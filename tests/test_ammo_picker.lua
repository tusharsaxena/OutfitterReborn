-- tests/test_ammo_picker.lua — modules/QuickSlots_Ammo.lua: WoW Forever's ammo picker (the owner's
-- smoke report, 2026-11-28).
--
-- WHY A PICKER OF ITS OWN. Blizzard's flyout lists what GetInventoryItemsForSlot answers, and for the
-- ammo slot that is nothing (the owner's probe: `ammo candidates: 0`). EquipmentFlyout_Show hides a
-- flyout with no entries (Camelot/EquipmentFlyout.lua:304-307), so the arrow the drawer gave the
-- ammo slot did nothing on an empty slot, and with ammo worn it showed only "place in bags", which
-- cannot clear the slot either (the owner's second probe). The picker lists the carried ammo itself,
-- in a frame of this addon's own, and equips a pick out of combat; Blizzard's flyout and its list are
-- never touched for the ammo slot (FLY-TAINT-01).
--
-- THE CLIENT is tests/mock_gear.lua's, with its Forever ammo slot (a reference to a carried type),
-- the character sheet's CharacterAmmoSlot made here as F-UI makes it (no arrow,
-- Camelot/PaperDollFrame.xml:873-927) and EquipmentFlyoutPopoutButton_OnClick recorded, so a case
-- sees Blizzard's flyout is never asked to open on the ammo slot.

local T = _G.OUTFITTERREBORN_TEST
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local FOREVER_ONLY = "WoW Forever's ammo slot; Retail has none"
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db
local AMMO_SLOT = 0

-- A hunter's bags: two stacks of bullets, a stack each of two arrows, and gear that is not ammo.
local function hunterBags(ranged)
    return {
        equipped = { RangedSlot = ranged },
        bags = { [0] = { items = {
            [1] = { key = "ammo_bullet", count = 200 },
            [2] = { key = "ammo_arrow_low", count = 200 },
            [3] = { key = "head_plate" },
            [4] = { key = "ammo_bullet", count = 40 },
            [5] = { key = "ammo_arrow_high", count = 120 },
        } } },
    }
end

-- Every frame CreateFrame builds from here on records its points (`__pts`) and size (`__size`): the
-- base frame keeps neither (mock_base.lua, rule 2's setters left undefined).
local function recordGeometry(M)
    local base = M.CreateFrame
    M.CreateFrame = function(...)
        local f = base(...)
        rawset(f, "__pts", {})
        rawset(f, "SetPoint", function(self, ...) local p = rawget(self, "__pts"); p[#p + 1] = { ... } end)
        rawset(f, "ClearAllPoints", function(self) rawset(self, "__pts", {}) end)
        rawset(f, "SetSize", function(self, w, h) rawset(self, "__size", { w, h }) end)
        return f
    end
end

-- An instance with a gear scenario, the sheet's ammo slot (27 px, F-UI's, unless `opts.slot` says),
-- and QuickSlots stood up. `M.__popoutClicks` counts Blizzard's popout handler; `M.__painted` records
-- Blizzard's item-button painters by button. `opts.paint` installs the kit's paint recorder and the
-- geometry recorder above, so the picker's strips, glow and anchors can be read back.
local function ammoInstance(scenario, opts)
    opts = opts or {}
    local inst = unitLoad({ mutate = function(M)
        if opts.paint then dofile(T.root .. "/tests/_kit/mock_paint.lua")(M); recordGeometry(M) end
        M.__gear:load(scenario or hunterBags("gun_ranged"))
        M.PaperDollItemsFrame.flyoutSettings.anchorX = 0
        M.PaperDollItemsFrame.flyoutSettings.anchorY = -3
        M.CharacterAmmoSlot = M.CreateFrame("Button", "CharacterAmmoSlot", M.PaperDollItemsFrame)
        local size = opts.slot or 27
        rawset(M.CharacterAmmoSlot, "GetID", function() return AMMO_SLOT end)
        rawset(M.CharacterAmmoSlot, "GetWidth", function() return size end)
        rawset(M.CharacterAmmoSlot, "GetHeight", function() return size end)
        M.__popoutClicks = 0
        M.EquipmentFlyoutPopoutButton_OnClick = function() M.__popoutClicks = M.__popoutClicks + 1 end
        M.EquipmentFlyout_Hide = function() end
        M.__painted = {}
        for _, name in ipairs({ "SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonQuality" }) do
            M[name] = function(b, ...)
                M.__painted[b] = M.__painted[b] or {}
                M.__painted[b][name] = { ... }
            end
        end
    end })
    inst.NS.QuickSlots.Resume()
    return inst.NS, inst.mocks
end

local function ids(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.itemID end
    return table.concat(out, ",")
end

local function picker(M) return M.OutfitterRebornAmmoPicker end
local function shownButtons(M)
    local out = {}
    for _, b in ipairs(picker(M).buttons) do if b:IsShown() then out[#out + 1] = b end end
    return out
end

-- ── the list ──────────────────────────────────────────────────────────────────────────────────

test("ammo picker: the list is the carried ammo the ranged weapon fires, one entry a type, counts summed", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS = ammoInstance(hunterBags("gun_ranged"))
    local list = NS.QuickSlots.Ammo.List()
    -- red under: Blizzard's own list (GetInventoryItemsForSlot answers no ammo at all).
    assertEqual(ids(list), tostring(DB.ammo_bullet.id), "a gun fires bullets only")
    assertEqual(list[1].count, 240, "both stacks of the type")
    assertEqual(list[1].bag, 0); assertEqual(list[1].slot, 1)
end)

test("ammo picker: a bow lists arrows, best item level first; no ranged weapon lists every type", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS = ammoInstance(hunterBags("bow_ranged"))
    -- red under: bag order (the low arrow sits first in the bag).
    assertEqual(ids(NS.QuickSlots.Ammo.List()), DB.ammo_arrow_high.id .. "," .. DB.ammo_arrow_low.id)
    local bare = ammoInstance(hunterBags(nil))
    assertEqual(ids(bare.QuickSlots.Ammo.List()),
        table.concat({ DB.ammo_bullet.id, DB.ammo_arrow_high.id, DB.ammo_arrow_low.id }, ","))
end)

-- ── the equip ─────────────────────────────────────────────────────────────────────────────────

test("ammo picker: a pick is dropped on the ammo slot from its bag, the cursor left empty", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("bow_ranged"))
    local high = NS.QuickSlots.Ammo.List()[1]
    assertTrue(NS.QuickSlots.Ammo.Equip(high), "the equip ran")
    assertEqual(M.GetInventoryItemID("player", AMMO_SLOT), DB.ammo_arrow_high.id)
    assertFalse(M.CursorHasItem(), "nothing left on the cursor")
    assertEqual(M.__gear:bagItem(0, 5).def.id, DB.ammo_arrow_high.id, "the stack stays in its bag")
end)

test("ammo picker: in combat lockdown nothing is picked up and the player is told", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("bow_ranged"))
    M.__lockdown = true
    local before = #M.__equipCalls
    -- red under: a combat equip (PickupInventoryItem from addon code is blocked in combat).
    assertFalse(NS.QuickSlots.Ammo.Equip(NS.QuickSlots.Ammo.List()[1]))
    assertEqual(#M.__equipCalls, before, "no cursor call in lockdown")
    assertNil(M.GetInventoryItemID("player", AMMO_SLOT))
    assertTrue(#M.__printed() > 0, "a line says why")
end)

-- ── the picker ────────────────────────────────────────────────────────────────────────────────

test("ammo picker: the ammo slot's arrow opens the picker, not Blizzard's flyout, and closes it again", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags(nil))
    local pop = rawget(M.CharacterAmmoSlot, "popoutButton")
    assertTrue(pop ~= nil, "the ammo slot has an arrow")
    pop:__fire("OnClick")
    -- red under: the arrow running Blizzard's popout handler (EquipmentFlyout_Show, which hides an
    -- empty list: the owner's arrow that did nothing).
    assertEqual(M.__popoutClicks, 0, "Blizzard's flyout is never asked")
    assertTrue(picker(M) ~= nil and picker(M):IsShown(), "the picker shows")
    assertEqual(#shownButtons(M), 3, "one button per carried type")
    assertTrue(NS.QuickSlots.Ammo.IsOpen())
    pop:__fire("OnClick")
    assertFalse(picker(M):IsShown(), "a second click closes it")
end)

test("ammo picker: a picked button equips that ammo and closes the picker", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = ammoInstance(hunterBags("bow_ranged"))
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    local buttons = shownButtons(M)
    assertEqual(buttons[2].entry.itemID, DB.ammo_arrow_low.id)
    buttons[2]:__fire("OnClick")
    assertEqual(M.GetInventoryItemID("player", AMMO_SLOT), DB.ammo_arrow_low.id)
    assertFalse(picker(M):IsShown())
end)

test("ammo picker: clicking the empty ammo slot opens the picker", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = ammoInstance(hunterBags("gun_ranged"))
    M.CharacterAmmoSlot:__fire("PostClick")
    assertEqual(M.__popoutClicks, 0)
    assertTrue(picker(M) ~= nil and picker(M):IsShown())
end)

test("ammo picker: no carried ammo opens nothing and says so", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance({ equipped = { RangedSlot = "gun_ranged" } })
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    assertFalse(NS.QuickSlots.Ammo.IsOpen())
    assertTrue(#M.__printed() > 0)
end)

test("ammo picker: combat, the stand-down and a close each hide it and drop its events", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("gun_ranged"))
    local Ammo = NS.QuickSlots.Ammo
    Ammo.Open()
    local f = picker(M)
    assertTrue(f:IsEventRegistered("PLAYER_REGEN_DISABLED"), "it listens while open")
    M.__world:setCombat(true)
    -- red under: a picker left open into combat (its clicks would be refused anyway).
    assertFalse(f:IsShown(), "combat closes it")
    assertFalse(f:IsEventRegistered("PLAYER_REGEN_DISABLED"), "and its events go")
    M.__world:setCombat(false)
    Ammo.Open()
    NS.QuickSlots.Suspend()
    assertFalse(f:IsShown(), "the stand-down closes it")
    assertFalse(f:IsEventRegistered("BAG_UPDATE_DELAYED"))
end)

test("ammo picker: opening in combat lockdown is refused", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("gun_ranged"))
    M.__lockdown = true
    NS.QuickSlots.Ammo.Open()
    assertFalse(NS.QuickSlots.Ammo.IsOpen())
end)

test("ammo picker: a bag change while open redraws the list", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags(nil))
    NS.QuickSlots.Ammo.Open()
    assertEqual(#shownButtons(M), 3)
    M.__gear:load(hunterBags("gun_ranged"))
    picker(M):__fire("OnEvent", "BAG_UPDATE_DELAYED")
    assertEqual(#shownButtons(M), 1, "the gun's bullets only, after the redraw")
end)

test("ammo picker: Retail builds no picker and no ammo arrow", function()
    if FOREVER then T.skip("pins Retail, which has no ammo slot") end
    local NS, M = ammoInstance(hunterBags(nil))
    NS.QuickSlots.Ammo.Open()
    assertFalse(NS.QuickSlots.Ammo.IsOpen())
    assertNil(picker(M))
    assertNil(rawget(M.CharacterAmmoSlot, "popoutButton"))
end)

-- ── Blizzard's flyout art (DEV-SKIN-AMMO-PICKER) ────────────────────────────────────────────────

local ART = "Interface\\PaperDollInfoFrame\\UI-GearManager-Flyout"

local function coords(t) return table.concat({ t:GetTexCoord() }, ",") end

test("ammo picker: two types draw Blizzard's one-row parchment, ItemButtons in its grid, no skin", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = ammoInstance(hunterBags("bow_ranged"), { paint = true })
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    local f = picker(M)
    -- red under: the skinned panel (a BackdropTemplate frame painted by NS.ApplySkin).
    assertNil(f.__template, "no BackdropTemplate")
    assertNil(M.__paint(f).backdrop, "no backdrop")
    -- EquipmentFlyout_UpdateItems' one-row case for two buttons: the left cap, then the right cap.
    assertEqual(f.bg1:GetTexture(), ART)
    local l, r, t, b = 0, 0.16796875, 0.5546875, 0.77734375
    assertEqual(coords(f.bg1), table.concat({ l, t, l, b, r, t, r, b }, ","), "the row's left cap")
    assertEqual(f.bg1:GetWidth(), 43); assertEqual(f.bg1:GetHeight(), 54)
    local p, rel, rp, x, y = f.bg1:GetPoint(1)
    assertEqual(p, "TOPLEFT"); assertEqual(rel, f); assertEqual(rp, "TOPLEFT"); assertEqual(x, -5); assertEqual(y, 4)
    assertEqual(f.bg2:GetWidth(), 47, "the row's right cap")
    _, rel, rp = f.bg2:GetPoint(1)
    assertEqual(rel, f.bg1); assertEqual(rp, "TOPRIGHT")
    -- buttonFrame's size (EquipmentFlyout.lua:427-428) and the second cell 41 px in.
    assertEqual(table.concat(f.__size, ","), (2 * 37 + 4 + 3) .. ",43")
    local buttons = shownButtons(M)
    assertEqual(buttons[2].__template, nil)
    local pt = buttons[2].__pts[1]
    assertEqual(pt[1], "TOPLEFT"); assertEqual(pt[4], 3 + 41); assertEqual(pt[5], -3)
    -- Blizzard's own painters, as EquipmentFlyout_DisplayButton calls them.
    assertEqual(M.__painted[buttons[1]].SetItemButtonTexture[1], DB.ammo_arrow_high.icon)
    assertEqual(M.__painted[buttons[1]].SetItemButtonCount[1], 120)
end)

test("ammo picker: one type draws the one-slot caps; a redraw to more hides none it still needs", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = ammoInstance(hunterBags("gun_ranged"), { paint = true })
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    local f = picker(M)
    assertEqual(f.bg1:GetWidth(), 25); assertEqual(f.bg2:GetWidth(), 24)
    assertEqual(table.concat(f.__size, ","), "40,43")
    M.__gear:load(hunterBags(nil))
    f:__fire("OnEvent", "BAG_UPDATE_DELAYED")
    assertEqual(f.bg1:GetWidth(), 43); assertEqual(f.bg2:GetWidth(), 41); assertEqual(f.bg3:GetWidth(), 47)
    assertTrue(f.bg3:IsShown())
end)

test("ammo picker: the worn type is left out, as Blizzard leaves the worn item out", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("bow_ranged"))
    NS.QuickSlots.Ammo.Equip(NS.QuickSlots.Ammo.List()[1])
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    local buttons = shownButtons(M)
    assertEqual(#buttons, 1)
    assertEqual(buttons[1].entry.itemID, DB.ammo_arrow_low.id)
end)

test("ammo picker: only the worn type carried opens nothing and says there is no other", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance({ equipped = { RangedSlot = "gun_ranged" },
                                 bags = { [0] = { items = { [1] = { key = "ammo_bullet", count = 200 } } } } })
    NS.QuickSlots.Ammo.Equip(NS.QuickSlots.Ammo.List()[1])
    local before = #M.__printed()
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    assertFalse(NS.QuickSlots.Ammo.IsOpen())
    assertEqual(M.__printed()[before + 1]:find("No other ammo", 1, true) ~= nil, true)
end)

test("ammo picker: it hangs off the arrow as Blizzard's flyout does, the glow on the slot at its size", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    for _, size in ipairs({ 27, 40 }) do        -- F-UI's ammo slot, and Chonky's larger one
        local _, M = ammoInstance(hunterBags("gun_ranged"), { paint = true, slot = size })
        local slot = M.CharacterAmmoSlot
        rawget(slot, "popoutButton"):__fire("OnClick")
        local f = picker(M)
        local p = f.__pts[1]
        -- red under: the skinned panel's own offset (+3, +7) off the arrow.
        assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], rawget(slot, "popoutButton")); assertEqual(p[3], "TOPRIGHT")
        assertEqual(p[4], 0); assertEqual(p[5], -3, "the paper doll's anchorY")
        local gp, grel = f.glow:GetPoint(1)
        assertEqual(gp, "CENTER"); assertEqual(grel, slot)
        assertEqual(f.glow:GetWidth(), size * 50 / 40, "the glow at the slot's size (" .. size .. " px)")
    end
end)

test("ammo picker: its rim takes the flyout's tint while the window shows, and gets its own back", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = ammoInstance(hunterBags("bow_ranged"), { paint = true })
    local visible = true
    NS.Dock.IsVisible = function() return visible end
    rawget(M.CharacterAmmoSlot, "popoutButton"):__fire("OnClick")
    local f = picker(M)
    local r, g, b = NS.Skin.Color("win.border")
    -- red under: a picker outside QS.TintSync (gold beside a tinted flyout).
    assertTrue(f.bg1:IsDesaturated(), "desaturated")
    local vr, vg, vb = f.bg1:GetVertexColor()
    assertEqual(table.concat({ vr, vg, vb }, ","), table.concat({ r, g, b }, ","))
    visible = false
    NS.QuickSlots.TintSync()
    assertFalse(f.bg1:IsDesaturated(), "Blizzard's own back with the window gone")
    vr, vg, vb = f.bg1:GetVertexColor()
    assertEqual(table.concat({ vr, vg, vb }, ","), "1,1,1")
    visible = true
    NS.QuickSlots.TintSync()
    NS.QuickSlots.Ammo.Close()
    assertFalse(f.bg2:IsDesaturated(), "and with the picker closed")
end)
