-- tests/test_foreverdb_missing.lua — the outfit tooltip's missing items, described from the client
-- or, on WoW Forever, from ForeverDB (SF-OR-02, LibKa0s#105; modules/OutfitTooltip.lua).
--
-- ForeverDB is the kit's fake (tests/_kit/mock_foreverdb.lua): invented rows in ForeverDB's shape,
-- never a row of the real database (its data is GPL-3.0). The fake goes in through `mutate`, BEFORE
-- the addon loads, so `fake.loads` proves that nothing loads ForeverDB at login and that the first
-- hover over an outfit with missing items is what loads it.
--
-- PER PROFILE. The kit stamps the profile's project constants on the mock when the addon's environment
-- is built, after `mutate`, so a case cannot pick its client at load. The cases that need WoW Forever
-- run under `KA0S_KIT_CLIENT=forever` and skip under the plain profile; the Retail case is the plain
-- profile's and skips under Forever. The characterization case runs under both.

local T = _G.OUTFITTERREBORN_TEST
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local FDB = dofile(T.root .. "/tests/_kit/mock_foreverdb.lua")
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local FOREVER = dofile(T.root .. "/tests/_kit/mock_client.lua").current() == "forever"
local FOREVER_ONLY = "WoW Forever only: run under KA0S_KIT_CLIENT=forever"
local RETAIL_ONLY = "the Retail case: run under the plain kit profile"

local DB = T.fixtures.items.db
local BLADE = FDB.IDS.blade          -- the fake's item: quality 2, required level 10
local BLADE_NAME = "Fixture Blade"

--- A fresh instance with the fake installed before the load, on the profile's client. `opts.preset`
--- is the fake's; the answer is NS, M and the fake's handle.
local function scene(opts)
    opts = opts or {}
    local fake
    local inst = unitLoad({ mutate = function(M)
        M.__gear:load("geared")
        fake = FDB.install(M, { preset = opts.preset or "present" })
    end })
    local NS, M = inst.NS, inst.mocks
    NS.ApplySkinChoice("ka0s", "ka0s")
    return NS, M, fake
end

--- An outfit whose main hand is the fake's blade, which no bag holds (so it is missing), and whose
--- head is a carried fixture item.
local function bladeOutfit(NS)
    local blade = NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB.neck_chain.link))
    blade.id, blade.name, blade.link = BLADE, BLADE_NAME, nil
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB.head_plate.link))
    return NS.Outfits.Create("Errand", { MainHandSlot = blade, HeadSlot = head })
end

--- The missing line of outfit `id`'s tooltip (line 2: the outfit has no trigger).
local function missingLine(NS, M, id)
    local owner = M.CreateFrame("Button", nil, M.UIParent)
    assertTrue(NS.OutfitTooltip.Show(id, owner, owner), "the tooltip showed")
    return M.GameTooltip.TextLeft2:GetText()
end

--- The line as the tooltip drew it before ForeverDB: the label in white, every name in the
--- missing color, one reset at the end.
local function plainLine(NS, names)
    return NS.SkinEscape("text.highlight") .. "Missing: " .. NS.SkinEscape("of.outfit.missing")
        .. table.concat(names, ", ") .. "|r"
end

local function qualityEscape(NS, q)
    local r, g, b = NS.QualityColor(q)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

--- The line with one described name: `q`'s color around the name, then the level suffix, if any.
local function describedLine(NS, q, level)
    local name = qualityEscape(NS, q) .. BLADE_NAME .. "|r"
    if level then name = name .. " (level " .. level .. ")" end
    return plainLine(NS, { name })
end

--- Run `fn` with the player at `level` (Compat.UnitLevel reads UnitLevel bare at call time).
local function atLevel(M, level, fn)
    local saved = M.UnitLevel
    M.UnitLevel = function() return level end
    local ok, err = pcall(fn)
    M.UnitLevel = saved
    if not ok then error(err, 0) end
end

-- ── characterization: the line before this change ────────────────────────────────────────────

test("foreverdb missing: without ForeverDB the missing line is the plain list it always was", function()
    -- The characterization case, written before the change and kept: the missing preset (and, under
    -- the plain profile, Retail) draws every name in the missing color, label in white, one reset.
    local NS, M, fake = scene({ preset = "missing" })
    local id = bladeOutfit(NS)
    assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    assertEqual(fake.loads, 0, "a missing addon is never loaded")
    fake.restore()
end)

-- ── with ForeverDB ────────────────────────────────────────────────────────────────────────────

