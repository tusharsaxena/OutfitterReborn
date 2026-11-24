local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.OpenMenu / NS.CloseMenu / NS.CloseMenuFrom / NS.MakeTestStrip /
-- NS.MakeFooter / NS.HeaderButtons from LibKa0s-Widgets-1.0 (BP §6.13).
--
-- A seam, nothing else (library-stack-§7): one file leases the major, so the art the controls draw
-- is resolved once, here, and every control is handed this addon's skin owner. The library is
-- vendored and cannot know which folder it was copied into, so the chevrons, the tick and the info
-- mark arrive as resolved paths from the media seam (core/MediaSetup.lua); NS.Icon answering nil is
-- a real answer, and the library falls back to the Blizzard art.
--
-- The users, as they land in P4: the outfit context menu (modules/OutfitMenu.lua, through
-- NS.OpenMenu; it replaces LibDropdown and the MC2 menus, design §7.5), the dialogs' dropdowns
-- (NS.MakeDropdown, §7.6), the outfit bar's and the window's test strips (NS.MakeTestStrip, §7.7, H17)
-- the outfit window's footer (NS.MakeFooter) and the title-bar marks of every window this addon
-- draws, the outfit window, the outfit bar and the dialogs (NS.HeaderButtons, AD-86-OR). The seam exports no copy window: the diagnostics
-- report is copied from the debug console's own Copy button.
--
-- THE POPUP IS A PROCESS-WIDE SINGLETON parented to UIParent, so hiding a window does not reach it.
-- Every non-click close path of a window that opens a menu calls NS.CloseMenu(): the character
-- sheet's OnHide, the outfit window's OnHide and each dialog's OnHide (design §7.2, §7.3, §7.6).
-- A surface that shares the screen with another menu's owner closes only its OWN menu instead:
-- NS.OpenMenu remembers the anchor it opened from until that menu hides by any route (a row's click,
-- an outside press, NS.CloseMenu), and NS.CloseMenuFrom(owns) closes it only when `owns` claims that
-- anchor. The outfit bar does that from every path that hides it (modules/Bar.lua hideFrames), so a
-- menu the window opened stays up when the bar goes.
--
-- DEGRADED (the library absent): NS.MakeDropdown, NS.MakeTestStrip and NS.MakeFooter answer nil, and
-- the caller draws no control rather than a dead one (the window lays its footer's buttons on a bare
-- frame of FOOTER_HEIGHT instead); NS.HeaderButtons builds the same strip by hand (the close through
-- NS.MakeCloseButton, which then answers nil, so the marks beside it alone); NS.OpenMenu hands the same `fill` to the client's
-- MenuUtil; NS.CloseMenu is a no-op, because no Ka0s menu can be open.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

--- One flat-skin dropdown, or nil when the library is absent. Nil is a real answer: the caller
--- draws no control.
--- @param parent table the frame to parent it to
--- @param width number the collapsed button's width
--- @return table|nil
function NS.MakeDropdown(parent, width)
    if not W then return nil end
    return W.Dropdown(parent, width, {
        chevron = NS.Icon("chevron-down"),
        check   = NS.Icon("confirm"),
        owner   = addonName,
    })
end

-- ── the context menus ────────────────────────────────────────────────────────────────────────────
-- A `fill(root)` is written against MenuUtil's own description (CreateTitle, CreateButton, and on a
-- button SetEnabled and a nested CreateButton), recorded here, then handed whole to W.ContextMenu:
-- a button with a nested level becomes a `submenu` row, which the library (Widgets minor 23) opens
-- beside its row with the parent kept drawn. Without the library the same `fill` goes to the
-- client's MenuUtil, which cascades natively. The library hides every level before a row's click
-- runs, which retires the old 0.1/0.2 s auto-hide.
--
-- KEEP-OPEN OR ACT-AND-CLOSE (design 2026-11-05 G4). A CreateCheckbox (a toggle) and a CreateRadio
-- (one choice of several, ticked) keep every level open; anything else closes them, because a row
-- that opens a dialog, popup or window would sit under the FULLSCREEN_DIALOG menu. On the client's
-- menu that is the responder's answer: MenuResponse.Refresh from the keep-open rows, nil (close all)
-- from the rest.

