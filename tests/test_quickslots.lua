-- tests/test_quickslots.lua — P4.18's flyout quick slots (design §7.9, INV §3.11): modules/QuickSlots.lua's
-- hooks and modules/QuickSlots_Sort.lua's upgrade-track sort.
--
-- The sort is pinned against the legacy capture (tests/fixtures/legacy/quickslots.lua) flyout by
-- flyout, through the whole client path: each fixture item sits in bag 0 at the slot of its index,
-- so a location unpacks through Compat.FlyoutLocationData, its link comes through the container
-- read, and its name, level and track through the C_Item reads the case answers. Then the upgrade
-- answer (a raise reads as "the game won't say", and the headroom fallback takes over), the untracked
-- banding, the specials and "place in bags", the equipped-item filter, the PostClick that opens or
-- closes the flyout, the secret or void location, and the two gates every hook body reads: the latch
-- and `quickSlots.enabled`. The outward drawer's cases are tests/test_drawer.lua.
--
-- THE FLYOUT STAND-IN. The mock's PaperDollItemsFrame.flyoutSettings gets the two functions the
-- client's flyout calls, marked hookable (the mock's hooksecurefunc would then really post-hook it,
-- mock_world.lua), so a case sees that nothing hooks them any more (FLY-TAINT-01). EquipmentFlyoutFrame
-- has Blizzard's `buttons` (plain stand-ins that record their anchor) and `buttonFrame`, and
-- EquipmentFlyout_UpdateItems copies Blizzard's display list (`M.__flyout.list`) into the buttons'
-- `location`, showing one per entry, as EquipmentFlyout.lua:285-286 does; the module's post-hook then
-- arranges the buttons. hooksecurefunc by name hooks the globals as the client does.
--
-- No module QuickSlots calls is owned by a later group, so no case installs a fake (design §12).

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db

-- The client's packed-location bits (ITEM_INVENTORY_LOCATION_*), as the gear mock answers them.
local PLAYER, BAGS, BANK = 0x00100000, 0x00200000, 0x00400000
-- The flyout's special entries, as this suite's stand-in client defines them: every location at or
-- above FIRST_SPECIAL is the flyout's own (ignore slot, place in bags), never an item.
local FIRST_SPECIAL, UNIGNORE, PLACE_IN_BAGS = 0xFFFFFFFC, 0xFFFFFFFD, 0xFFFFFFFE

local function bagLoc(bag, slot) return PLAYER + BAGS + bag * 256 + slot end

local function QS(NS) return NS.QuickSlots end

-- ── the instances ────────────────────────────────────────────────────────────────────────────────

-- One of Blizzard's flyout item buttons, as far as the arrangement reads it: shown or not, 37 px wide,
-- and the one anchor it was last given (`pt`: point, relative, relative point, x, y).
local function flyoutButton()
    local b = { shown = false, w = 37 }
    function b:IsShown() return self.shown end
    function b:Show() self.shown = true end
    function b:Hide() self.shown = false end
    function b:GetWidth() return self.w end
    function b:ClearAllPoints() self.pt = nil end
    function b:SetPoint(...) self.pt = { ... } end
    return b
end

