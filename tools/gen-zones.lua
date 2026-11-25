-- tools/gen-zones.lua — diffs a wago.tools Map.db2 export against defaults/Zones.lua (design §6.5).
-- Never loaded by the client, never shipped (.pkgmeta ignores tools/).
--
--   lua tools/gen-zones.lua --build <build> --fetch Map.csv [defaults/Zones.lua]
--   lua tools/gen-zones.lua --build <build> Map.csv [defaults/Zones.lua]
--
-- The export is pinned to one build (clients-§10): `--build` is required, and the report names it.
-- Take the build from https://wago.tools/api/builds, the newest live (non-bgdl) `wow` build. The
-- table is diffed whole, as Retail reads it, so a `wowf` build would report every Retail-only map
-- as removed; the per-client check is tools/seeds/seeds.py's. `--fetch` downloads the export
-- first, through curl, from https://wago.tools/db2/Map/csv?build=<build> with the User-Agent
-- OutfitterReborn-seed-check (wago.tools refuses an anonymous agent). Without it, the CSV must
-- already be an export of that build.
--
-- It reads every map of InstanceType 3 (battleground) or 4 (arena) from the export and reports:
--   added      a map the export has and the table does not: a new row, a new map id on an existing
--              row, or a brawl to add to BRAWL_MAP_IDS -- decided by hand, from its name
--   removed    a map the table has and the export does not
--   wrongKind  a map whose row kind disagrees with its InstanceType (an arena row is type 4; a bg row
--              and a brawl are type 3)
-- The exit status is 0 when all three are empty and 1 otherwise. The tool edits nothing: the zone
-- table is hand-kept, so a new row gets its id, its place in the wear order and its trigger reviewed.
--
-- `dofile`d (tests/test_zones.lua), it runs nothing and returns its functions.

local M = {}

local KIND_TYPE = { bg = 3, arena = 4, brawl = 3 }