--- A level of a description: the recorder a `fill` writes to, and each button's own nested level.
--- Beside MenuUtil's CreateTitle and CreateButton it records CreateDivider, CreateCheckbox and
--- CreateRadio (keep-open rows) and a row's SetTooltip, each under MenuUtil's own name and shape, so
--- the client's menu reads the same `fill` on the degraded arm.
local function newLevel()
    local level = { items = {} }
    function level:CreateTitle(text)
        self.items[#self.items + 1] = { label = text, title = true }
        return {}
    end
    function level:CreateDivider()
        self.items[#self.items + 1] = { divider = true }
        return {}
    end
    local function row(self, text, onClick)
        local sub = newLevel()
        sub.label, sub.onClick, sub.enabled = text, onClick, true
        function sub.SetEnabled(_, on) sub.enabled = on and true or false end
        -- MenuUtil's tooltip is `fn(tooltip, description)`; it is read into plain text at each paint.
        function sub.SetTooltip(_, fn) sub.tooltip = fn end
        self.items[#self.items + 1] = sub
        return sub
    end
    function level:CreateButton(text, onClick) return row(self, text, onClick) end
    --- A toggle row: `isSelected(data)` draws its tick, `setSelected(data)` flips it, and the menu stays.
    function level:CreateCheckbox(text, isSelected, setSelected, data)
        local sub = row(self, text, nil)
        sub.isSelected, sub.setSelected, sub.data = isSelected, setSelected, data
        return sub
    end
    --- A choice row: as a toggle, drawn as a radio with the menu's tick on the current choice.
    function level:CreateRadio(text, isSelected, setSelected, data)
        local sub = self:CreateCheckbox(text, isSelected, setSelected, data)
        sub.radio = true
        return sub
    end
    return level
end

-- A row's tooltip as plain text: the recorded MenuUtil-shaped function, handed a capture of the one
-- tooltip call it makes.
local function tooltipText(item)
    if type(item.tooltip) ~= "function" then return nil end
    local text
    local capture = {}
    function capture.SetText(_, t) text = t end
    function capture.AddLine(_, t) text = text and (text .. "\n" .. t) or t end
    item.tooltip(capture, item)
    return text
end

--- Write a recorded item's state onto its W.ContextMenu row: label, disabled state, tooltip, and a
--- toggle's or radio's tick predicate. The library reads these on every paint. Both kinds hand the
--- library `selected`, so it draws the tick in its column and the ticked label in the menu's selected
--- color (WidgetsDropdown minor 4): a toggle's tick drawn inline beside plain text was a mark alone,
--- which skinning-§4 rules out (*A selected entry reads apart*, FB2-OR-01).
local function paintRow(out, item)
    out.label = item.label
    if item.title then return end
    out.disabled = item.enabled == false or nil
    out.tooltip = tooltipText(item)
    if item.isSelected then out.selected = function() return item.isSelected(item.data) and true or false end end
end

--- After a keep-open pick: the fill written again (`level`, the fresh root) onto the open rows, so
--- every level the library repaints reads the new labels, ticks and disabled states (a parent's
--- "Automation: X", a key's holder). A level whose shape moved keeps what it had, its keep-open
--- rows repainted from their own items first (NS.OpenMenu's refresh).
local function relabel(rows, level)
    if #rows ~= #level.items then return end
    for i, out in ipairs(rows) do
        local item = level.items[i]
        if (item.divider == true) ~= (out.divider == true) or (item.title == true) ~= (out.title == true) then return end
        if not item.divider then paintRow(out, item) end
        if out.submenu and #item.items > 0 then relabel(out.submenu, item) end
    end
end

local buildRows

--- One W.ContextMenu row: a title, a divider, a submenu row carrying its level, a keep-open toggle or
--- radio, or a button with its click. `menu.refresh` rewrites the whole open tree after a keep-open pick.
local function menuRow(item, menu)
    if item.title then return { label = item.label, title = true } end
    if item.divider then return { divider = true } end
    local out = {}
    paintRow(out, item)
    if item.isSelected then
        out.keepOpen, out.radio = true, item.radio or nil
        menu.own[#menu.own + 1] = { out = out, item = item }
        out.onClick = function()
            item.setSelected(item.data)
            menu.refresh()
        end
    elseif #item.items > 0 then
        out.submenu = buildRows(item, menu)
    else
        out.onClick = item.onClick
    end
    return out
end

buildRows = function(level, menu)
    local rows = {}
    for i, item in ipairs(level.items) do rows[i] = menuRow(item, menu) end
    return rows
end

-- The value a keep-open row's responder answers on the client's menu: Refresh, guarded, since a
-- client without MenuResponse is one where nil (close all) is the only safe answer.
local function refreshResponse()
    local R = MenuResponse
    return R and R.Refresh or nil
end

--- The client's description, wrapped so a toggle or radio answers Refresh and keeps the menu open,
--- and every button answers nil and closes it, at any depth. Every other method passes through.
local function wrapDescription(desc)
    local w = setmetatable({}, { __index = function(_, k)
        return function(_, ...) return desc[k](desc, ...) end
    end })
    function w.CreateButton(_, text, onClick)
        local cb = onClick and function(...) onClick(...) end
        return wrapDescription(desc:CreateButton(text, cb))
    end
    local function keepOpen(method)
        return function(_, text, isSelected, setSelected, data)
            local function set(...)
                setSelected(...)
                return refreshResponse()
            end
            return wrapDescription(desc[method](desc, text, isSelected, set, data))
        end
    end
    w.CreateCheckbox, w.CreateRadio = keepOpen("CreateCheckbox"), keepOpen("CreateRadio")
    return w
end

-- THE OPENER: the anchor of the menu NS.OpenMenu has up, or nil. Cleared by the menu's own OnHide,
-- hooked once on the frame W.ContextMenu answers (the library's one popup), so a menu dismissed by an
-- outside press is forgotten before a dropdown drops the same popup; and by NS.CloseMenu.
local opener
local watched = setmetatable({}, { __mode = "k" })

local function remember(m, anchor)
    if m == nil then return end
    opener = anchor
    if type(m) ~= "table" or watched[m] or type(m.HookScript) ~= "function" then return end
    watched[m] = true
    m:HookScript("OnHide", function() opener = nil end)
end

--- A context menu at the cursor: `fill(root)` adds its rows as it would to a MenuUtil description.
--- `opts.below`: drop it under the anchor instead (a hover menu, the Outfits broker's).
--- @param anchor table the region the menu belongs to (a press on it is no outside press)
--- @param fill function
--- @param opts table|nil { below = bool }
--- @return boolean opened  false when neither the library nor the client's MenuUtil can draw one
--- @return table|nil menu  the library's menu frame (nil on the client's MenuUtil)
function NS.OpenMenu(anchor, fill, opts)
    if not W then
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
        MenuUtil.CreateContextMenu(anchor, function(_, root) fill(wrapDescription(root)) end)
        return true
    end
    local level = newLevel()
    fill(level)
    local menu = { own = {} }
    local rows = buildRows(level, menu)
    function menu.refresh()
        -- Every toggle and radio from its own item: a pick may move another's tick (wearing a
        -- Complete outfit takes the others off), as MenuUtil re-reads each checkbox.
        for _, o in ipairs(menu.own) do paintRow(o.out, o.item) end
        local fresh = newLevel()
        fill(fresh)
        relabel(rows, fresh)
    end
    local below = type(opts) == "table" and opts.below == true
    local m = W.ContextMenu(anchor, rows, { owner = addonName, cursor = not below })
    remember(m, anchor)
    return true, type(m) == "table" and m or nil
end

--- An icon as inline markup for a line of text, cropped by the library's icon rule (W.IconText):
--- the Outfits broker's menu rows. `size` 0 is the line's height. "" without the library or an icon.
--- @param icon number|string|nil
--- @param size number|nil
--- @return string
function NS.IconText(icon, size)
    if not (W and W.IconText) or icon == nil then return "" end
    return W.IconText(icon, size or 0)
end

--- Close the shared popup menu behind every dropdown and context menu in the process, if one is
--- open. Safe when none ever opened, and a no-op on a degraded install.
function NS.CloseMenu()
    opener = nil
    if W then W.CloseMenu() end
end

--- Close the menu NS.OpenMenu has up only when `owns(anchor)` claims the anchor it opened from: a
--- surface's own hide takes its own menu down and leaves another surface's alone. Nothing on a
--- degraded install, where the client's menu is not this seam's to close (NS.CloseMenu above).
--- @param owns function (anchor) -> boolean
--- @return boolean closed
function NS.CloseMenuFrom(owns)
    if opener == nil or not owns(opener) then return false end
    NS.CloseMenu()
    return true
end

-- ── the test-mode strip ──────────────────────────────────────────────────────────────────────────

--- The strip's height, for a surface laying its content out below it (the library publishes it).
NS.TEST_STRIP_HEIGHT = (W and W.TEST_STRIP and W.TEST_STRIP.HEIGHT) or 18

--- Test mode's own end, for the strip's right-click menu: modules/Preview.lua, reached at call time.
local function endTestMode()
    local P = NS.Preview
    if P and P.IsActive and P.IsActive() and P.Stop then P.Stop() end
end

--- The test-mode strip (the library's W.TestStrip, born hidden), or nil when the library is absent.
--- Its mark is the catalog's info icon and its right-click ends test mode. The caller shows it, and
--- places it through its docking (AD-88-OR; Widgets minor 27, preview-mode's *Where the strip sits*):
--- `{ dock = "title", titleBar = band }` in `opts` puts it directly under that title band, full width,
--- placed again by the library on every show, hide and resize of the band; the caller never anchors
--- it, and moves its body down by the strip's `strip:BodyOffset()` while it shows (the outfit bar,
--- which lays out from config before the strip is shown, reads `NS.TEST_STRIP_HEIGHT` instead).
--- @param parent table the frame to parent it to
--- @param label string the localized line it says
--- @param opts table|nil any further W.TestStrip option (`dock`, `titleBar`, `kind`, `panel`, `L`,
--- `onEnd`), which wins
--- @return table|nil
function NS.MakeTestStrip(parent, label, opts)
    if not W then return nil end
    local o = { text = label, icon = NS.Icon("info"), owner = addonName, onEnd = endTestMode }
    if type(opts) == "table" then
        for k, v in pairs(opts) do o[k] = v end
    end
    return W.TestStrip(parent, o)
end

-- ── the window footer ────────────────────────────────────────────────────────────────────────────

--- The footer's height (W.FOOTER.HEIGHT, skin-invariant: standalone-windows, *Window chrome
--- geometry*), read where the library publishes it; 24, its published value, with no library.
NS.FOOTER_HEIGHT = (W and W.FOOTER and W.FOOTER.HEIGHT) or 24

--- A window footer (the library's W.Footer, Widgets minor 27; standalone-windows' *The footer*,
--- AD-89-OR): no fill, a hairline in the skin's `divider` along its top, `FOOTER.HEIGHT` tall across
--- `parent`'s bottom edge, born shown, painted for this addon's skin owner. Nil when the library is
--- absent; the caller then lays the same controls on a bare frame of the same height.
--- @param parent table the window whose bottom edge it spans
--- @param opts table|nil W.Footer's opts; `owner` is always this addon
--- @return table|nil
function NS.MakeFooter(parent, opts)
    if not (W and type(W.Footer) == "function") then return nil end
    local o = {}
    if type(opts) == "table" then
        for k, v in pairs(opts) do o[k] = v end
    end
    o.owner = addonName
    return W.Footer(parent, o)
end

-- ── the title-bar marks ──────────────────────────────────────────────────────────────────────────

--- W.HEADER's figures (an 18 px slot, 12 px art, 6 in from the corner, 6 apart), read where the
--- library publishes them; its published values with no library, for the degraded strip below.
NS.HEADER = (W and W.HEADER) or { SIZE = 18, ART = 12, PAD = 6, GAP = 6 }

--- The degraded strip's settings click: as the library's (hide `hideOnSettings`, then the window's
--- own opener), else the settings panel.
local function hostSettings(spec)
    return function()
        local hide = spec.hideOnSettings
        if type(hide) == "table" and type(hide.Hide) == "function" then hide:Hide() end
        if type(spec.settings) == "function" then spec.settings() else NS.OpenOptionsPanel() end
    end
end

--- One degraded mark: an 18 px Button with its art centered at 12 px, a title-bar control
--- (NS.TitleControl, core/CoreSetup.lua: the colors and the tooltip).
local function hostMark(bar, icon, tip, onClick)
    local H = NS.HEADER
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(H.SIZE, H.SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetSize(H.ART, H.ART)
    b.icon:SetTexture(NS.Icon(icon))
    b.__tip = tip
    NS.TitleControl(b, tip)
    b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
    return b
end

--- The degraded strip's answer shell and its own marks (settings, close): the waiver check, the
--- companion (WidgetsHeader minor 2: no settings mark, no reason) and the opt-out.
local function hostAnswer(bar, spec)
    local companion = spec.companion == true
    local waived = not companion and spec.settings == false
    if waived and (type(spec.settingsOptOut) ~= "string" or spec.settingsOptOut == "") then
        error("NS.HeaderButtons: settings = false needs spec.settingsOptOut, the reason", 4)
    end
    local hb = { extras = {}, order = {}, companion = companion or nil, optOut = waived and spec.settingsOptOut or nil }
    if not companion and not waived then
        hb.settings = hostMark(bar, "settings", spec.settingsTip or "Open settings", hostSettings(spec))
    end
    if spec.close ~= false then
        local win = spec.frame or bar
        local onClose = type(spec.close) == "function" and spec.close or function() win:Hide() end
        hb.close = spec.makeClose(bar, onClose)
    end
    return hb
end

--- The marks outermost first: close, settings, then the extras from the last to the first.
local function hostList(bar, spec, hb)
    local list = {}
    if hb.close then list[1] = { key = "close", btn = hb.close } end
    if hb.settings then list[#list + 1] = { key = "settings", btn = hb.settings } end
    local extras = type(spec.extras) == "table" and spec.extras or {}
    for i = #extras, 1, -1 do
        local x = extras[i]
        local b = hostMark(bar, x.icon, x.tip, x.onClick)
        hb.extras[x.key] = b
        list[#list + 1] = { key = x.key, btn = b }
    end
    for i = #list, 1, -1 do hb.order[#hb.order + 1] = list[i].key end
    return list
end

--- The strip with no W.HeaderButtons: the same marks in the same order at the same offsets, and the
--- same answer, so a window reads one shape either way.
local function hostStrip(bar, spec)
    local H = NS.HEADER
    local hb = hostAnswer(bar, spec)
    local list = hostList(bar, spec, hb)
    hb.offsets, hb.right = {}, {}
    local off, point = H.PAD, spec.point or "RIGHT"
    for _, e in ipairs(list) do
        if spec.place ~= false then e.btn:SetPoint(point, bar, point, -off, spec.y or 0) end
        hb.offsets[e.key] = -off
        hb.right[#hb.right + 1] = { frame = e.btn, x = off }
        off = off + H.SIZE + H.GAP
    end
    local host = spec.frame or bar
    host.headerButtons = hb
    return hb
end

--- A window's title-bar marks (LibKa0s-Widgets-1.0's W.HeaderButtons, WidgetsHeader minor 2;
--- standalone-windows' *Title-bar controls*, AD-86-OR): right-aligned, left to right `spec.extras`,
--- settings, close, each an 18 px mark 6 px from the corner and 6 apart, in `icon.tint` at rest and
--- `text.link` under the pointer (the close `close.hot`), each with its tooltip. The owner is always
--- this addon, so the marks wear its skin and the default settings click reaches the opener the
--- launcher registered under its folder; the close is built through NS.MakeCloseButton (the one close
--- wrapper, read at call time). `spec` is W.HeaderButtons' own: `close` (the click, or false),
--- `companion` (true: a companion window, no settings mark and no reason, standalone-windows v2.119.0),
--- `settings` (nil, a function, or false with `settingsOptOut`), `settingsTip`, `extras`, `point`,
--- `y`, `place`, `frame`. Without the library the same strip is built by hand (hostStrip above).
--- @param bar table the frame the marks are made on and, unless `place = false`, anchored to
--- @param spec table
--- @return table hb { close, settings, extras, order, offsets, right, optOut, companion }, also `(spec.frame or bar).headerButtons`
function NS.HeaderButtons(bar, spec)
    local o = {}
    for k, v in pairs(spec) do o[k] = v end
    o.owner = addonName
    o.makeClose = function(parent, onClick) return NS.MakeCloseButton(parent, onClick) end
    if W and type(W.HeaderButtons) == "function" then return W.HeaderButtons(bar, o) end
    return hostStrip(bar, o)
end