-- An instance with the flyout stand-in installed, a gear scenario loaded, and the hooks built
-- (Resume is the lifecycle's stand-up, which is where the hooks are built). `M.__flyout` records
-- what the hooks asked of the client: the popout buttons clicked and the hides.
local function flyoutInstance(scenario)
    local inst = unitLoad({ mutate = function(M)
        if scenario then M.__gear:load(scenario) end
        local rec = { source = {}, clicked = {}, hidden = 0 }
        M.__flyout = rec
        local fs = M.PaperDollItemsFrame.flyoutSettings
        fs.getItemsFunc = function(_, itemTable)
            for location, itemID in pairs(rec.source) do itemTable[location] = itemID end
        end
        fs.postGetItemsFunc = function(_, display, numItems)
            table.insert(display, 1, PLACE_IN_BAGS)
            return numItems + 1
        end
        M.__hookable[fs] = true
        M.EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION = FIRST_SPECIAL
        M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
        local frame = M.CreateFrame("Frame", "EquipmentFlyoutFrame", M.UIParent)
        frame:Hide()
        frame.buttonFrame = M.CreateFrame("Frame", nil, frame)
        frame.buttons = {}
        rec.list = {}
        M.EquipmentFlyout_UpdateItems = function()
            for i, loc in ipairs(rec.list) do
                local b = frame.buttons[i]
                if not b then
                    -- EquipmentFlyout_CreateButton's cell, set once at creation (EquipmentFlyout.lua:64-70)
                    b = flyoutButton()
                    local row, col = math.floor((i - 1) / 5), (i - 1) % 5
                    b:SetPoint("TOPLEFT", frame.buttonFrame, "TOPLEFT", 3 + col * 41, -3 - row * 42)
                end
                frame.buttons[i] = b
                b.location = loc
                b:Show()
            end
            for i = #rec.list + 1, #frame.buttons do frame.buttons[i]:Hide() end
        end
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(a, b, c)
            if type(a) == "string" then
                local orig = rawget(M, a)
                if type(orig) ~= "function" then error("hooksecurefunc(): " .. a .. " is not a function", 2) end
                rawset(M, a, function(...) orig(...); b(...) end)
                M.__hooks[#M.__hooks + 1] = { target = M, name = a }
                return
            end
            return base(a, b, c)
        end
        M.EquipmentFlyout_Hide = function()
            rec.hidden = rec.hidden + 1
            frame.button = nil
            frame:Hide()
        end
        -- The client's toggle (EquipmentFlyoutPopoutButton_OnClick): it keys on flyoutLocked, and
        -- EquipmentFlyout_Hide above leaves the lock as it was.
        M.EquipmentFlyoutPopoutButton_OnClick = function(popout)
            rec.clicked[#rec.clicked + 1] = popout
            if popout.flyoutLocked then
                popout.flyoutLocked, popout.reversed = false, false
                M.EquipmentFlyout_Hide()
            else
                popout.flyoutLocked, popout.reversed = true, true
                frame.button = popout.owner
                frame:Show()
            end
        end
        for _, b in pairs(M.__slotButtons) do b.popoutButton = { owner = b } end
    end })
    QS(inst.NS).Resume()
    return inst, inst.NS, inst.mocks
end

-- How many post-hooks the mock recorded on the flyout settings.
local function flyoutHooks(M)
    local n = 0
    for _, h in ipairs(M.__hooks) do
        if h.target == M.PaperDollItemsFrame.flyoutSettings then n = n + 1 end
    end
    return n
end

-- The client opening the flyout on `slot` with Blizzard's display `list`: the buttons filled, then the
-- post-hook. Answers the shown buttons' locations in drawn order (row by row, left to right).
local function openWith(M, slot, list)
    local frame = M.EquipmentFlyoutFrame
    frame.button = M.__slotButtons[slot]
    M.__flyout.list = list
    frame:Show()
    M.EquipmentFlyout_UpdateItems()
    local shown = {}
    for _, b in ipairs(frame.buttons) do if b:IsShown() then shown[#shown + 1] = b end end
    table.sort(shown, function(a, b)
        if a.pt[5] ~= b.pt[5] then return a.pt[5] > b.pt[5] end
        return a.pt[4] < b.pt[4]
    end)
    local out = {}
    for i, b in ipairs(shown) do out[i] = b.location end
    return out, shown
end

-- An instance whose client answers each bag 0 slot from `state.items` (a fixture flyout's items):
-- the link, the name and base level, the upgrade track, and the upgrade answer `state.canUpgrade`
-- (a function, so a case can make it raise).
local function sortInstance()
    local inst = unitLoad()
    local M = inst.mocks
    local state = { items = {}, canUpgrade = function() return false end }
    local function recOf(link) return state.items[tonumber(link:match("item:(%d+)"))] end
    M.C_Container.GetContainerItemLink = function(bag, slot)
        if bag == 0 and state.items[slot] then return "|cffffffff|Hitem:" .. slot .. "::|h[x]|h|r" end
        return nil
    end
    M.C_Item.GetItemInfo = function(link)
        local rec = recOf(link)
        if not rec then return nil end
        return rec.name, link, 1, rec.level
    end
    M.C_Item.GetItemUpgradeInfo = function(link)
        local rec = recOf(link)
        return rec and rec.track
    end
    M.C_Item.DoesItemExist = function(il) return il.bag == 0 and state.items[il.slot] ~= nil end
    M.C_ItemUpgrade.CanUpgradeItem = function(il) return state.canUpgrade(il.slot) end
    return inst, state
end

-- Sort `display` (fixture indexes and specials) as bag 0 locations; answer it in fixture indexes.
local function sortIndexes(NS, display)
    local locs = {}
    for i, v in ipairs(display) do locs[i] = (v < FIRST_SPECIAL) and bagLoc(0, v) or v end
    QS(NS).Sort.Items(locs, #locs)
    local out = {}
    for i, v in ipairs(locs) do out[i] = (v < FIRST_SPECIAL) and (v - bagLoc(0, 0)) or v end
    return table.concat(out, ",")
end

-- ── surface ──────────────────────────────────────────────────────────────────────────────────────

test("quickslots: NS.QuickSlots and its sort are published", function()
    local Q = QS(T.NS)
    assertEqual(type(Q), "table", "NS.QuickSlots")
    for _, name in ipairs({ "Install", "Suspend", "Resume", "SetEnabled" }) do
        assertEqual(type(Q[name]), "function", "QuickSlots." .. name)
    end
    for _, name in ipairs({ "Items", "PlaceInBagsLast", "CompareItemSortInfo", "ItemSortInfo",
                            "LocationItemLink", "ItemCanBeUpgraded", "ResolveUpgradableItems",
                            "AssignTrackBands" }) do
        assertEqual(type(Q.Sort[name]), "function", "QuickSlots.Sort." .. name)
    end
end)

test("quickslots: the hooks are post-hooks, built once however often the addon stands up", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local fs = M.PaperDollItemsFrame.flyoutSettings
    local get, post = fs.getItemsFunc, fs.postGetItemsFunc
    -- red under (FLY-TAINT-01): post-hooks on getItemsFunc and postGetItemsFunc, which wrote Blizzard's
    -- lists and so tainted every flyout button's location (the owner's ADDON_ACTION_BLOCKED)
    assertEqual(flyoutHooks(M), 0, "nothing hooks the flyout's settings")
    assertTrue(fs.getItemsFunc == get and fs.postGetItemsFunc == post, "the settings' functions are Blizzard's")
    local function updateHooks()
        local n = 0
        for _, h in ipairs(M.__hooks) do if h.name == "EquipmentFlyout_UpdateItems" then n = n + 1 end end
        return n
    end
    assertEqual(updateHooks(), 1, "EquipmentFlyout_UpdateItems is post-hooked")
    QS(NS).Resume()
    QS(NS).Install()
    QS(NS).SetEnabled(true)
    -- red under: dropping the `installed` guard in QuickSlots.Install (each stand-up hooks again).
    assertEqual(updateHooks(), 1, "a second stand-up hooked the flyout again")
    M.__slotButtons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#M.__flyout.clicked, 1, "a second stand-up hooked the slot button again")
end)

test("quickslots: a client without the flyout functions builds the slot hooks and raises nothing", function()
    -- The bare mock: flyoutSettings is an empty table. hooksecurefunc on a missing member raises in
    -- the client, so this instance's raises too.
    local inst = unitLoad({ mutate = function(M)
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(t, name, fn)
            if type(t) == "table" and type(rawget(t, name)) ~= "function" then
                error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2)
            end
            return base(t, name, fn)
        end
    end })
    -- red under: dropping the member check in QuickSlots.lua's hookFlyout.
    QS(inst.NS).Resume()
    assertEqual(flyoutHooks(inst.mocks), 0)
    assertEqual(type(inst.mocks.__slotButtons.HeadSlot:GetScript("PostClick")), "function",
        "the slot buttons are hooked regardless")
end)

-- ── the sort, against the legacy capture ─────────────────────────────────────────────────────────

test("quickslots: the sort equals the legacy capture, flyout by flyout", function()
    local inst, state = sortInstance()
    local flyouts = T.legacy.quickslots.flyouts
    assertTrue(#flyouts >= 5, "the capture holds no flyouts; nothing below can fail")
    for _, f in ipairs(flyouts) do
        state.items = f.items
        local upgradable = f.canUpgrade or {}
        state.canUpgrade = function(slot) return upgradable[slot] == true end
        local display = {}
        for i = 1, #f.items do display[i] = i end
        if f.special then display = { 1, UNIGNORE, 2 } end
        assertEqual(sortIndexes(inst.NS, display), table.concat(f.order, ","), f.name)
    end
end)

test("quickslots: CanUpgradeItem decides once any item answers yes; else the headroom does", function()
    local inst, state = sortInstance()
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    -- Both items have headroom; item 1's track tops out higher, item 2 is the one the game upgrades.
    state.items = {
        [1] = { name = "Hero", level = 600, track = track(2, 626, 2) },
        [2] = { name = "Champion", level = 610, track = track(1, 619, 2) },
    }
    state.canUpgrade = function() return false end
    -- No item answers yes, so the headroom decides: both keep their tracks, the higher one first.
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "1,2", "the headroom fallback")
    state.canUpgrade = function(slot) return slot == 2 end
    -- red under: ResolveUpgradableItems reading HasUpgradeHeadroom regardless of the answer.
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "2,1", "a yes from the game outranks the headroom")
end)

test("quickslots: a raising CanUpgradeItem reads as 'the game won't say', and the sort goes on", function()
    local inst, state = sortInstance()
    local Sort = QS(inst.NS).Sort
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    state.items = {
        [1] = { name = "Champion", level = 600, track = track(1, 610, 2) },
        [2] = { name = "Old Hero", level = 590, track = track(2, 626, 8) },
    }
    state.canUpgrade = function() error("CanUpgradeItem: not at an upgrade vendor") end
    -- red under: calling C_ItemUpgrade.CanUpgradeItem unprotected (Compat.CanUpgradeItem's pcall).
    assertNil(Sort.ItemCanBeUpgraded({ bag = 0, slot = 1 }), "a raise is no answer")
    -- red under: reading a raise as a yes (item 2 would keep its 626 track and come first).
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "1,2", "the headroom fallback after a raise")
    assertNil(Sort.ItemCanBeUpgraded(nil), "no location, no answer")
    state.canUpgrade = function() return true end
    assertNil(Sort.ItemCanBeUpgraded({ bag = 0, slot = 9 }), "no item there, no answer")
    assertEqual(Sort.ItemCanBeUpgraded({ bag = 0, slot = 1 }), true)
end)

test("quickslots: an untracked item joins the highest track whose range starts at or below it", function()
    local inst, state = sortInstance()
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    state.items = {
        [1] = { name = "Champion", level = 600, track = track(1, 610, 2) },
        [2] = { name = "Hero", level = 615, track = track(2, 626, 2) },
        [3] = { name = "Crafted high", level = 620 },   -- in the Hero range (615+): ceiling 626
        [4] = { name = "Crafted mid", level = 605 },    -- in the Champion range only: ceiling 610
        [5] = { name = "Crafted low", level = 500 },    -- below every range: stays at 0, last
    }
    -- red under: AssignTrackBands joining the LOWEST qualifying track (item 3 would sort after 2's
    -- track as a 610), or skipping the banding (items 3 and 4 would sink below every tracked item).
    assertEqual(sortIndexes(inst.NS, { 5, 4, 3, 2, 1 }), "3,2,4,1,5")
    local infos = { { OnTrack = false, Level = 640, TrackCeiling = 0 } }
    QS(inst.NS).Sort.AssignTrackBands(infos)
    assertEqual(infos[1].TrackCeiling, 0, "no tracked item in the flyout, nothing to band into")
end)

test("quickslots: an item the client cannot place keeps the defaults and sorts last", function()
    local inst, state = sortInstance()
    state.items = { [1] = { name = "Here", level = 600 } }
    local info = QS(inst.NS).Sort.ItemSortInfo(bagLoc(0, 7), 3)
    assertEqual(info.Location, bagLoc(0, 7))
    assertEqual(info.Index, 3)
    assertEqual(info.Level, 0)
    assertEqual(info.TrackCeiling, 0)
    assertNil(info.Name)
    assertNil(info.HasTrack)
    assertEqual(sortIndexes(inst.NS, { 7, 1 }), "1,7")
end)

-- ── the specials and "place in bags" ─────────────────────────────────────────────────────────────

test("quickslots: the buttons are drawn sorted, 'place in bags' last; Blizzard's list is never written", function()
    local inst, state = sortInstance()
    local M = inst.mocks
    state.items = { [1] = { name = "Low", level = 500 }, [2] = { name = "High", level = 700 } }
    M.EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION = FIRST_SPECIAL
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    local buttons = {}
    for i, loc in ipairs({ PLACE_IN_BAGS, bagLoc(0, 1), bagLoc(0, 2) }) do
        buttons[i] = flyoutButton(); buttons[i].location = loc; buttons[i]:Show()
    end
    local order = QS(inst.NS).FlyoutOrder(buttons)
    assertEqual(order[1].location, bagLoc(0, 2), "High first")
    assertEqual(order[2].location, bagLoc(0, 1), "Low second")
    -- red under: dropping Sort.PlaceInBagsLast from the order.
    assertEqual(order[3].location, PLACE_IN_BAGS, "place in bags last")
    assertEqual(#order, 3, "nothing added or lost")
    -- the buttons keep the locations Blizzard gave them: only the drawn order is this addon's
    assertEqual(buttons[1].location, PLACE_IN_BAGS)
    assertEqual(buttons[2].location, bagLoc(0, 1))
    -- a location that is not a plain number leaves Blizzard's order
    buttons[2].location = T.secret(bagLoc(0, 1))
    assertNil(QS(inst.NS).FlyoutOrder(buttons), "a secret location: Blizzard's order")
end)

test("quickslots: the flyout's buttons go to Blizzard's grid cells in the sorted order", function()
    local _, _, M = flyoutInstance("secret_slots")
    M.EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION = FIRST_SPECIAL
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    local list = { PLACE_IN_BAGS }
    for slot = 1, 6 do list[#list + 1] = bagLoc(1, slot) end
    local copy = { unpack(list) }
    local drawn, shown = openWith(M, "LegsSlot", list)
    assertEqual(drawn[#drawn], PLACE_IN_BAGS, "place in bags drawn last")
    assertEqual(table.concat(M.__flyout.list, ","), table.concat(copy, ","), "Blizzard's list untouched")
    -- cells: 3 px in, 41 px apart (37 + 4), five to a row, a row 42 px down (37 - -5)
    local first, sixth = shown[1].pt, shown[6].pt
    assertTrue(first[2] == M.EquipmentFlyoutFrame.buttonFrame and first[1] == "TOPLEFT", "anchored to the item frame")
    assertEqual(first[4], 3); assertEqual(first[5], -3)
    assertEqual(shown[2].pt[4], 44)
    assertEqual(sixth[4], 3); assertEqual(sixth[5], -45, "the sixth starts the second row")
end)

test("quickslots: a special entry anywhere but first stays where the flyout put it", function()
    local inst = unitLoad()
    local M, Sort = inst.mocks, QS(inst.NS).Sort
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    local t = { 11, PLACE_IN_BAGS, 12 }
    Sort.PlaceInBagsLast(t, 3)
    assertEqual(table.concat(t, ","), "11," .. PLACE_IN_BAGS .. ",12", "only a leading 'place in bags' moves")
    t = { PLACE_IN_BAGS, 11 }
    Sort.PlaceInBagsLast(t, 2)
    assertEqual(table.concat(t, ","), "11," .. PLACE_IN_BAGS)
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = nil
    t = { PLACE_IN_BAGS, 11 }
    Sort.PlaceInBagsLast(t, 2)
    assertEqual(t[1], PLACE_IN_BAGS, "a client without the constant moves nothing")
    t = { 5 }
    Sort.Items(t, 1)
    assertEqual(t[1], 5, "a one-item flyout is left alone")
end)

-- ── the filter ───────────────────────────────────────────────────────────────────────────────────

test("quickslots: items already on the player leave the flyout; bag and bank items stay", function()
    local _, _, M = flyoutInstance("secret_slots")
    local worn, carried = PLAYER + 5, bagLoc(0, 2)
    local banked, bankBag = PLAYER + BANK + 40, PLAYER + BANK + BAGS + 6 * 256 + 1
    local drawn = openWith(M, "LegsSlot", { worn, carried, banked, bankBag })
    local seen = {}
    for _, loc in ipairs(drawn) do seen[loc] = true end
    assertFalse(seen[worn] == true, "the worn chest is hidden")
    assertTrue(seen[carried], "a bag item stays")
    -- red under: a mask of PLAYER + BAGS only (the bank's main slots carry PLAYER + BANK and would
    -- read as worn).
    assertTrue(seen[banked], "a bank slot stays")
    assertTrue(seen[bankBag], "a bank bag item stays")
    assertEqual(#M.__flyout.list, 4, "hidden, never taken out of Blizzard's list")
end)

test("quickslots: off, the flyout gets Blizzard's order back once", function()
    local _, NS, M = flyoutInstance("secret_slots")
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    openWith(M, "LegsSlot", { PLACE_IN_BAGS, bagLoc(0, 2), PLAYER + 5 })
    NS.db.profile.quickSlots.enabled = false
    local drawn = openWith(M, "LegsSlot", { PLACE_IN_BAGS, bagLoc(0, 2), PLAYER + 5 })
    assertEqual(table.concat(drawn, ","), table.concat({ PLACE_IN_BAGS, bagLoc(0, 2), PLAYER + 5 }, ","),
        "Blizzard's own order and every item")
end)

-- ── PostClick ────────────────────────────────────────────────────────────────────────────────────

test("quickslots: an empty slot, or an item on the cursor, opens the flyout; a plain click does not", function()
    local _, _, M = flyoutInstance("secret_slots")
    local rec, buttons = M.__flyout, M.__slotButtons
    buttons.ChestSlot:__fire("PostClick", "LeftButton", false)
    -- red under: opening the flyout on every click (dropping the cursor / empty-slot condition).
    assertEqual(#rec.clicked, 0, "a click on a filled slot with an empty cursor leaves the flyout shut")
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 1, "an empty slot opens the flyout")
    assertTrue(rec.clicked[1] == buttons.LegsSlot.popoutButton, "through the slot's own popout button")
    M.CursorHasItem = function() return true end
    buttons.ChestSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 2, "an item on the cursor opens the flyout")
    M.CursorHasItem = function() return false end
    -- The helm's link is a secret: it reads as an empty slot (Q12), so the click opens the flyout.
    buttons.HeadSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 3, "a secret link reads as an empty slot")
    assertEqual(rec.hidden, 0)
end)

test("quickslots: a click on the button the flyout is open on closes it", function()
    local _, _, M = flyoutInstance("secret_slots")
    local rec, buttons = M.__flyout, M.__slotButtons
    local flyout = M.EquipmentFlyoutFrame
    flyout:Show()
    flyout.button = buttons.LegsSlot
    buttons.LegsSlot:__fire("PreClick", "LeftButton", false)
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    -- red under: dropping the open-on-this-button branch (the empty Legs slot would open it again).
    assertEqual(rec.hidden, 1, "the open flyout is closed")
    assertEqual(#rec.clicked, 0, "and not reopened")
    flyout:Show()
    flyout.button = buttons.ChestSlot
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(rec.hidden, 1, "a flyout open on another button is not this click's to close")
    assertEqual(#rec.clicked, 1, "the empty slot opens its own")
end)

test("quickslots: an empty slot opened, closed and clicked again opens again", function()
    local _, _, M = flyoutInstance("secret_slots")
    local legs = M.__slotButtons.LegsSlot
    local flyout = M.EquipmentFlyoutFrame
    legs:__fire("PostClick", "LeftButton", false)
    assertTrue(flyout:IsVisible() and flyout.button == legs, "the first click opens it")
    legs:__fire("PostClick", "LeftButton", false)
    assertFalse(flyout:IsVisible(), "the second closes it")
    -- red under: closing with a bare EquipmentFlyout_Hide (the lock stays set, and this click only
    -- unlocks it: the flyout stays shut).
    assertFalse(legs.popoutButton.flyoutLocked, "the close cleared the popout's lock")
    assertFalse(legs.popoutButton.reversed, "and turned its arrow back")
    legs:__fire("PostClick", "LeftButton", false)
    assertTrue(flyout:IsVisible() and flyout.button == legs, "the third opens it again")
end)

test("quickslots: a lock left set by a flyout closed elsewhere does not swallow the open", function()
    local _, _, M = flyoutInstance("secret_slots")
    local legs = M.__slotButtons.LegsSlot
    legs:__fire("PostClick", "LeftButton", false)
    M.EquipmentFlyout_Hide()                    -- Escape, or another frame closing it: the lock stays
    assertTrue(legs.popoutButton.flyoutLocked)
    legs:__fire("PostClick", "LeftButton", false)
    -- red under: one popout click for the open (it reads the stale lock and only unlocks).
    assertTrue(M.EquipmentFlyoutFrame:IsVisible(), "the click opened the flyout")
    assertTrue(legs.popoutButton.flyoutLocked)
end)

-- ── the location read ────────────────────────────────────────────────────────────────────────────

test("quickslots: a location reads its link through the seam; a secret, void or bogus one is nil", function()
    local inst = unitLoad({ mutate = function(M) M.__gear:load("secret_slots") end })
    local Sort, M = QS(inst.NS).Sort, inst.mocks
    local link, loc = Sort.LocationItemLink(bagLoc(0, 2))
    assertEqual(link, DB.ring_plain_a.link, "a carried item's link")
    assertEqual(loc.bag, 0)
    assertEqual(loc.slot, 2)
    link, loc = Sort.LocationItemLink(PLAYER + 5)
    assertEqual(link, DB.chest_plate.link, "a worn item's link")
    assertEqual(loc.slotID, 5)
    -- red under: reading the container link without the seam (the secret wrapper would come back).
    assertNil((Sort.LocationItemLink(bagLoc(0, 1))), "a secret bag link")
    assertNil((Sort.LocationItemLink(PLAYER + 1)), "a secret worn link")
    assertNil((Sort.LocationItemLink(T.secret(bagLoc(0, 2)))), "a secret location")
    assertNil((Sort.LocationItemLink(1)), "a location the client cannot unpack")
    local base = M.EquipmentManager_GetLocationData
    M.EquipmentManager_GetLocationData = function(location)
        if location == 77 then return { isPlayer = false, isBank = false, isBags = false, slot = 3 } end
        return base(location)
    end
    assertNil((Sort.LocationItemLink(77)), "void storage: neither bags, bank nor player")
end)

-- ── the gates ────────────────────────────────────────────────────────────────────────────────────

-- Every hook body's effect at once: the filter, the sort and the click.
local function hooksActed(M)
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    local drawn = openWith(M, "LegsSlot", { PLACE_IN_BAGS, bagLoc(0, 2), PLAYER + 5 })
    local filtered = #drawn == 2
    local sorted = drawn[#drawn] == PLACE_IN_BAGS
    M.EquipmentFlyout_Hide()
    local before = #M.__flyout.clicked
    M.__slotButtons.LegsSlot:__fire("PostClick", "LeftButton", false)
    return filtered, sorted, #M.__flyout.clicked > before
end

test("quickslots: every hook body stands down with the addon and comes back with it", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act while standing up; nothing below can fail")
    NS.ApplyEnabled(false)
    assertTrue(NS.IsStoodDown())
    filtered, sorted, opened = hooksActed(M)
    -- red under: dropping the `NS.IsStoodDown()` check from the shared gate in modules/QuickSlots.lua.
    assertFalse(filtered, "the filter ran while stood down")
    assertFalse(sorted, "the sort ran while stood down")
    assertFalse(opened, "PostClick opened the flyout while stood down")
    NS.ApplyEnabled(true)
    filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act again after the stand-up")
    assertEqual(flyoutHooks(M), 0, "the flyout's settings stay unhooked")
end)

test("quickslots: quickSlots.enabled off silences every hook body; on brings them back", function()
    local _, NS, M = flyoutInstance("secret_slots")
    NS.db.profile.quickSlots.enabled = false
    QS(NS).SetEnabled(false)
    local filtered, sorted, opened = hooksActed(M)
    -- red under: dropping the `quickSlots.enabled` read from the shared gate.
    assertFalse(filtered, "the filter ran with quick slots off")
    assertFalse(sorted, "the sort ran with quick slots off")
    assertFalse(opened, "PostClick opened the flyout with quick slots off")
    NS.db.profile.quickSlots.enabled = true
    QS(NS).SetEnabled(true)
    filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act again with quick slots on")
end)

test("quickslots: the stand-down owns nothing to tear down: no event, no timer, no frame", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local frames = #M.__shownFrames()
    QS(NS).Suspend()
    QS(NS).Resume()
    assertEqual(#M.__shownFrames(), frames, "QuickSlots owns no frames (design §7.9)")
end)
