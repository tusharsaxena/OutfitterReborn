-- tests/test_missing_items.lua — the outfit tooltip's missing items (modules/OutfitTooltip.lua):
-- on WoW Forever each one is described from the client's answer alone, and nothing in this addon
-- reads ForeverDB (SF-OR-02, narrowed by ISF-OR-01: only Drop Watcher reads ForeverDB now).
--
-- The items are invented (an id no fixture or client table holds), never a row of ForeverDB (its
-- data is GPL-3.0). The client's answer is a stub of C_Item.GetItemInfo for that one id. The kit's
-- ForeverDB fake (tests/_kit/mock_foreverdb.lua) goes in through `mutate`, before the addon loads,
-- only to prove that no hover loads or reads it.
--
-- PER PROFILE. The kit stamps the profile's project constants on the mock when the addon's environment
-- is built, after `mutate`, so a case cannot pick its client at load. The cases that need WoW Forever
-- run under `KA0S_KIT_CLIENT=forever` and skip under the plain profile; the Retail case is the plain
-- profile's and skips under Forever. The rest run under both.

local T = _G.OUTFITTERREBORN_TEST
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local FDB = dofile(T.root .. "/tests/_kit/mock_foreverdb.lua")
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local FOREVER = dofile(T.root .. "/tests/_kit/mock_client.lua").current() == "forever"
local FOREVER_ONLY = "WoW Forever only: run under KA0S_KIT_CLIENT=forever"
local RETAIL_ONLY = "the Retail case: run under the plain kit profile"

local DB = T.fixtures.items.db
local BLADE = 990777                 -- invented: no fixture and no client table knows it
local BLADE_NAME = "Fixture Blade"

--- A fresh instance on the profile's client; `withFake` installs the kit's ForeverDB fake first.
local function scene(withFake)
    local fake
    local inst = unitLoad({ mutate = function(M)
        M.__gear:load("geared")
        if withFake then fake = FDB.install(M, { preset = "present" }) end
    end })
    local NS, M = inst.NS, inst.mocks
    NS.ApplySkinChoice("ka0s", "ka0s")
    return NS, M, fake
end

--- An outfit whose main hand is the blade, which no bag holds (so it is missing), and whose head is
--- a carried fixture item.
local function bladeOutfit(NS, id)
    local blade = NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB.neck_chain.link))
    blade.id, blade.name, blade.link = id or BLADE, BLADE_NAME, nil
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB.head_plate.link))
    return NS.Outfits.Create("Errand", { MainHandSlot = blade, HeadSlot = head })
end

--- The missing line of outfit `id`'s tooltip (line 2: the outfit has no trigger).
local function missingLine(NS, M, id)
    local owner = M.CreateFrame("Button", nil, M.UIParent)
    assertTrue(NS.OutfitTooltip.Show(id, owner, owner), "the tooltip showed")
    return M.GameTooltip.TextLeft2:GetText()
end

--- The line as the tooltip drew it before SF-OR-02: the label in white, every name in the missing
--- color, one reset at the end.
local function plainLine(NS, names)
    return NS.SkinEscape("text.highlight") .. "Missing: " .. NS.SkinEscape("of.outfit.missing")
        .. table.concat(names, ", ") .. "|r"
end

local function qualityEscape(NS, q)
    local r, g, b = NS.QualityColor(q)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

--- The line with one described name: `q`'s color around the name (none for a nil `q`), then the
--- level suffix, if any.
local function describedLine(NS, q, level)
    local name = BLADE_NAME
    if q then name = qualityEscape(NS, q) .. name .. "|r" end
    if level then name = name .. " (level " .. level .. ")" end
    return plainLine(NS, { name })
end

--- Run `fn` with the player at `level` and the client answering `quality` and `minLevel` for the
--- blade (Compat.UnitLevel and Compat.ItemInfo read the client at call time).
local function withClient(M, level, quality, minLevel, fn)
    local savedLevel, savedInfo = M.UnitLevel, M.C_Item.GetItemInfo
    M.UnitLevel = function() return level end
    M.C_Item.GetItemInfo = function(item)
        if item == BLADE then
            if quality == nil and minLevel == nil then return nil end
            return BLADE_NAME, nil, quality, 20, minLevel
        end
        return savedInfo(item)
    end
    local ok, err = pcall(fn)
    M.UnitLevel, M.C_Item.GetItemInfo = savedLevel, savedInfo
    if not ok then error(err, 0) end
end

-- ── the client's answer alone ─────────────────────────────────────────────────────────────────

test("missing items: an item the client has not loaded is the plain name it always was", function()
    -- The SF-OR-02 characterization case, kept: no client answer draws every name in the missing
    -- color, label in white, one reset, on both clients.
    local NS, M = scene()
    local id = bladeOutfit(NS)
    withClient(M, 5, nil, nil, function()
        assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    end)
end)

