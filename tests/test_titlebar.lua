-- tests/test_titlebar.lua — the title-bar controls of the windows this addon draws itself (LibKa0s
-- v1.105.0 smoke round 1, rulings 3 and 4; SR-OR of Ka0sAddonsCommonTasks
-- docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/SR1_SMOKE_ROUND1.md).
--
-- One case per window, over every control on its title band:
--   - a tooltip on hover: the game tooltip owned by the control, a non-empty first line in the
--     owner's `gtip.title`, hidden again on leave;
--   - its colors in every shipped skin, Ka0s Default first: `icon.tint` at rest for every control,
--     the close X included; under the pointer `text.link` for a mark (the window's gear, the bar's
--     lock) and `close.hot` for the close.
-- The windows: the outfit window (close, settings gear), the outfit bar (close, settings, lock) and
-- the four dialogs (close). Since AD-86-OR (LibKa0s#86) every one builds its marks with W.HeaderButtons
-- (NS.HeaderButtons, core/WidgetsSetup.lua): the strip cases at the end pin the order, the pitch, the
-- settings mark's click and the dialogs' recorded opt-out. The library's own windows (console, copy,
-- perf, sim, picker, icon browser) are the library's to pin. Every case builds its own instance through tests/skin_surfaces.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertNil, assertError = T.test, T.assertEqual, T.assertTrue, T.assertNil, T.assertError

local OWNER = "OutfitterReborn"

local function live()
    local facts = dofile(T.root .. "/tests/skin_surfaces.lua")(T)
    local NS, M = facts.live()
    return NS, M, M.LibStub("LibKa0s-Skin-1.0")
end

--- Switch the owner onto the kit's probe skin, which gives every token a value of its own
--- (tests/_kit/skin_switch.lua), so gtip.title is told apart from the tooltip's own gold.
local function probe(Skin)
    local W = dofile(T.root .. "/tests/_kit/skin_switch.lua")
    if not Skin:GetSkin(W.PROBE_KEY) then
        Skin:RegisterSkin({ key = W.PROBE_KEY, label = "Probe", tokens = W.probeTokens(Skin) })
    end
    Skin:SetChoice(OWNER, "ka0s", W.PROBE_KEY)
end

local function rgb(r, g, b) return ("%.3f %.3f %.3f"):format(r or -1, g or -1, b or -1) end
local function tint(tex) return rgb(tex:GetVertexColor()) end
local function token(NS, name) return rgb(NS.Skin.Color(name)) end

--- Every control's tooltip, under the probe skin: owned by it, a first line, in gtip.title, gone on
--- leave.
local function assertTips(NS, M, Skin, controls)
    local tip = M.GameTooltip
    probe(Skin)
    assertTrue(token(NS, "gtip.title") ~= rgb(1, 0.82, 0), "the probe's gtip.title is the tooltip's own gold")
    for _, c in ipairs(controls) do
        tip:Hide()
        c.btn:__fire("OnEnter")
        assertTrue(tip:IsShown(), c.name .. ": no tooltip on hover")
        assertTrue(tip:GetOwner() == c.btn, c.name .. ": the tooltip is not owned by the control")
        local line = tip.TextLeft1
        local words = line and line:GetText()
        assertTrue(type(words) == "string" and words ~= "", c.name .. ": the tooltip says nothing")
        assertEqual(rgb(line.__r, line.__g, line.__b), token(NS, "gtip.title"), c.name .. ": not in gtip.title")
        c.btn:__fire("OnLeave")
        assertTrue(not tip:IsShown(), c.name .. ": the tooltip stays up after leave")
    end
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
end

