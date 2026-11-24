-- tests/test_foreverdb_missing.lua — the outfit tooltip's missing items, described from the client
-- or, on WoW Forever, from ForeverDB (SF-OR-02, LibKa0s#105; modules/OutfitTooltip.lua).
--
-- ForeverDB is the kit's fake (tests/_kit/mock_foreverdb.lua): invented rows in ForeverDB's shape,
-- never a row of the real database (its data is GPL-3.0). The fake goes in through `mutate`, BEFORE
-- the addon loads, so `fake.loads` proves that nothing loads ForeverDB at login and that the first
-- hover over an outfit with missing items is what loads it. `client` sets the project constants, so
-- every case means the same under both kit profiles.

local T = _G.OUTFITTERREBORN_TEST
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local FDB = dofile(T.root .. "/tests/_kit/mock_foreverdb.lua")
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local DB = T.fixtures.items.db
local BLADE = FDB.IDS.blade          -- the fake's item: quality 2, required level 10
local BLADE_NAME = "Fixture Blade"

--- A fresh instance with the fake installed before the load. `opts.preset` and `opts.client` are
--- the fake's; the answer is NS, M and the fake's handle.
local function scene(opts)
    opts = opts or {}
    local fake
    local inst = unitLoad({ mutate = function(M)
        M.__gear:load("geared")
        fake = FDB.install(M, { preset = opts.preset or "present", client = opts.client or "forever" })
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

-- ── characterization: the line before this change ────────────────────────────────────────────

test("foreverdb missing: without ForeverDB the missing line is the plain list it always was", function()
    -- The characterization case, written before the change and kept: the missing preset on WoW
    -- Forever draws every name in the missing color, label in white, one reset.
    local NS, M, fake = scene({ preset = "missing" })
    local id = bladeOutfit(NS)
    assertEqual(missingLine(NS, M, id), plainLine(NS, { BLADE_NAME }))
    assertEqual(fake.loads, 0, "a missing addon is never loaded")
    fake.restore()
end)
