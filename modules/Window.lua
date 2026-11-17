local _, NS = ...
-- modules/Window.lua — NS.Window: the outfit window's chrome, the list body, the scroll bar and the
-- footer (W.Footer), and its render (design §7.1, §7.3, INV §7.1-§7.2).
--
-- `OutfitterRebornWindow` is built once, by modules/Dock.lua, which owns every Show and Hide of it,
-- its position and its layers. This file draws what is in it. No tabs: the old Options and About
-- panels are the settings pages and their landing page. Its own scale is Win.SCALE (1.25) over
-- UIParent's.
--
-- DIRTY, THEN DRAWN. Window.MarkDirty(wipeCache) replaces the old Update(true): the bus receivers
-- below mark the list dirty (and wipe the outfit status cache), and the dock's follow tick draws it
-- while the window is shown (Window.RenderIfDirty). Nothing renders while the window is hidden.
--
-- TEST MODE (smoke round 2 design G7). Win.SetTestMode, called by Dock.Refresh before every show and
-- so never in lockdown, shows the amber strip (NS.MakeTestStrip, the bar's own), pushes the list down
-- by its body offset (strip:BodyOffset(), read after the show) and grows the window to match, and disables New outfit (it would make a real outfit);
-- the Slots buttons stay hidden. The strip is docked by the library under `frame.titleBar`, the title
-- band's frame down to the divider (`dock = "title"`; AD-88-OR, preview-mode's *Where the strip
-- sits*): this file never anchors it. One marker per mode: the title says test mode only when the
-- library is degraded and there is no strip.
--
-- THE FOOTER (AD-89-OR, standalone-windows' *The footer*) is the library's W.Footer (NS.MakeFooter):
-- no fill, a hairline in the skin's divider, FOOTER_HEIGHT (24) tall along the window's bottom edge.
-- New outfit sits on its left and the Slots: [All] [None] trio on its right, each centered on it; the
-- list ends above it. With no library the same buttons sit on a bare frame of the same height.
--
-- CALLS (at call time; design §12): NS.Dock.Close, NS.WindowRows, NS.WindowListModel, NS.Stack.Selected,
-- NS.Outfits.SetAllSlotsEnabled, NS.OutfitDialog.OpenNew, NS.OpenOptionsPanel, NS.Preview.IsActive,
-- NS.MakeTestStrip, NS.MakeFooter, NS.HeaderButtons.

-- SCALE: the window's own scale, 1.25 (Forever smoke feedback 3, owner 2026-11-09: the window drawn
-- as at a 1.25 scale, on both clients). Its sizes stay in its own units; the dock converts the sheet's
-- corner by the scale ratio, so it still docks flush.
local Win = { collapsed = {}, offset = 0, dirty = true, entries = {}, WIDTH = 260, HEIGHT = 320, inset = 0,
              SCALE = 1.25 }
NS.Window = Win

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL

local frame, list, scroll, newButton
local chrome = {}          -- the title-strip and footer controls, re-leveled at W + CHROME
local footer = {}          -- the Slots: [All] [None] trio, shown while an outfit is selected
local statusCache = {}
local installed = false

-- Every message that can change a row: each marks the list dirty and wipes the status cache.
-- STACK_CHANGED is not among them: a stack change re-draws the worn marks, and an outfit's missing
-- or banked status is inventory-driven, so it marks the list dirty and keeps the cache (Win.Install).
-- PREVIEW_CHANGED swaps the whole list for the sample outfits and back (smoke round 2 design G7).
local DIRTY_ON = { "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_EDITED", "OUTFIT_RENAMED", "OUTFIT_WORN",
                   "OUTFIT_REMOVED", "INVENTORY_CHANGED", "SELECTION_CHANGED", "EM_SYNCED",
                   "TRIGGERS_REBOUND", "PREVIEW_CHANGED" }

local function wipe(t) for k in pairs(t) do t[k] = nil end end

--- Mark the list for a redraw; `wipeCache` drops the outfit status cache too.
--- @param wipeCache boolean|nil
function Win.MarkDirty(wipeCache)
    if wipeCache then wipe(statusCache) end
    Win.dirty = true
end

--- @return table|nil the window frame, once built
function Win.Frame() return frame end

local function selectedFooter()
    local on = NS.Stack.Selected() ~= nil and not NS.Preview.IsActive()
    for _, f in ipairs(footer) do f:SetShown(on) end
end