--- The export's rows as arrays of fields. RFC 4180: a quoted field may hold commas, newlines and a
--- doubled quote; a CR before a row's LF is dropped. The real Map.db2 export has all three, in the
--- PvP description columns.
local function rows(text)
    local out, row, buf = {}, {}, {}
    local i, n, quoted = 1, #text, false
    local function endField() row[#row + 1] = table.concat(buf); buf = {} end
    local function endRow()
        endField()
        if not (#row == 1 and row[1] == "") then out[#out + 1] = row end
        row = {}
    end
    while i <= n do
        local c = text:sub(i, i)
        if quoted then
            if c == '"' and text:sub(i + 1, i + 1) == '"' then
                buf[#buf + 1] = '"'
                i = i + 1
            elseif c == '"' then
                quoted = false
            else
                buf[#buf + 1] = c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," then
            endField()
        elseif c == "\n" then
            endRow()
        elseif c ~= "\r" then
            buf[#buf + 1] = c
        end
        i = i + 1
    end
    if #buf > 0 or #row > 0 then endRow() end
    return out
end

--- The export as an array of records keyed by its header row.
function M.parseCSV(text)
    local all, records = rows(text), {}
    local header = all[1] or {}
    for r = 2, #all do
        local rec = {}
        for k, name in ipairs(header) do rec[name] = all[r][k] end
        records[#records + 1] = rec
    end
    return records
end

--- map id -> { kind, owner } for every map the zone table names.
local function knownMaps(zones)
    local known = {}
    for _, row in ipairs(zones.rows) do
        for _, mapID in ipairs(row.mapIDs or {}) do known[mapID] = { kind = row.kind, owner = row.id } end
    end
    for _, mapID in ipairs(zones.BRAWL_MAP_IDS or {}) do known[mapID] = { kind = "brawl", owner = "BRAWL_MAP_IDS" } end
    return known
end

local function byId(a, b) return a.id < b.id end

--- The three lists the header describes, each sorted by map id.
function M.diff(zones, records)
    local known, seen = knownMaps(zones), {}
    local d = { added = {}, removed = {}, wrongKind = {} }
    for _, rec in ipairs(records) do
        local id, itype = tonumber(rec.ID), tonumber(rec.InstanceType)
        if id and (itype == 3 or itype == 4) then
            seen[id] = true
            local k = known[id]
            if not k then
                d.added[#d.added + 1] = { id = id, instanceType = itype, name = rec.MapName_lang or "" }
            elseif KIND_TYPE[k.kind] ~= itype then
                d.wrongKind[#d.wrongKind + 1] = { id = id, instanceType = itype, owner = k.owner }
            end
        end
    end
    for id, k in pairs(known) do
        if not seen[id] then d.removed[#d.removed + 1] = { id = id, owner = k.owner } end
    end
    table.sort(d.added, byId)
    table.sort(d.removed, byId)
    table.sort(d.wrongKind, byId)
    return d
end

--- The wago.tools build a pin names: four dot-separated numbers, as the builds API spells them.
function M.validBuild(build)
    return type(build) == "string" and build:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
end

M.USER_AGENT = "OutfitterReborn-seed-check"

--- The export's URL at one build. Errors on anything but a valid build: an unpinned fetch reads
--- whatever wago.tools calls current, and the diff could not say which build it describes.
function M.exportURL(build)
    assert(M.validBuild(build), "gen-zones: --build must be a wago.tools build such as 12.1.5.70961")
    return "https://wago.tools/db2/Map/csv?build=" .. build
end

--- The curl command `--fetch` runs. The build is validated and the path single-quoted for the
--- shell; a path that holds a single quote is refused rather than escaped.
function M.fetchCommand(build, path)
    assert(type(path) == "string" and path ~= "" and not path:find("'", 1, true),
        "gen-zones: the CSV path must be non-empty and hold no single quote")
    return ("curl -fsSL -A '%s' -o '%s' '%s'"):format(M.USER_AGENT, path, M.exportURL(build))
end

--- The command line: `--build <build>` (required), `--fetch`, then the CSV path and the optional
--- Zones.lua path. Answers the options, or nil and the reason.
function M.parseArgs(argv)
    local opts, pos, i = { fetch = false }, {}, 1
    while argv[i] ~= nil do
        local a = argv[i]
        if a == "--build" then
            opts.build = argv[i + 1]
            i = i + 1
        elseif a == "--fetch" then
            opts.fetch = true
        elseif a:sub(1, 2) == "--" then
            return nil, "unknown option " .. a
        else
            pos[#pos + 1] = a
        end
        i = i + 1
    end
    if not M.validBuild(opts.build) then
        return nil, "--build <build> is required (a wago.tools build such as 12.1.5.70961)"
    end
    if not pos[1] then return nil, "the Map.csv path is required" end
    if pos[3] then return nil, "too many arguments" end
    opts.csv, opts.zones = pos[1], pos[2]
    return opts
end

--- The diff as the lines a person reads, under a line naming the build when one is given.
function M.report(d, build)
    local out = {}
    if build then out[1] = ("Map.db2 at wago.tools build %s"):format(build) end
    for _, e in ipairs(d.added) do
        out[#out + 1] = ("added      %5d  InstanceType %d  %s"):format(e.id, e.instanceType, e.name)
    end
    for _, e in ipairs(d.removed) do
        out[#out + 1] = ("removed    %5d  (%s)"):format(e.id, e.owner)
    end
    for _, e in ipairs(d.wrongKind) do
        out[#out + 1] = ("wrongKind  %5d  InstanceType %d, listed under %s"):format(e.id, e.instanceType, e.owner)
    end
    if #d.added + #d.removed + #d.wrongKind == 0 then
        out[#out + 1] = "defaults/Zones.lua matches the export: no map added, removed or moved"
    end
    return table.concat(out, "\n")
end

--- Loads defaults/Zones.lua outside the client: its NS gets an L that answers every key with itself,
--- and reads as Retail with every row admitted, so `rows` is the whole table (Zones.ALL) the export
--- is diffed against.
function M.loadZones(path)
    local chunk = assert(loadfile(path))
    local NS = { L = setmetatable({}, { __index = function(_, k) return k end }), CLIENT = "retail" }
    function NS.PerClient(pair) return pair and pair.retail end
    function NS.ForClientRows(list) return list end
    chunk("OutfitterReborn", NS)
    return NS.Zones
end

local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local USAGE = "usage: lua tools/gen-zones.lua --build <build> [--fetch] Map.csv [defaults/Zones.lua]\n"

local function main(argv)
    local opts, err = M.parseArgs(argv)
    if not opts then
        io.stderr:write("gen-zones: " .. err .. "\n" .. USAGE)
        return 2
    end
    if opts.fetch then
        -- os.execute answers 0 on Lua 5.1 and true on 5.2+ when the command succeeds.
        local ok = os.execute(M.fetchCommand(opts.build, opts.csv))
        if ok ~= true and ok ~= 0 then
            io.stderr:write("gen-zones: fetching " .. M.exportURL(opts.build) .. " failed\n")
            return 2
        end
    end
    local d = M.diff(M.loadZones(opts.zones or "defaults/Zones.lua"), M.parseCSV(readAll(opts.csv)))
    print(M.report(d, opts.build))
    return (#d.added + #d.removed + #d.wrongKind == 0) and 0 or 1
end

if arg and type(arg[0]) == "string" and arg[0]:match("gen%-zones%.lua$") then
    os.exit(main(arg))
end

return M