test("foreverdb missing: nothing loads ForeverDB at login; the first hover loads it once", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M, fake = scene()
    -- red under: an Available() call at file load or in OnEnable (core/ForeverDBSetup.lua).
    assertEqual(fake.loads, 0, "loaded at login")
    local id = bladeOutfit(NS)
    atLevel(M, 5, function()
        missingLine(NS, M, id)
        missingLine(NS, M, id)
    end)
    -- red under: a lookup that bypasses the library's session cache.
    assertEqual(fake.loads, 1, "one load, on the first hover")
    fake.restore()
end)

test("foreverdb missing: an item the client cannot describe takes ForeverDB's quality and level", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M, fake = scene()
    local id = bladeOutfit(NS)
    atLevel(M, 5, function()
        -- red under: describe() never reaching NS.ForeverDB.Item (the plain list comes back).
        assertEqual(missingLine(NS, M, id), describedLine(NS, 2, 10))
    end)
    atLevel(M, 10, function()
        -- red under: the level shown whatever the player's level.
        assertEqual(missingLine(NS, M, id), describedLine(NS, 2, nil), "at the level, no suffix")
    end)
    atLevel(M, nil, function()
        assertEqual(missingLine(NS, M, id), describedLine(NS, 2, 10), "an unknown level shows it")
    end)
    fake.restore()
end)

test("foreverdb missing: the client's answer wins over ForeverDB's, field by field", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M, fake = scene()
    local id = bladeOutfit(NS)
    local real = M.C_Item.GetItemInfo
    local minLevel = 30
    M.C_Item.GetItemInfo = function(item)
        if item == BLADE then return BLADE_NAME, nil, 4, 20, minLevel end
        return real(item)
    end
    local ok, err = pcall(function()
        atLevel(M, 5, function()
            -- red under: ForeverDB read first (quality 2 and level 10 instead of 4 and 30).
            assertEqual(missingLine(NS, M, id), describedLine(NS, 4, 30), "the client knows both")
            minLevel = nil
            -- red under: a client answer taken whole or not at all (ForeverDB's level dropped).
            assertEqual(missingLine(NS, M, id), describedLine(NS, 4, 10), "the client's quality, ForeverDB's level")
        end)
    end)
    M.C_Item.GetItemInfo = real
    fake.restore()
    if not ok then error(err, 0) end
end)

-- ── without it, or not on WoW Forever ─────────────────────────────────────────────────────────

test("foreverdb missing: reshaped or failing to load, the list stays plain", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    for _, preset in ipairs({ "reshaped", "loadfails" }) do
        local NS, M, fake = scene({ preset = preset })
        local id = bladeOutfit(NS)
        atLevel(M, 5, function()
            -- red under: describing() ignoring Available()'s answer.
            assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }), preset)
        end)
        assertEqual(fake.loads, 1, preset .. ": the one load attempt")
        fake.restore()
    end
end)

test("foreverdb missing: with the setting off, nothing loads and the list stays plain", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, M, fake = scene()
    NS.SetByPath("window.foreverdb", false)
    local id = bladeOutfit(NS)
    atLevel(M, 5, function()
        -- red under: the setting not read before Available() (the load happens anyway).
        assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    end)
    assertEqual(fake.loads, 0, "the setting off loads nothing")
    fake.restore()
end)

test("foreverdb missing: on Retail it is inert: no row, no load, the plain list", function()
    if FOREVER then return T.skip(RETAIL_ONLY) end
    local NS, M, fake = scene()
    -- red under: the row registered without NS.ForClientRows (settings/OutfitWindow.lua).
    assertNil(NS.FindSchemaRow("window.foreverdb"), "Retail offers no row")
    local id = bladeOutfit(NS)
    atLevel(M, 5, function()
        assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    end)
    -- red under: an adapter gate that loads before asking which client this is.
    assertEqual(fake.loads, 0, "Retail loads nothing")
    fake.restore()
end)

test("foreverdb missing: on WoW Forever the Outfit rows group offers the switch, on by default", function()
    if not FOREVER then return T.skip(FOREVER_ONLY) end
    local NS, _, fake = scene()
    local row = NS.FindSchemaRow("window.foreverdb")
    assertTrue(row ~= nil, "the row is registered on WoW Forever")
    assertEqual(row.page .. "/" .. row.group .. "/" .. row.subgroup, "window/List/Outfit rows")
    assertEqual(row.default, true)
    assertEqual(NS.GetSetting("window.foreverdb"), true)
    -- The row says it needs ForeverDB (clients-§11).
    assertTrue(row.label:find("ForeverDB", 1, true) ~= nil, row.label)
    assertTrue(row.tooltip:find("Needs the ForeverDB addon", 1, true) ~= nil, row.tooltip)
    fake.restore()
end)