--- Draw the list now (a no-op while the window is hidden).
function Win.Render()
    if not (frame and frame:IsShown()) then return end
    Win.dirty = false
    local entries = NS.WindowListModel.Build(Win.collapsed, statusCache)
    Win.entries = entries
    local Rows = NS.WindowRows
    local maxOffset = math.max(0, #entries - Rows.COUNT)
    if Win.offset > maxOffset then Win.offset = maxOffset end
    scroll:SetMinMaxValues(0, maxOffset)
    scroll:SetValue(Win.offset)
    for i, row in ipairs(Rows.rows) do
        local n = Win.offset + i
        Rows.Bind(row, entries[n], n)
    end
    selectedFooter()
end

--- The dock's follow tick: draw if something marked the list.
function Win.RenderIfDirty()
    if Win.dirty then Win.Render() end
end

--- Scroll to `n` rows down (clamped at render).
--- @param n number
function Win.SetOffset(n)
    n = math.max(0, math.floor(NS.SafeNumber(n, 0)))
    if n == Win.offset and not Win.dirty then return end
    Win.offset = n
    Win.Render()
end

--- Collapse or expand a category for the session.
--- @param id string
function Win.ToggleCollapsed(id)
    Win.collapsed[id] = not Win.collapsed[id] or nil
    Win.MarkDirty(false)
    Win.Render()
end

--- Re-assert the window's stack over `base`, its own level (frame-layering-§3): chrome +CHROME, the
--- body and rows +CONTENT, the scroll bar +SCROLL. After every strata or level change, and after a
--- SetParent.
--- @param base number|nil
function Win.Relevel(base)
    if not frame then return end
    base = NS.SafeNumber(base, nil) or NS.SafeNumber(frame:GetFrameLevel(), 0)
    for _, c in ipairs(chrome) do c:SetFrameLevel(base + LEVEL.CHROME) end
    list:SetFrameLevel(base + LEVEL.CONTENT)
    NS.WindowRows.Relevel(base + LEVEL.CONTENT)
    scroll:SetFrameLevel(base + LEVEL.SCROLL)
end

-- ── test mode ─────────────────────────────────────────────────────────────────────────────────

-- The list's top under the title divider, the title band's height (its frame's bottom, where the
-- docked strip hangs, is 1 px under the divider), and the strip's gap below it.
local LIST_TOP, TITLE_BAND, STRIP_GAP = -30, 27, 2

-- The contents' shift for an inset: the list's own 8 px left padding is taken up by the band, so the
-- rows start flush with the strip's edge (Forever smoke feedback 2, R2-2) and the window widens by
-- the rest.
local LEFT_PAD = 8
local function shiftOf(px) return math.max(0, px - LEFT_PAD) end

-- The strip, built the first time test mode shows the window; false when the library is degraded.
-- Docked under the title band's frame, which carries the inset, so the strip follows it.
local function ensureStrip()
    if frame.strip == nil then
        local strip = NS.MakeTestStrip(frame, L["Test mode: sample outfits, nothing equipped"],
            { dock = "title", titleBar = frame.titleBar })
        frame.strip = strip or false
        if strip then
            chrome[#chrome + 1] = strip
            strip:SetFrameLevel(NS.SafeNumber(frame:GetFrameLevel(), 0) + LEVEL.CHROME)
        end
    end
    return frame.strip or nil
end

--- The window's size as this file set it, in its own units: the width and the height with the test
--- strip's push. Read where the client's rect may not be laid yet (the dock's alone spot).
--- @return number width, number height
function Win.Size() return Win.WIDTH + shiftOf(Win.inset), Win.HEIGHT + (Win.push or 0) end

--- Widen the window by `px` on its left and move its contents right by as much (Forever smoke
--- feedback S5): a side-tab strip that hangs over the docked window's left edge then lies over an
--- empty band of the window's own background, and the window is extended, never moved. The dock
--- passes the strip's reach (NS.Sheet.StripInset) on every placing and 0 standing alone. Out of
--- lockdown only (the list holds secure children); a no-op when the inset is unchanged.
--- @param px number
function Win.SetLeftInset(px)
    if not frame then return end
    px = math.floor(math.max(0, NS.SafeNumber(px, 0)) + 0.5)
    if px == Win.inset then return end
    Win.inset = px
    local shift = shiftOf(px)
    frame:SetWidth(Win.WIDTH + shift)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + shift, -8)
    frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + shift, -26)
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + shift, 0)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_PAD + shift, LIST_TOP - (Win.push or 0))
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shift, 0)
end