test("missing items: on WoW Forever the client's quality and level describe the name", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M = scene()
    local id = bladeOutfit(NS)
    withClient(M, 5, 4, 30, function()
        -- red under: describe() dropping the client's answer (the plain list comes back).
        assertEqual(missingLine(NS, M, id), describedLine(NS, 4, 30))
    end)
    withClient(M, 30, 4, 30, function()
        -- red under: the level shown whatever the player's level.
        assertEqual(missingLine(NS, M, id), describedLine(NS, 4, nil), "at the level, no suffix")
    end)
    withClient(M, nil, 4, 30, function()
        assertEqual(missingLine(NS, M, id), describedLine(NS, 4, 30), "an unknown level shows it")
    end)
end)

test("missing items: on WoW Forever a field the client left nil is left out", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M = scene()
    local id = bladeOutfit(NS)
    withClient(M, 5, 3, nil, function()
        assertEqual(missingLine(NS, M, id), describedLine(NS, 3, nil), "quality only")
    end)
    withClient(M, 5, nil, 12, function()
        assertEqual(missingLine(NS, M, id), describedLine(NS, nil, 12), "level only")
    end)
end)

test("missing items: on Retail the list stays plain whatever the client answers", function()
    if FOREVER then return T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    local id = bladeOutfit(NS)
    withClient(M, 5, 4, 30, function()
        -- red under: the per-client pick in modules/OutfitTooltip.lua answering true on Retail.
        assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    end)
end)

-- ── no ForeverDB read remains (ISF-OR-01) ─────────────────────────────────────────────────────

test("missing items: with ForeverDB installed, no hover loads it and its item is not described", function()
    local NS, M, fake = scene(true)
    local id = bladeOutfit(NS, FDB.IDS.blade)
    local ok, err = pcall(function()
        missingLine(NS, M, id)
        -- red under: an Available() call anywhere on the hover (the SF-OR-02 lease back).
        assertEqual(fake.loads, 0, "a hover loaded ForeverDB")
        -- The fake knows the blade; the client does not, so the name is plain.
        assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    end)
    fake.restore()
    if not ok then error(err, 0) end
    assertEqual(NS["Forever" .. "DB"], nil, "the ForeverDB lease is gone")
end)

-- The names below are built in pieces so this file does not match its own scan; the file is also
-- left out of it, since it has to name what it looks for. Comments are blanked first (as in Skill
-- Master's tests/test_no_foreverdb.lua), so a comment telling this history is no read, and then a bare
-- name is enough: the global (`_G.ForeverDB`, `ForeverDB.item`), a `LoadAddOn("ForeverDB")`, the
-- library (`LibKa0s-ForeverDB`) and the lease (`NS.ForeverDB`) all hold it. Case matters: the retired
-- `window.foreverdb` key that core/Database.lua's step 2 clears does not match.
local PATTERNS = { "Forever" .. "DB", "forever%-" .. "db" }
local SELF = "tests/test_missing_items.lua"

local function scanned(path)
    return (path:find("%.lua$") ~= nil or path:find("%.toc$") ~= nil or path == ".pkgmeta")
        and path ~= SELF and not path:find("^libs/") and not path:find("^tests/_kit/")
end

--- `text` with its Lua comments blanked (long ones first); a .toc or .pkgmeta is scanned whole.
--- Rough on purpose: no addon string literal holds "--".
local function code(path, text)
    if not path:find("%.lua$") then return text end
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

test("missing items: no file outside libs/ and tests/_kit/ reads ForeverDB, in code or manifest", function()
    local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard 2>/dev/null')
    assertTrue(p ~= nil, "io.popen gave no handle for `git ls-files`")
    local files, hits = 0, {}
    for path in p:lines() do
        if scanned(path) then
            local f = io.open(T.root .. "/" .. path, "rb")
            if f then
                files = files + 1
                local body = code(path, (f:read("*a"):gsub("\r\n", "\n")))
                f:close()
                for _, pat in ipairs(PATTERNS) do
                    if body:find(pat) then hits[#hits + 1] = path .. ": " .. pat:gsub("%%", "") end
                end
            end
        end
    end
    p:close()
    assertTrue(files > 50, "`git ls-files` listed only " .. files .. " files")
    -- red under: core/ForeverDBSetup.lua back, a module calling the library or reading the ForeverDB
    -- global, a LoadAddOn of it anywhere, or ForeverDB named in the TOC or .pkgmeta.
    assertEqual(table.concat(hits, ", "), "")
end)

test("missing items: the TOC names no ForeverDB dependency", function()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "r"))
    local text = f:read("*a")
    f:close()
    for line in text:gmatch("[^\r\n]+") do
        if line:find("^## OptionalDeps") or line:find("^## Dependencies") or line:find("^## RequiredDeps") then
            assertFalse(line:find("ForeverDB", 1, true) ~= nil, line)
        end
    end
end)
