local _, NS = ...
-- modules/QuickSlots_Ammo.lua — NS.QuickSlots.Ammo: WoW Forever's ammo picker (the owner's smoke
-- report, 2026-11-28). Extends NS.QuickSlots, as modules/QuickSlots_Sort.lua does.
--
-- WHY NOT BLIZZARD'S FLYOUT. EquipmentFlyout_Show lists what PaperDollItemsFrame.flyoutSettings
-- .getItemsFunc answers, which is GetInventoryItemsForSlot (F-UI Camelot/PaperDollFrame.lua:
-- 2573-2575), and for the ammo slot (inventory id 0) that answers nothing: the owner's probe printed
-- `ammo candidates: 0`. With nothing to list the flyout hides itself (Camelot/EquipmentFlyout.lua:
-- 304-307), so the arrow the drawer gave the ammo slot did nothing on an empty slot, and with ammo
-- worn it showed only "place in bags". Blizzard never opens its flyout on the ammo slot itself
-- (EquipmentFlyout_UpdateFlyout skips INVSLOT_AMMO, :648). Feeding ammo into Blizzard's list would
-- write the flyout's locations, which FLY-TAINT-01 stopped (modules/QuickSlots.lua's header).
--
-- SO THE PICKER IS THIS ADDON'S OWN FRAME, built on the first open, a child of CharacterAmmoSlot (it
-- hides with the sheet). It lists the carried ammo the ranged weapon fires (a bow or crossbow arrows,
-- a gun bullets, anything else every type), one button per type with its stacks summed, best item
-- level first. A click equips that type: its first stack is picked up and dropped on the ammo slot,
-- which is how the client equips ammo (the slot names a carried type; the stack stays in its bag).
-- There is no "place in bags": the owner's second probe showed Blizzard's unequip moves the stack but
-- leaves the slot naming it, and no client call clears the slot while the type is carried.
--
-- OUT OF COMBAT ONLY. The equip is a cursor write from addon code, which the client blocks in combat
-- (the ADDON_ACTION_BLOCKED of FLY-TAINT-01 was PickupInventoryItem). An open and an equip are
-- refused in lockdown with a line saying why, and PLAYER_REGEN_DISABLED closes an open picker. The
-- picker listens only while open (BAG_UPDATE_DELAYED and PLAYER_EQUIPMENT_CHANGED redraw it), and
-- every close drops its events, so a stood-down addon holds none.
--
-- THE ARROW (modules/QuickSlots.lua, ammoArrow) is a button of this addon's own, not Blizzard's
-- EquipmentFlyoutPopoutButtonTemplate, so Blizzard's popout list and its HideAll never reach it and
-- its click is this file's alone. Its `flyoutLocked` is this addon's field on this addon's frame: the
-- drawer paints the open art from it.
--
-- BLIZZARD'S FLYOUT ART, NOT THE SKIN (the accepted deviation DEV-SKIN-AMMO-PICKER, owner ruling
-- 2026-11-28; docs/ARCHITECTURE.md -> Documented deviations). The picker stands in for the flyout
-- every other slot opens, so it is drawn as EquipmentFlyout_UpdateItems draws that one (F-UI
-- Camelot/EquipmentFlyout.lua:327-531, EquipmentFlyout.xml): the parchment strips of
-- UI-GearManager-Flyout cut and laid for one slot, one row or several rows, the item frame sized and
-- anchored as Blizzard sizes and anchors buttonFrame (TOPLEFT to the arrow's TOPRIGHT plus the paper
-- doll's anchorX / anchorY, the arrow opening right as the drawer turns the ammo slot), ItemButtons in
-- Blizzard's grid painted by Blizzard's own SetItemButtonTexture / Count / Quality, the worn type left
-- out as Blizzard leaves the worn item out, and the gold slot glow (UI-GearManager-ItemButton-
-- Highlight). On WoW Forever neither sheet addon restyles the flyout (ChonkyCharacterSheet has no
-- flyout code; EllesmereUI's flyout skin stands down on Forever, EllesmereUIBlizzardSkin_
-- CharacterSheet.lua FlyoutSkinActive), so this is the look of the flyout beside it on every sheet.
-- What the sheets change is geometry, and the picker reads it live: it hangs off the arrow, which the
-- drawer sets flush when a sheet hides the slot's BorderFrame (Chonky), and the glow takes the slot's
-- own size (Chonky resizes the ammo slot; the stock one is 27 px, Camelot/PaperDollFrame.xml:874) by
-- the art's 50 : 40, centered on it. Its rim follows the flyout's tint while the outfit window shows
-- (DEV-SKIN-FLYOUT-TINT; QS.TintSync reads Ammo.RimTextures). A button's tooltip is the bag item's, a
-- body tooltip placed beside the picker (NS.PlaceBodyTip; docs/ARCHITECTURE.md, *Tooltip placement*).
--
-- CLIENT READS beyond the shared luacheck globals go through `_G` by name at call time:
-- CharacterAmmoSlot, CursorHasItem, GameTooltip, PaperDollItemsFrame and SetItemButtonTexture /
-- Count / Quality. Bags, links, counts and the cursor go through NS.Compat.

local QS = NS.QuickSlots
local Ammo = {}
QS.Ammo = Ammo

local Compat, Secrets, L = NS.Compat, NS.Secrets, NS.L

local ON = NS.PerClient({ retail = false, forever = true })
local AMMO_SLOT, RANGED_SLOT = 0, 18       -- INVSLOT_AMMO, INVSLOT_RANGED
local WEAPON, PROJECTILE = 2, 6            -- Enum.ItemClass
-- The projectile subclass a ranged weapon subclass fires (Enum.ItemWeaponSubclass Bows 2, Guns 3,
-- Crossbows 18 -> Enum.ItemProjectileSubclass Arrow 2, Bullet 3). Thrown and wands fire none.
local FIRES = { [2] = 2, [3] = 3, [18] = 2 }
local LAST_BAG = 4                          -- the backpack and four carried bags (quivers included)
-- Blizzard's flyout numbers (Camelot/EquipmentFlyout.lua:3-48): EQUIPMENTFLYOUT_ITEMS_PER_ROW,
-- EFITEM_WIDTH, EFITEM_XOFFSET, the row pitch EFITEM_HEIGHT - EFITEM_YOFFSET, EQUIPMENTFLYOUT_BORDERWIDTH
-- and EQUIPMENTFLYOUT_HEIGHT.
local PER_ROW, SIZE, GAP, PITCH, BORDER, HEIGHT = 5, 37, 4, 42, 3, 43
local ART = "Interface\\PaperDollInfoFrame\\UI-GearManager-Flyout"
local GLOW = "Interface\\PaperDollInfoFrame\\UI-GearManager-ItemButton-Highlight"
local GLOW_RATIO, GLOW_COORD = 50 / 40, 0.78125       -- EquipmentFlyout.xml: 50 px art for a 40 px slot
-- The strips (Camelot/EquipmentFlyout.lua:3-24): { left, right, top, bottom, width, height }.
local STRIP = {
    oneLeft  = { 0, 0.09765625, 0.5546875, 0.77734375, 25, 54 },
    oneRight = { 0.41796875, 0.51171875, 0.5546875, 0.77734375, 24, 54 },
    rowLeft  = { 0, 0.16796875, 0.5546875, 0.77734375, 43, 54 },
    rowMid   = { 0.16796875, 0.328125, 0.5546875, 0.77734375, 41, 54 },
    rowRight = { 0.328125, 0.51171875, 0.5546875, 0.77734375, 47, 54 },
    top      = { 0, 0.8359375, 0, 0.19140625, 214, 49 },
    middle   = { 0, 0.8359375, 0.19140625, 0.35546875, 214, 42 },
    bottom   = { 0, 0.8359375, 0.35546875, 0.546875, 214, 49 },
}
local EVENTS = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED" }

local frame                                 -- the picker, built on the first open

-- ── the list ──────────────────────────────────────────────────────────────────────────────────

-- The projectile subclass the worn ranged weapon fires, or nil (none worn, or one that fires none).
local function firedSubclass()
    local link = Compat.InventoryItemLink(RANGED_SLOT)
    if not link then return nil end
    local _, _, _, classID, subclassID = Compat.ItemInfoInstant(link)
    if classID ~= WEAPON then return nil end
    return FIRES[subclassID]
end

-- The bag slot's item as an ammo entry's fields, or nil when it is not ammo the weapon fires.
local function ammoAt(bag, slot, want)
    local link = Compat.ContainerItemLink(bag, slot)
    if not link then return nil end
    local id, _, icon, classID, subclassID = Compat.ItemInfoInstant(link)
    if not id or classID ~= PROJECTILE or (want and subclassID ~= want) then return nil end
    return id, icon, link
end

local function byLevel(a, b)
    if a.level ~= b.level then return a.level > b.level end
    if a.name ~= b.name then return a.name < b.name end
    return a.itemID < b.itemID
end

--- The carried ammo the worn ranged weapon fires (every type without one), one entry per type:
--- { itemID, icon, link, name, level, quality, count (the type's stacks summed), bag, slot (its first
--- stack) },
--- best item level first.
--- @return table[]
function Ammo.List()
    local want, byID, out = firedSubclass(), {}, {}
    for bag = 0, LAST_BAG do
        for slot = 1, Compat.ContainerNumSlots(bag) do
            local id, icon, link = ammoAt(bag, slot, want)
            local e = id and byID[id]
            if id and not e then
                local name, quality, level = Compat.ItemInfo(link)
                e = { itemID = id, icon = icon, link = link, name = name or "", level = level or 0,
                      quality = quality, count = 0, bag = bag, slot = slot }
                byID[id] = e
                out[#out + 1] = e
            end
            if e then e.count = e.count + Compat.ContainerItemCount(bag, slot) end
        end
    end
    table.sort(out, byLevel)
    return out
end

-- ── the equip ─────────────────────────────────────────────────────────────────────────────────

local function cursorHasItem()
    local fn = _G.CursorHasItem
    return type(fn) == "function" and Secrets.PlainTruth(fn()) == true
end

-- The first carried stack of `itemID` now (the bags may have moved since the list was drawn).
local function stackOf(itemID)
    for bag = 0, LAST_BAG do
        for slot = 1, Compat.ContainerNumSlots(bag) do
            local link = Compat.ContainerItemLink(bag, slot)
            if link and Compat.ItemInfoInstant(link) == itemID then return bag, slot end
        end
    end
    return nil
end

--- Equip ammo `entry` (one of Ammo.List's): its first carried stack dropped on the ammo slot. False,
--- with a line saying why, in combat lockdown; false when no stack of it is carried any more.
--- @param entry table
--- @return boolean
function Ammo.Equip(entry)
    if Compat.InCombatLockdown() then
        NS.Print(L["Ammo can't be changed in combat"])
        return false
    end
    if Compat.InventoryItemID(AMMO_SLOT) == entry.itemID then return true end
    local bag, slot = stackOf(entry.itemID)
    if not bag then return false end
    Compat.ClearCursor()
    Compat.PickupContainerItem(bag, slot)
    Compat.PickupInventoryItem(AMMO_SLOT)
    if cursorHasItem() then Compat.ClearCursor() end
    return true
end

-- ── the picker ────────────────────────────────────────────────────────────────────────────────

local function ammoSlot()
    local slot = _G.CharacterAmmoSlot
    return type(slot) == "table" and slot or nil
end

-- The arrow's open art follows the picker (the drawer paints it from flyoutLocked).
local function markArrow(open)
    local slot = ammoSlot()
    local pop = slot and rawget(slot, "popoutButton")
    if not pop then return end
    pop.flyoutLocked = open
    QS.PaintArrow(slot)
end

local function showTooltip(b)
    local tip = _G.GameTooltip
    if not (tip and b.entry) then return end
    tip:SetOwner(b, "ANCHOR_NONE")
    tip:SetBagItem(b.entry.bag, b.entry.slot)
    tip:Show()
    NS.PlaceBodyTip(tip, b, frame)
end

local function hideTooltip()
    local tip = _G.GameTooltip
    if tip then tip:Hide() end
end

local function onPick(b)
    if b.entry then Ammo.Equip(b.entry) end
    Ammo.Close()
end

-- Call Blizzard's item-button painter `name` on `b` when the client has it.
local function paint(name, b, ...)
    local fn = _G[name]
    if type(fn) == "function" then fn(b, ...) end
end

local function newButton(f)
    local b = CreateFrame("ItemButton", nil, f)
    b:SetScript("OnClick", onPick)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", hideTooltip)
    return b
end

-- Button `i` painted with `entry` in Blizzard's grid cell (EquipmentFlyout_CreateButton, :123-140).
local function fillButton(f, i, entry)
    local b = f.buttons[i] or newButton(f)
    f.buttons[i] = b
    b.entry = entry
    paint("SetItemButtonTexture", b, entry.icon)
    paint("SetItemButtonCount", b, entry.count)
    paint("SetItemButtonQuality", b, entry.quality, entry.itemID)
    local row, col = math.floor((i - 1) / PER_ROW), (i - 1) % PER_ROW
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", BORDER + col * (SIZE + GAP), -BORDER - row * PITCH)
    b:Show()
end

-- The strips for `n` buttons and whether each hangs below the last (else beside it), as
-- EquipmentFlyout_UpdateItems picks them (:436-525).
local function stripsFor(n)
    if n == 1 then return { STRIP.oneLeft, STRIP.oneRight }, false end
    local out = {}
    if n <= PER_ROW then
        out[1] = STRIP.rowLeft
        for _ = 2, n - 1 do out[#out + 1] = STRIP.rowMid end
        out[#out + 1] = STRIP.rowRight
        return out, false
    end
    out[1] = STRIP.top
    for _ = 2, math.ceil(n / PER_ROW) - 1 do out[#out + 1] = STRIP.middle end
    out[#out + 1] = STRIP.bottom
    return out, true
end

-- Strip `i` of the item frame, made the first time it is needed (as _createFlyoutBG makes bgN).
local function strip(f, i)
    local t = f["bg" .. i]
    if not t then
        t = f:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(ART)
        f["bg" .. i] = t
        f.numBGs = i
    end
    return t
end

-- The parchment laid for `n` buttons, the first strip 5 px out and 4 px up (EquipmentFlyout.xml bg1).
local function layStrips(f, n)
    local list, below = stripsFor(n)
    local last
    for i, s in ipairs(list) do
        local t = strip(f, i)
        t:ClearAllPoints()
        t:SetTexCoord(s[1], s[2], s[3], s[4])
        t:SetSize(s[5], s[6])
        if last == nil then
            t:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 4)
        else
            t:SetPoint("TOPLEFT", last, below and "BOTTOMLEFT" or "TOPRIGHT")
        end
        t:Show()
        last = t
    end
    for i = #list + 1, f.numBGs or 0 do f["bg" .. i]:Hide() end
end

-- The gold glow on the ammo slot at its own size, by the art's 50 : 40 (a sheet may resize the slot).
local function fitGlow(f, slot)
    local w, h = NS.SafeNumber(slot:GetWidth(), 0), NS.SafeNumber(slot:GetHeight(), 0)
    f.glow:ClearAllPoints()
    f.glow:SetPoint("CENTER", slot, "CENTER", 0, 0)
    if w > 0 and h > 0 then f.glow:SetSize(w * GLOW_RATIO, h * GLOW_RATIO) end
end

-- The carried ammo but the worn type, drawn into the item frame and sized as Blizzard sizes
-- buttonFrame (:427-428); false when there is nothing to draw.
local function draw(f)
    local worn, list = Compat.InventoryItemID(AMMO_SLOT), {}
    for _, e in ipairs(Ammo.List()) do
        if e.itemID ~= worn then list[#list + 1] = e end
    end
    if #list == 0 then return false end
    for i, entry in ipairs(list) do fillButton(f, i, entry) end
    for i = #list + 1, #f.buttons do f.buttons[i]:Hide(); f.buttons[i].entry = nil end
    local cols = math.min(#list, PER_ROW)
    f:SetSize(cols * SIZE + (cols - 1) * GAP + BORDER, HEIGHT + math.floor((#list - 1) / PER_ROW) * PITCH)
    layStrips(f, #list)
    return true
end

-- The line a refused open prints: none carried at all, or only the worn type.
local function nothingLine()
    if Compat.InventoryItemID(AMMO_SLOT) then return L["No other ammo in your bags"] end
    return L["No ammo in your bags"]
end

local function onEvent(f, event)
    if event == "PLAYER_REGEN_DISABLED" or not draw(f) then return Ammo.Close() end
    QS.TintSync()
end

local function build(slot)
    local f = CreateFrame("Frame", "OutfitterRebornAmmoPicker", slot)
    f:Hide()
    f:SetFrameStrata(NS.Constants.LAYERS.STRATA.FLYOUT)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.buttons, f.numBGs = {}, 0
    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture(GLOW)
    f.glow:SetTexCoord(0, GLOW_COORD, 0, GLOW_COORD)
    f:SetScript("OnEvent", onEvent)
    -- The sheet closing hides the picker with it: drop its events and the arrow's open art then too.
    f:SetScript("OnHide", function() Ammo.Close() end)
    return f
end

-- Blizzard's anchor for a flyout opening right: TOPLEFT to the arrow's (or the slot's) TOPRIGHT plus
-- the paper doll's anchorX / anchorY (Camelot/EquipmentFlyout.lua:420-433, PaperDollFrame.lua:354-364).
local function place(f, slot)
    local rel = rawget(slot, "popoutButton") or slot
    local items = _G.PaperDollItemsFrame
    local s = type(items) == "table" and type(items.flyoutSettings) == "table" and items.flyoutSettings or {}
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", rel, "TOPRIGHT", NS.SafeNumber(s.anchorX, 0), NS.SafeNumber(s.anchorY, 0))
    fitGlow(f, slot)
end

--- Whether the picker is on screen.
--- @return boolean
function Ammo.IsOpen()
    return frame ~= nil and frame:IsShown() == true
end

--- The picker's rim, the parchment strips it shows now, for QS.TintSync (DEV-SKIN-FLYOUT-TINT); none
--- while it is closed. The glow is the slot's, not the rim, and is left out as the flyout's is.
--- @return table[]
function Ammo.RimTextures()
    local out = {}
    if not Ammo.IsOpen() then return out end
    for i = 1, frame.numBGs do
        local t = frame["bg" .. i]
        if t:IsShown() then out[#out + 1] = t end
    end
    return out
end

--- Open the picker beside the ammo slot. Refused in combat lockdown and with nothing to list, each
--- with a line saying why; a no-op off WoW Forever or without the sheet's ammo slot.
function Ammo.Open()
    local slot = ammoSlot()
    if not ON or not slot then return end
    if Compat.InCombatLockdown() then return NS.Print(L["Ammo can't be changed in combat"]) end
    frame = frame or build(slot)
    if not draw(frame) then return NS.Print(nothingLine()) end
    place(frame, slot)
    for _, event in ipairs(EVENTS) do NS.SafeRegisterEvent(frame, event, nil, NS.rejectedEvents) end
    frame:Show()
    markArrow(true)
    QS.TintSync()
end

--- Close the picker and drop its events. Safe when it never opened.
function Ammo.Close()
    if not frame then return end
    frame:UnregisterAllEvents()
    if frame:IsShown() then frame:Hide() end
    markArrow(false)
    QS.TintSync()
end

--- The arrow's click: open, or close an open picker.
function Ammo.Toggle()
    if Ammo.IsOpen() then return Ammo.Close() end
    Ammo.Open()
end

--- The ammo slot's PostClick (modules/QuickSlots.lua): an open picker closes; with an item on the
--- cursor, or the slot empty, it opens, as a click opens every other slot's flyout.
--- @param button table the ammo slot
function Ammo.SlotClick(button)
    if Ammo.IsOpen() then return Ammo.Close() end
    local empty = not Compat.InventoryItemLink(button.id or button:GetID())
    if cursorHasItem() or empty then Ammo.Open() end
end