--- Dress the window for test mode or take it off: the strip, the list's push, the height, New outfit
--- and the degraded title. Dock.Refresh only (the list holds secure children: never in lockdown).
--- @param on boolean
function Win.SetTestMode(on)
    if not frame then return end
    on = on == true
    if on == Win.testMode then return end
    Win.testMode = on
    local strip = on and ensureStrip()
    if strip then strip:Show() elseif frame.strip then frame.strip:Hide() end
    -- The push is the strip's own body offset (its height while it shows, read after Show), so a
    -- strip that ever outgrows NS.TEST_STRIP_HEIGHT still clears the list; plus the gap below it.
    -- NS.TEST_STRIP_HEIGHT stands in when a shown strip answers no height (its rect not laid yet).
    local offset = strip and type(strip.BodyOffset) == "function" and NS.SafeNumber(strip:BodyOffset(), 0) or 0
    if strip and offset <= 0 then offset = NS.TEST_STRIP_HEIGHT end
    local push = strip and (offset + STRIP_GAP) or 0
    Win.push = push
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_PAD + shiftOf(Win.inset), LIST_TOP - push)
    frame:SetHeight(Win.HEIGHT + push)
    frame.title:SetText((on and not strip) and L["Outfitter Reborn (test mode)"] or L["Outfitter Reborn"])
    newButton:SetEnabled(not on)
    selectedFooter()
    Win.MarkDirty(true)
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────