--- Every control's rest and hover colors under each shipped skin, Ka0s Default first.
local function assertColors(NS, Skin, controls)
    -- The shipped skins only: the probe gives close.rest a value of its own, which no shipped skin does.
    local W = dofile(T.root .. "/tests/_kit/skin_switch.lua")
    local keys = { "ka0s" }
    for _, def in ipairs(Skin:Skins()) do
        if def.key ~= "ka0s" and def.key ~= W.PROBE_KEY then keys[#keys + 1] = def.key end
    end
    assertTrue(#keys > 2, "too few shipped skins to switch through")
    local moved = false
    for _, key in ipairs(keys) do
        Skin:SetChoice(OWNER, "ka0s", key)
        local rest, link, hot = token(NS, "icon.tint"), token(NS, "text.link"), token(NS, "close.hot")
        if key ~= "ka0s" and rest ~= rgb(0.7, 0.7, 0.72) then moved = true end
        for _, c in ipairs(controls) do
            local what = key .. ": " .. c.name
            assertEqual(tint(c.btn.icon), rest, what .. " at rest is not icon.tint")
            c.btn:__fire("OnEnter")
            assertEqual(tint(c.btn.icon), c.close and hot or link,
                what .. " under the pointer is not " .. (c.close and "close.hot" or "text.link"))
            c.btn:__fire("OnLeave")
            assertEqual(tint(c.btn.icon), rest, what .. " did not go back to icon.tint")
        end
    end
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    assertTrue(moved, "no shipped skin moved icon.tint, so the walk proved nothing")
end

local function check(NS, M, Skin, controls)
    for _, c in ipairs(controls) do
        assertTrue(c.btn ~= nil and c.btn.icon ~= nil, c.name .. " was not built with art")
    end
    assertTips(NS, M, Skin, controls)
    assertColors(NS, Skin, controls)
end

test("title bar: the outfit window's close and gear carry tooltips and the skin's rest and hover colors", function()
    -- red under: modules/Window.lua's gear without NS.TitleControl (no tooltip, close.hot on hover).
    local NS, M, Skin = live()
    local win = M.OutfitterRebornWindow
    check(NS, M, Skin, {
        { name = "the window's close", btn = win.close, close = true },
        { name = "the window's gear", btn = win.settingsButton },
    })
end)

test("title bar: the outfit bar's close, settings and lock carry tooltips and the skin's rest and hover colors", function()
    -- red under: modules/Bar_Chrome.lua's lock painted by S.CloseButton (close.hot on hover) or its
    -- tooltip owned at ANCHOR_TOP in the tooltip's own color.
    local NS, M, Skin = live()
    local f = NS.Bar.Frame()
    check(NS, M, Skin, {
        { name = "the bar's close", btn = f.close, close = true },
        { name = "the bar's settings", btn = f.settingsButton },
        { name = "the bar's lock", btn = f.lock },
    })
end)

test("title bar: every dialog's close carries a tooltip and the skin's rest and hover colors", function()
    -- red under: a dialog close built past NS.MakeCloseButton (no owner: no tooltip, no skin colors).
    local NS, M, Skin = live()
    check(NS, M, Skin, {
        { name = "the outfit dialog's close", btn = NS.OutfitDialog.Frame().close, close = true },
        { name = "the trigger dialog's close", btn = NS.TriggerDialog.Frame().close, close = true },
        { name = "the rebuild dialog's close", btn = NS.RebuildDialog.Frame().close, close = true },
        { name = "the progress dialog's close", btn = NS.ProgressDialog.Frame().close, close = true },
    })
end)

test("title bar: the bar's lock keeps its body line, and the drag strip's tip takes gtip.title", function()
    -- The lock's second line names the switch it shares (General > Master controls); the strip says
    -- how to move the bar. red under: the strip's tooltip set in the tooltip's own color.
    local NS, M, Skin = live()
    local f, tip = NS.Bar.Frame(), M.GameTooltip
    probe(Skin)
    f.lock:__fire("OnEnter")
    assertEqual(tip.TextLeft1:GetText(), NS.L["Lock or unlock the outfit bar"])
    assertEqual(tip.TextLeft2:GetText(), NS.L["The same switch as Lock frame on General > Master controls."])
    f.lock:__fire("OnLeave")
    f.drag:__fire("OnEnter")
    assertTrue(tip:IsShown() and tip:GetOwner() == f.drag, "the drag strip shows no tooltip")
    local line = tip.TextLeft1
    assertEqual(line:GetText(), NS.L["Outfit bar"])
    assertEqual(rgb(line.__r, line.__g, line.__b), token(NS, "gtip.title"))
    f.drag:__fire("OnLeave")
    assertTrue(not tip:IsShown(), "the drag strip's tooltip stays up")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
end)

-- ── the strip: W.HeaderButtons (AD-86-OR, LibKa0s#86; standalone-windows, *Title-bar controls*) ──

-- The geometry cases run on the suites' own scenes, which record every point a frame is given
-- (`__pts`): the dock's (tests/dock_scene.lua) for the window, the bar's (tests/bar_scene.lua).
local function lastPoint(r) return r.__pts[#r.__pts] end

local function openedWindow()
    local NS, M = dofile(T.root .. "/tests/dock_scene.lua")(T)()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    return NS, M, M.OutfitterRebornWindow
end

local function shownBar()
    local B = dofile(T.root .. "/tests/bar_scene.lua")(T)
    local NS, M, Bar = B.scene()
    B.complete(NS, "A")
    B.settle(M)
    return NS, M, Bar.Frame()
end

local function strip(hb)
    assertTrue(type(hb) == "table", "no headerButtons answer recorded on the window")
    return table.concat(hb.order, ",")
end

test("title bar: the outfit window's marks are W.HeaderButtons', settings beside the close", function()
    -- red under: modules/Window.lua's hand-placed close and gear (no headerButtons, the gear at -28).
    local NS, M, win = openedWindow()
    local hb = win.headerButtons
    assertEqual(strip(hb), "settings,close")
    assertTrue(hb.close == win.close and hb.settings == win.settingsButton, "the window keeps its marks")
    assertNil(hb.optOut, "the window has a settings mark")
    local H = M.LibStub("LibKa0s-Widgets-1.0").HEADER
    -- One pitch: the close PAD in from the corner, settings a SIZE and a GAP further in.
    assertEqual(hb.offsets.close, -H.PAD)
    assertEqual(hb.offsets.settings, -(H.PAD + H.SIZE + H.GAP))
    local p = lastPoint(win.settingsButton)
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[2], win); assertEqual(p[4], -(H.PAD + H.SIZE + H.GAP))
    assertEqual(win.settingsButton.__tip, NS.L["Open settings"])
end)

test("title bar: the outfit window's settings mark opens the settings panel, never while stood down", function()
    local NS, M = live()
    local opened = {}
    NS.OpenOptionsPanel = function(page) opened[#opened + 1] = page or "root" end
    M.OutfitterRebornWindow.settingsButton:__fire("OnClick", "LeftButton")
    assertEqual(table.concat(opened, ","), "root")
    local real = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    M.OutfitterRebornWindow.settingsButton:__fire("OnClick", "LeftButton")
    NS.IsStoodDown = real
    assertEqual(#opened, 1, "the settings mark opened the panel while stood down")
end)

test("title bar: the outfit bar's marks read lock, settings, close on the band", function()
    -- red under: modules/Bar_Chrome.lua's hand-laid lock and close at a 22 px pitch, no settings mark.
    local _, M, f = shownBar()
    local hb = f.headerButtons
    assertEqual(strip(hb), "lock,settings,close")
    assertTrue(hb.close == f.close and hb.extras.lock == f.lock and hb.settings == f.settingsButton,
        "the bar keeps its marks")
    local H = M.LibStub("LibKa0s-Widgets-1.0").HEADER
    local pitch = H.SIZE + H.GAP
    assertEqual(hb.offsets.close, -H.PAD)
    assertEqual(hb.offsets.settings, -(H.PAD + pitch))
    assertEqual(hb.offsets.lock, -(H.PAD + 2 * pitch))
    -- The drag strip stops short of the innermost mark (the lock), 2 px clear of it.
    local dp
    for _, q in ipairs(f.drag.__pts) do
        if q[1] == "BOTTOMRIGHT" then dp = q end
    end
    assertTrue(dp ~= nil, "the drag strip has no BOTTOMRIGHT point")
    assertEqual(dp[4], -(H.PAD + 2 * pitch + H.SIZE + 2))
end)

test("title bar: the outfit bar's settings mark opens the bar's settings page", function()
    local NS = live()
    local opened = {}
    NS.OpenOptionsPanel = function(page) opened[#opened + 1] = page or "root" end
    NS.Bar.Frame().settingsButton:__fire("OnClick", "LeftButton")
    assertEqual(table.concat(opened, ","), "bar")
end)

test("title bar: every dialog is a companion: W.HeaderButtons' close alone, no settings mark, no waiver", function()
    -- standalone-windows v2.119.0, *A companion window carries no settings mark*: each dialog opens
    -- only from the outfit window, a row menu or the bar, and edits only that owner's outfit.
    -- red under: the waiver path (settings = false with a settingsOptOut reason, FB-OR-01).
    local NS, M = live()
    local H = M.LibStub("LibKa0s-Widgets-1.0").HEADER
    for _, d in ipairs({ NS.OutfitDialog, NS.TriggerDialog, NS.RebuildDialog, NS.ProgressDialog }) do
        local f = d.Frame()
        local hb = f.headerButtons
        assertEqual(strip(hb), "close")
        assertTrue(hb.close == f.close, "the dialog keeps its close")
        assertNil(hb.settings, "a companion dialog carries a settings mark")
        assertEqual(hb.companion, true, "the dialog is not recorded as a companion")
        assertNil(hb.optOut, "a companion needs no waiver reason")
        assertEqual(hb.offsets.close, -H.PAD)
    end
end)

test("title bar: without the library a companion strip is the close alone, and needs no reason", function()
    -- core/WidgetsSetup.lua's hostStrip mirrors WidgetsHeader minor 2's `companion`.
    -- red under: hostStrip raising on settings ~= false without a reason, or building the gear.
    local inst = T.load({ libFiles = {} })
    local NS, DM = inst.NS, inst.mocks
    local bar = DM.CreateFrame("Frame", nil, DM.UIParent)
    local hb = NS.HeaderButtons(bar, { frame = bar, companion = true, close = function() end })
    assertNil(hb.settings, "the degraded companion strip built a settings mark")
    assertEqual(hb.companion, true)
    assertNil(hb.optOut)
    -- the waiver stays: settings = false still needs its reason
    assertError(function() NS.HeaderButtons(bar, { frame = bar, settings = false }) end)
end)

test("title bar: the bar's lock mark carries its own tip, so every mark has a __tip", function()
    -- red under: the lock extra built with no `tip` (its title only from the hooked NS.ShowTitleTip).
    local NS, _, f = shownBar()
    assertEqual(f.lock.__tip, NS.L["Lock or unlock the outfit bar"])
end)

test("title bar: without the library the bar's degraded strip matches the library's order and offsets", function()
    -- core/WidgetsSetup.lua's hostStrip re-builds W.HeaderButtons by hand; pinned against the library
    -- strip so the two cannot drift (AD-86-OR review).
    local _, M, lf = shownBar()
    local want = lf.headerButtons
    local H = M.LibStub("LibKa0s-Widgets-1.0").HEADER
    local inst = T.load({ libFiles = {} })
    local NS, DM = inst.NS, inst.mocks
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(DM)
    NS.db.profile.bar.shown = true
    NS.Outfits.Create("A", dofile(T.root .. "/tests/bar_scene.lua")(T).naked())
    NS.Bar.Resume()
    DM.__fireTimers()
    local hb = NS.Bar.Frame().headerButtons
    -- Without the library NS.MakeCloseButton answers nil (core/CoreSetup.lua: the chrome degrades to
    -- nothing), so the strip holds no close; like W.HeaderButtons with no close, the rest pack from
    -- the corner in the same order and at the same pitch: each mark one slot outward of the library's.
    assertEqual(strip(hb), "lock,settings")
    assertEqual(NS.HEADER.PAD, H.PAD); assertEqual(NS.HEADER.SIZE, H.SIZE); assertEqual(NS.HEADER.GAP, H.GAP)
    assertEqual(hb.offsets.settings, want.offsets.close, "settings is not where the library puts the corner mark")
    assertEqual(hb.offsets.lock, want.offsets.settings, "the lock is not one pitch in from settings")
    assertEqual(hb.offsets.settings, -H.PAD)
    assertEqual(hb.offsets.lock, -(H.PAD + H.SIZE + H.GAP))
    assertNil(hb.close, "a degraded close appeared")
    assertNil(hb.optOut, "the degraded bar keeps its settings mark")
end)
