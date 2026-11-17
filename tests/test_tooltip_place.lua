-- tests/test_tooltip_place.lua — AD-92-OR (LibKa0s#92): where this addon's own tooltips open
-- (WowAddonStandards standalone-windows, *Tooltip placement*).
--
-- Every tooltip this addon places itself is a BODY element's: a row of the outfit window (a category,
-- an outfit, an item), the EM mark inside an outfit row, and a button of the outfit bar. Each is owned
-- at ANCHOR_NONE, filled, shown, and then placed by LibKa0s-Tooltip-1.0's PlaceBeside against the
-- whole window group (the window; the whole bar), through NS.PlaceBodyTip (core/CoreSetup.lua). The
-- title-bar controls are chrome and attach above their control (test_titlebar). The addon's own
-- compare tooltips are in scope on an item row (body rule 5: chained further out on the side the
-- row's tooltip took; this file and test_tooltips' compare cases) and out of scope on a bag, sheet
-- or link hover, where GameTooltip is the client's. Out of scope, and held to that by the guard
-- below: the toggle button on the client's character frame (a Blizzard frame).
--
-- The surface cases spy on the instance's own PlaceBeside (its call shape, calling straight
-- through); the geometry case drives the kit's fake screen (tests/_kit/mock_screen.lua, revision 57)
-- through a right-fits and a right-does-not-fit layout.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil
local dockScene = dofile(T.root .. "/tests/dock_scene.lua")(T)
local B = dofile(T.root .. "/tests/bar_scene.lua")(T)

--- Record every PlaceBeside on `M`'s Tooltip major: the tooltip, the element, the group, and the
--- anchor the tooltip was owned at when it was placed. Answers the list.
local function spyBeside(M)
    local Tip = M.LibStub("LibKa0s-Tooltip-1.0")
    local calls, orig = {}, Tip.PlaceBeside
    Tip.PlaceBeside = function(tip, el, group, opts)
        calls[#calls + 1] = { tip = tip, el = el, group = group, anchor = rawget(tip, "__anchor"),
                              shown = tip:IsShown() == true }
        return orig(tip, el, group, opts)
    end
    return calls
end