local function labeledButton(name, parent, w, h, text, opts)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(w, h)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(text)
    NS.Skin.Button(b, opts)
    chrome[#chrome + 1] = b
    return b
end

local function titleStrip(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(L["Outfitter Reborn"])
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -26)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -26)
    -- The title band as a frame, the test strip's dock (it draws nothing and takes no mouse): the
    -- window's top, 1 px in as the divider is, TITLE_BAND high. Win.SetLeftInset moves its left edge.
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, 0)
    bar:SetHeight(TITLE_BAND)
    bar:EnableMouse(false)
    f.titleBar = bar
    NS.ApplySkin(f)
    -- The marks (AD-86-OR, LibKa0s#86; standalone-windows' *Title-bar controls*): W.HeaderButtons'
    -- strip through NS.HeaderButtons, left to right settings, close, the close 6 px in from the top
    -- right and the gear 6 px past it, both at y -5 on the title band, each an 18 px mark with 12 px
    -- art in icon.tint, lit text.link under the pointer (the close close.hot), each with its tooltip
    -- above it ("Open settings", "Close"). The close's click closes through the dock; the gear opens
    -- the settings panel, refused while the addon stands down. The window sits beside the character
    -- sheet, not over the panel, so it stays shown (no hideOnSettings).
    local hb = NS.HeaderButtons(f, {
        frame = f, point = "TOPRIGHT", y = -5,
        close = function() NS.Dock.Close() end,
        settings = function() if not NS.IsStoodDown() then NS.OpenOptionsPanel() end end,
        settingsTip = L["Open settings"],
    })
    f.close, f.settingsButton = hb.close, hb.settings
    if hb.close then chrome[#chrome + 1] = hb.close end
    if hb.settings then chrome[#chrome + 1] = hb.settings end
end

local function body(f)
    local Rows = NS.WindowRows
    list = CreateFrame("Frame", "OutfitterRebornWindowList", f)
    list:SetSize(Rows.ROW_W, Rows.COUNT * Rows.ROW_H)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, LIST_TOP)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Win.SetOffset(Win.offset - NS.SafeNumber(delta, 0)) end)
    Rows.Build(list)
    scroll = CreateFrame("Slider", "OutfitterRebornWindowScroll", f)
    scroll:SetOrientation("VERTICAL")
    scroll:SetSize(12, Rows.COUNT * Rows.ROW_H)
    scroll:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
    scroll:SetValueStep(1)
    scroll:SetObeyStepOnDrag(true)
    scroll:SetMinMaxValues(0, 0)
    local track, thumb = scroll:CreateTexture(nil, "BACKGROUND"), scroll:CreateTexture(nil, "OVERLAY")
    track:SetAllPoints(scroll)
    thumb:SetSize(12, 24)
    scroll:SetThumbTexture(thumb)
    NS.Skin.ScrollBar(scroll, { track = track, thumb = thumb })
    scroll:SetScript("OnValueChanged", function(_, value) Win.SetOffset(value) end)
end

-- The footer with no library: a bare frame of the same height on the same edge (no hairline).
local function bareFooter(f)
    local foot = CreateFrame("Frame", nil, f)
    foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(NS.FOOTER_HEIGHT)
    return foot
end

local function footerRow(f)
    -- The library's footer (AD-89-OR), re-leveled with the chrome; its two text lines stay empty.
    local foot = NS.MakeFooter(f) or bareFooter(f)
    f.footer = foot
    chrome[#chrome + 1] = foot
    -- One look for the footer's three buttons (Forever smoke feedback 2, R2-4): the skin's plain button,
    -- not the primary one, whose fill made the label hard to read under several skins; All and None
    -- draw their label in the muted text color, a step dimmer. Each is centered on the footer.
    local new = labeledButton("OutfitterRebornNewOutfitButton", foot, 120, 20, L["New outfit"])
    new:SetPoint("LEFT", foot, "LEFT", LEFT_PAD, 0)
    new.mark = new:CreateTexture(nil, "ARTWORK")
    new.mark:SetSize(12, 12)
    new.mark:SetPoint("LEFT", new, "LEFT", 4, 0)
    new.mark:SetTexture(NS.Icon("add"))
    NS.Skin.Mark(new.mark)
    new:SetScript("OnClick", function()
        if not NS.IsStoodDown() and not NS.Preview.IsActive() then NS.OutfitDialog.OpenNew() end
    end)
    newButton = new
    local dim = { tokens = { text = "text.muted" } }
    local none = labeledButton("OutfitterRebornSlotsNone", foot, 40, 18, L["None"], dim)
    none:SetPoint("RIGHT", foot, "RIGHT", -8, 0)
    local all = labeledButton("OutfitterRebornSlotsAll", foot, 40, 18, L["All"], dim)
    all:SetPoint("RIGHT", none, "LEFT", -4, 0)
    local label = foot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT", all, "LEFT", -4, 0)
    label:SetText(L["Slots:"])
    NS.Skin.Text(label, "muted")
    local function setAll(on)
        local sel = NS.Stack.Selected()
        if NS.IsStoodDown() or not sel then return end
        NS.Outfits.SetAllSlotsEnabled(sel, on)
    end
    all:SetScript("OnClick", function() setAll(true) end)
    none:SetScript("OnClick", function() setAll(false) end)
    footer[1], footer[2], footer[3] = label, all, none
    for _, x in ipairs(footer) do x:Hide() end
end

--- Build the window, once. Hidden until the dock shows it; out of combat only (Dock.Refresh).
--- @return table the frame
function Win.Build()
    if frame then return frame end
    local f = CreateFrame("Frame", "OutfitterRebornWindow", UIParent, "BackdropTemplate")
    f:SetScale(Win.SCALE)
    f:SetSize(Win.WIDTH, Win.HEIGHT)
    f:Hide()
    titleStrip(f)
    body(f)
    footerRow(f)
    frame = f
    return f
end

--- The bus receivers, once per session; the bus record drops and replays them across a stand-down.
--- And the skin's looks-changed listener: an item row's name wears its quality color, NS.QualityColor
--- (the skin's q.* tokens), written at render rather than by a recorded primitive, so a skin switch
--- marks the list for the follow tick's redraw (core/SkinSetup.lua: a surface that draws at render
--- subscribes to NS.Skin.OnLooksChanged).
function Win.Install()
    if installed then return end
    installed = true
    NS.Skin.OnLooksChanged(function() Win.MarkDirty(false) end)
    local bus = NS.NewBusTarget()
    if not bus then return end
    for _, key in ipairs(DIRTY_ON) do
        bus:RegisterMessage(NS.MSG[key], function() Win.MarkDirty(true) end)
    end
    bus:RegisterMessage(NS.MSG.STACK_CHANGED, function() Win.MarkDirty(false) end)
    -- auto.enabled dims the trigger marks; an Outfit Window row (smoke round 3 E11) changes the
    -- sections or the marks the list draws.
    bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
        if path == "auto.enabled" or (type(path) == "string" and path:find("^window%.")) then
            Win.MarkDirty(false)
        end
    end)
    -- A profile switch writes no row, so the new profile's auto.enabled and window.* reach the list here.
    bus:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() Win.MarkDirty(false) end)
end