--- The one placement a hover made: beside `group`, against `el`, owned at ANCHOR_NONE and shown.
local function assertBeside(calls, el, group, what)
    assertEqual(#calls, 1, what .. ": not placed by PlaceBeside exactly once")
    local c = calls[1]
    assertTrue(c.el == el, what .. ": placed against another element")
    assertTrue(c.group == group, what .. ": placed against another group")
    -- red under: SetOwner(el, "ANCHOR_RIGHT"), a corner offset (anti-pattern #119).
    assertEqual(c.anchor, "ANCHOR_NONE", what .. ": owned at " .. tostring(c.anchor))
    assertTrue(c.shown, what .. ": placed before Show (no size to measure)")
end

-- ── the placement itself, on the fake screen ──────────────────────────────────────────────────

test("tooltip place: a body tooltip opens right of the group, top level with the element, else left", function()
    local M = T.mocks
    local NS = T.NS
    local scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local ok, err = pcall(function()
        local win = scr.frame{ left = 400, bottom = 300, width = 300, height = 400 }
        local row = scr.frame{ left = 400, bottom = 580, width = 300, height = 20, parent = win }
        local tip = scr.tooltip{ width = 250, height = 90 }
        NS.PlaceBodyTip(tip, row, win)
        local l, _, _, t = scr.rectOf(tip)
        -- red under: a placement at the row's corner (ANCHOR_RIGHT puts it at the row's top right).
        assertEqual(l, 702, "right: the tooltip's left is the group's right edge + 2")
        assertEqual(t, 600, "right: the tooltip's top is the row's top")
        win:__place(1500, 300, 300, 400)
        row:__place(1500, 580, 300, 20)
        NS.PlaceBodyTip(tip, row, win)
        local _, _, r, t2 = scr.rectOf(tip)
        assertEqual(r, 1498, "left: the tooltip's right is the group's left edge - 2")
        assertEqual(t2, 600, "left: the tooltip's top is the row's top")
    end)
    scr.restore()
    if not ok then error(err, 0) end
end)

-- The anchor type of `tip`'s last SetAnchorType (the comparison side the placer handed the client).
local function lastAnchorType(tip)
    local found
    for _, e in ipairs(tip.__log or {}) do
        if e.op == "SetAnchorType" then found = e.anchor end
    end
    return found
end

test("tooltip place: the comparison side follows the side taken, and the side is remembered for its owner", function()
    local NS, M = T.NS, T.mocks
    local scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local ok, err = pcall(function()
        local win = scr.frame{ left = 400, bottom = 300, width = 300, height = 400 }
        local row = scr.frame{ left = 400, bottom = 580, width = 300, height = 20, parent = win }
        local tip = scr.tooltip{ width = 250, height = 90 }
        tip:SetOwner(row, "ANCHOR_NONE")
        assertEqual(NS.PlaceBodyTip(tip, row, win), "right")
        -- red under: PlaceBeside called with comparisons = false (the stock shopping pair would
        -- keep the client's own side and open back over the window).
        assertEqual(lastAnchorType(tip), "ANCHOR_RIGHT", "right: the comparisons go right")
        -- red under: NS.PlaceBodyTip not remembering its side (Compare.Placement falls back to the
        -- screen half with more room: left here, back over the tooltip and the window).
        assertEqual(NS.BodyTipSide(tip), "right", "the side is remembered")
        win:__place(1500, 300, 300, 400)
        row:__place(1500, 580, 300, 20)
        assertEqual(NS.PlaceBodyTip(tip, row, win), "left")
        assertEqual(lastAnchorType(tip), "ANCHOR_LEFT", "left: the comparisons go left")
        assertEqual(NS.BodyTipSide(tip), "left")
        tip:SetOwner(M.UIParent, "ANCHOR_NONE")
        -- red under: a record that outlives its owner (a bag hover would take a row's side).
        assertNil(NS.BodyTipSide(tip), "re-owned: the client's tooltip again")
    end)
    scr.restore()
    if not ok then error(err, 0) end
end)

test("tooltip place: a body tooltip that grows after it is placed is placed again", function()
    local NS, M = T.NS, T.mocks
    local scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local ok, err = pcall(function()
        local win = scr.frame{ left = 400, bottom = 60, width = 300, height = 400 }
        local row = scr.frame{ left = 400, bottom = 80, width = 300, height = 20, parent = win }
        local tip = scr.tooltip{ width = 250, height = 90 }
        tip:SetOwner(row, "ANCHOR_NONE")
        NS.PlaceBodyTip(tip, row, win)
        local _, b0, _, t0 = scr.rectOf(tip)
        assertEqual(t0, 100, "placed: top level with the row")
        assertEqual(b0, 10)
        tip:__size(250, 300)                  -- the item's data arrived: it grew below the screen
        -- red under: no NS.ReplaceBodyTip (the item post-call leaves the stale clamp).
        assertEqual(NS.ReplaceBodyTip(tip), "right")
        local _, b1, _, t1 = scr.rectOf(tip)
        assertEqual(t1, 300, "placed again: slid up just enough to stay on the screen")
        assertEqual(b1, 0)
        tip:SetOwner(M.UIParent, "ANCHOR_NONE")
        assertNil(NS.ReplaceBodyTip(tip), "a tooltip this addon no longer owns is not moved")
    end)
    scr.restore()
    if not ok then error(err, 0) end
end)

test("tooltip place: unreadable geometry attaches above the element, never at the cursor", function()
    local NS, M = T.NS, T.mocks
    local scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local ok, err = pcall(function()
        local el = scr.frame{}               -- an unplaced element: no placer can read it
        local tip = scr.tooltip{ width = 250, height = 90 }
        NS.PlaceBodyTip(tip, el, el)
        local p = tip.__point
        assertTrue(p ~= nil, "nothing placed")
        assertEqual(("%s %s %s %d %d"):format(p.point, tostring(p.rel == el), p.relPoint, p.x, p.y), "BOTTOM true TOP 0 2")
        assertTrue(not scr.ops(tip):find("SetAnchorType", 1, true), "a comparison side was set on the fallback")
    end)
    scr.restore()
    if not ok then error(err, 0) end
end)

-- ── the outfit window ─────────────────────────────────────────────────────────────────────────

local function opened()
    local NS, M = dockScene()
    for i = 1, 3 do NS.Outfits.Create(("Outfit %02d"):format(i), { HeadSlot = { id = 0 } }) end
    M.__world:openCharacter()
    NS.Dock.Open()
    return NS, M
end

local function rowOf(NS, kind)
    for _, row in ipairs(NS.WindowRows.rows) do
        local e = row.entry
        if e and e.kind == kind and (kind ~= "category" or e.desc) then return row end
    end
    return nil
end

test("tooltip place: a category row's tooltip opens beside the outfit window", function()
    local NS, M = opened()
    local row = rowOf(NS, "category")
    assertTrue(row ~= nil, "no category row with a description")
    local calls = spyBeside(M)
    row:__fire("OnEnter")
    assertBeside(calls, row, NS.Window.Frame(), "category row")
    assertEqual(M.GameTooltip.TextLeft1:GetText(), row.entry.label)
end)

test("tooltip place: the EM mark's tooltip opens beside the outfit window, top level with the mark", function()
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local calls = spyBeside(M)
    row.em:__fire("OnEnter")
    assertBeside(calls, row.em, NS.Window.Frame(), "EM mark")
    assertEqual(M.GameTooltip.TextLeft1:GetText(), "Not stored in the Equipment Manager")
end)

test("tooltip place: an item row's tooltip opens beside the outfit window", function()
    local NS, M = opened()
    local row = NS.WindowRows.rows[1]
    row.entry = { kind = "item", id = "loose:1", depth = 1, item = { id = 0, name = "Item", loc = { slotID = 1 } } }
    local calls = spyBeside(M)
    row:__fire("OnEnter")
    assertBeside(calls, row, NS.Window.Frame(), "item row")
end)

test("tooltip place: an item row hands the side it took to the compare tooltips, after placing", function()
    local NS, M = opened()
    local row = NS.WindowRows.rows[1]
    row.entry = { kind = "item", id = "loose:1", depth = 1, item = { id = 0, name = "Item", loc = { slotID = 1 } } }
    local Tip = M.LibStub("LibKa0s-Tooltip-1.0")
    local order, side = {}, "left"
    Tip.PlaceBeside = function() order[#order + 1] = "placed"; return side end
    NS.Compare.Reside = function()
        order[#order + 1] = "reside"
        -- what Compare.Placement reads when ours are drawn again
        order[#order + 1] = tostring(NS.BodyTipSide(M.GameTooltip))
    end
    row:__fire("OnEnter")
    -- red under: no Compare.Reside after the placement (a compare the client ran first keeps the
    -- screen-half side), or a side not remembered (Placement cannot follow it).
    assertEqual(table.concat(order, " "), "placed reside left")
    assertEqual(select(2, NS.Compare.Placement()), false, "ours go left with the item tooltip")
    order, side = {}, "right"
    row:__fire("OnEnter")
    assertEqual(table.concat(order, " "), "placed reside right")
    assertTrue(select(2, NS.Compare.Placement()), "ours go right with the item tooltip")
end)

test("tooltip place: a sample outfit row's tooltip opens beside the outfit window", function()
    local NS, M = opened()
    local row = NS.WindowRows.rows[1]
    row.entry = { kind = "outfit", id = "preview:1", depth = 1, placeholder = true, rec = { name = "Sample", em = false } }
    local calls = spyBeside(M)
    row:__fire("OnEnter")
    assertBeside(calls, row, NS.Window.Frame(), "sample outfit row")
    assertEqual(M.GameTooltip.TextLeft1:GetText(), "Sample")
end)

test("tooltip place: an outfit row hands the outfit window to the outfit tooltip as its group", function()
    local NS = opened()
    local row = rowOf(NS, "outfit")
    local tip = T.fake(NS, "OutfitTooltip", { Show = function() return false end })
    row:__fire("OnEnter")
    assertEqual(tip.__calls[1][2], row.entry.id)
    assertTrue(tip.__calls[1][3] == row, "the owner is not the row")
    -- red under: the retired anchor argument ("ANCHOR_RIGHT") in the group's place.
    assertTrue(tip.__calls[1][4] == NS.Window.Frame(), "the group is not the outfit window")
end)

-- ── the outfit tooltip ────────────────────────────────────────────────────────────────────────

test("tooltip place: the outfit tooltip is owned at ANCHOR_NONE and placed beside the group it is given", function()
    local NS, M = opened()
    local id = NS.Outfits.Create("Plain", { HeadSlot = { id = 0 } })
    local owner = NS.WindowRows.rows[1]
    local calls = spyBeside(M)
    assertTrue(NS.OutfitTooltip.Show(id, owner, NS.Window.Frame(), true))
    assertBeside(calls, owner, NS.Window.Frame(), "outfit tooltip")
    assertEqual(M.GameTooltip.TextLeft1:GetText(), "Plain")
end)

-- ── the outfit bar ────────────────────────────────────────────────────────────────────────────

local function shownBar()
    local NS, M, Bar = B.scene()
    local hat = B.accessory(NS, "Hat")
    B.settle(M)
    return NS, M, Bar, hat
end

test("tooltip place: a bar button's outfit tooltip takes the whole bar as its group, with always", function()
    local NS, _, Bar, hat = shownBar()
    local tip = T.fake(NS, "OutfitTooltip", { Show = function() return false end })
    local btn = B.buttonFor(Bar, hat)
    btn:__fire("OnEnter")
    assertTrue(tip.__calls[1][3] == btn, "the owner is not the button")
    -- red under: the retired anchor argument ("ANCHOR_RIGHT"): the group is the whole display.
    assertTrue(tip.__calls[1][4] == Bar.Frame(), "the group is not the whole bar")
    assertEqual(tip.__calls[1][5], true)
end)

test("tooltip place: a sample bar button's tooltip opens beside the whole bar", function()
    local _, M, Bar, hat = shownBar()
    local btn = B.buttonFor(Bar, hat)
    rawset(btn, "outfit", { id = "preview:1", name = "Sample", placeholder = true })
    local calls = spyBeside(M)
    btn:__fire("OnEnter")
    assertBeside(calls, btn, Bar.Frame(), "sample bar button")
    assertEqual(M.GameTooltip.TextLeft1:GetText(), "Sample")
end)

-- ── the guard ─────────────────────────────────────────────────────────────────────────────────

-- The out-of-scope sites, closed (docs/ARCHITECTURE.md, *Tooltip placement*): the character
-- frame's toggle button (Blizzard's frame).
local ALLOWED = { ["modules/Dock.lua"] = 1 }

test("tooltip place: no source file owns a tooltip at the cursor or a corner anchor", function()
    local out = {}
    for _, dir in ipairs({ "core", "modules" }) do
        local p = io.popen('git -C "' .. T.root .. '" ls-files --cached --others --exclude-standard -- "' .. dir .. '/*.lua"')
        for path in p:lines() do out[#out + 1] = path end
        p:close()
    end
    assertTrue(#out > 0, "no source files found")
    local bad = {}
    for _, path in ipairs(out) do
        local fh = io.open(T.root .. "/" .. path, "rb")
        local text = fh and fh:read("*a") or ""
        if fh then fh:close() end
        local n = 0
        for anchor in text:gmatch('SetOwner%b()') do
            local a = anchor:match('"(ANCHOR_[%u_]+)"')
            if a and a ~= "ANCHOR_NONE" then n = n + 1 end
        end
        if text:find("ANCHOR_CURSOR", 1, true) or text:find("GetCursorPosition", 1, true) then n = n + 100 end
        if n ~= (ALLOWED[path] or 0) then bad[#bad + 1] = path .. " (" .. n .. ")" end
    end
    -- red under: any SetOwner(x, "ANCHOR_RIGHT") left in Window_Rows, Bar_Buttons or OutfitTooltip.
    assertEqual(table.concat(bad, ", "), "")
end)
