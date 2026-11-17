local addonName, NS = ...
-- core/CoreSetup.lua — NS.Print, the secret-safe stringifier, the SafeRegister* family, the window
-- chrome and NS.ResolveColor, from LibKa0s-Core-1.0; every tagged chat line leaves through here.

NS.Util = NS.Util or {}

-- The HOST owns the rejected-event list (events-frames-taint-§1): the library keeps no state, so the
-- addon surfaces this list in its diagnostics report.
NS.rejectedEvents = NS.rejectedEvents or {}

-- The one sentence every degradation stub opens with, so a library-absent load says the same thing
-- wherever it is noticed.
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s Outfitter Reborn "
    .. "(expected in libs/LibKa0s)"

-- ── a title-bar control (LibKa0s v1.105.0 smoke round 1, rulings 3 and 4; SR-OR) ──────────────
--
-- Every control on a title band this addon draws itself (the outfit window's gear, the outfit bar's
-- lock) wears the library's header-mark look: its art (`btn.icon`) through the skin facade's Mark,
-- `icon.tint` at rest and `text.link` under the pointer, recorded so a skin switch repaints it, as
-- LibKa0s-Widgets' HeaderButton paints its marks. The close X is Core's (NS.MakeCloseButton), which
-- carries `close.rest` (following `icon.tint`), `close.hot` and its "Close" tooltip itself. A
-- control's tooltip is the game tooltip owned by it, its first line in the owner's `gtip.title` and
-- an optional second line in `gtip.body`, placed by LibKa0s-Tooltip-1.0's PlaceAttached (above the
-- control, below only without room), else above it by a relative point. Resolved at call time:
-- the skin facade (core/SkinSetup.lua) and the Tooltip major load after this file, and without the
-- library the facade's Mark is a no-op and the tooltip is still placed above.

local TITLE_HOT = { token = "text.link" }

local function words(v, btn)
    if type(v) == "function" then v = v(btn) end
    return type(v) == "string" and v ~= "" and v or nil
end

--- Show `title` (and `body`, wrapped) as `owner`'s title-bar tooltip.
--- @param owner table the control or strip under the pointer
--- @param title string|function
--- @param body string|nil
function NS.ShowTitleTip(owner, title, body)
    local tip = GameTooltip
    title = words(title, owner)
    if not (title and tip and tip.SetOwner) then return end
    local color = NS.Skin and NS.Skin.Color or function() end
    tip:SetOwner(owner, "ANCHOR_NONE")
    local r, g, b = color("gtip.title")
    tip:SetText(title, r, g, b, 1, true)
    body = words(body, owner)
    if body then
        local br, bg, bb = color("gtip.body")
        tip:AddLine(body, br, bg, bb, true)
    end
    tip:Show()
    local Tip = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    if Tip and type(Tip.PlaceAttached) == "function" and Tip.PlaceAttached(tip, owner) then return end
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOM", owner, "TOP", 0, 2)
end

-- ── a body element's tooltip (AD-92-OR, LibKa0s#92; standalone-windows, *Tooltip placement*) ──
--
-- Every tooltip this addon places on a BODY element (an outfit window row, the EM mark in a row, an
-- outfit bar button) is owned at ANCHOR_NONE, filled, shown, and then placed here: beside the whole
-- window group by LibKa0s-Tooltip-1.0's PlaceBeside (right of the group, else left, top level with
-- the element, comparisons on the same side). Unreadable geometry falls back to PlaceAttached above
-- the element, then to a plain attach above it by a relative point; never the cursor. Resolved at
-- call time, as ShowTitleTip resolves the major.

--- Place the shown tooltip `tip`, owned by body element `el`, beside window group `group` (a frame,
--- a list of frames or a group table; anything else lets the library find the group from `el`).
--- @param tip table
--- @param el table
--- @param group table|function|nil
--- @return string|nil side the side the tooltip took ("right", "left", "above", "below")
function NS.PlaceBodyTip(tip, el, group)
    if not (tip and el) then return nil end
    local g = group
    if type(g) ~= "table" and type(g) ~= "function" then g = nil end
    local Tip = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    local side = Tip and type(Tip.PlaceBeside) == "function" and Tip.PlaceBeside(tip, el, g) or nil
    if side then return side end
    side = Tip and type(Tip.PlaceAttached) == "function" and Tip.PlaceAttached(tip, el) or nil
    if side then return side end
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOM", el, "TOP", 0, 2)
    return "above"
end

--- Hide the game tooltip when `owner` holds it.
--- @param owner table
function NS.HideTitleTip(owner)
    local tip = GameTooltip
    if not (tip and tip.Hide) then return end
    if type(tip.IsOwned) == "function" and not tip:IsOwned(owner) then return end
    if type(tip.GetOwner) == "function" and tip:GetOwner() ~= owner then return end
    tip:Hide()
end

local function paintTitleMark(btn, hot)
    local icon = rawget(btn, "icon")
    local S = NS.Skin
    if icon and S and type(S.Mark) == "function" then S.Mark(icon, hot and TITLE_HOT or nil) end
end

--- Make `btn` (a Button with its art in `btn.icon`) a title-bar control: the mark's rest and hover
--- colors and the tooltip, both hooked, so the control's own OnEnter / OnLeave keep running.
--- @param btn table
--- @param title string|function the tooltip's first line, read on each hover
--- @param body string|nil a second line
--- @return table btn
function NS.TitleControl(btn, title, body)
    paintTitleMark(btn, false)
    btn:HookScript("OnEnter", function(self)
        paintTitleMark(self, true)
        NS.ShowTitleTip(self, title, body)
    end)
    btn:HookScript("OnLeave", function(self)
        paintTitleMark(self, false)
        NS.HideTitleTip(self)
    end)
    return btn
end

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- Degrade, never error. A nil printer takes every settings file with it, and a silent one makes
    -- /or answer nothing, so keep a short fallback and say "missing" ONCE, on the first line printed.
    local function probeConcat(v) return table.concat({ v }) end
    function NS.IsConcatSafe(v) return (pcall(probeConcat, v)) end
    function NS.SafeToString(v)
        if v == nil or type(v) == "boolean" then return tostring(v) end
        if NS.IsConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    local announced = false
    local function fallbackPrint(...)
        local chat = DEFAULT_CHAT_FRAME
        if not chat then return end
        if not announced then
            announced = true
            chat:AddMessage(NS.PREFIX .. " " .. NS.LIBKA0S_MISSING .. "; running on reduced fallbacks.")
        end
        local parts = { NS.PREFIX }
        for i = 1, select("#", ...) do parts[i + 1] = NS.SafeToString((select(i, ...))) end
        chat:AddMessage(table.concat(parts, " "))
    end
    NS.Print = fallbackPrint
    NS.Util.print = fallbackPrint

    -- The chrome degrades to NOTHING rather than to a hand-copied backdrop (standalone-windows):
    -- SKIN is an empty table so a window may index it, and MakeCloseButton answers nil exactly as
    -- Core's own does where CreateFrame is unavailable.
    NS.SKIN            = {}
    NS.ApplySkin       = function() end
    NS.MakeCloseButton = function() return nil end
    -- No grip: the window keeps its stored size (Core's own answer where it cannot build one).
    NS.MakeResizable   = function() return nil end
    NS.RaiseStaticPopups = function() end
    -- A stored swatch as drawn (Core's ResolveColor): no class color without the library, so the
    -- swatch itself, keyed or positional, white where it holds nothing.
    NS.ResolveColor = function(stored)
        local c = type(stored) == "table" and stored or {}
        return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
    end

    -- The SafeRegister* family as ONE-RUNG pcall bodies (events-frames-taint-§1).
    local function reject(rejected, event)
        if type(rejected) ~= "table" then return end
        for i = 1, #rejected do if rejected[i] == event then return end end
        rejected[#rejected + 1] = event
    end
    NS.SafeRegisterEvent = function(target, event, handler, rejected)
        local ok = pcall(target.RegisterEvent, target, event, handler)
        if not ok then reject(rejected, event) end
        return ok
    end
    NS.SafeRegisterUnitEvent = function(frame, event, rejected, unit1, unit2)
        local ok = pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2)
        if not ok then reject(rejected, event) end
        return ok
    end
    NS.SafeRegisterEvents = function(target, events, handler, rejected)
        local n = 0
        for _, event in ipairs(events) do
            if NS.SafeRegisterEvent(target, event, handler, rejected) then n = n + 1 end
        end
        return n
    end
    return
end

NS.IsConcatSafe, NS.SafeToString = lib.IsConcatSafe, lib.SafeToString

-- Every event registration in the addon goes through these (events-frames-taint-§1).
NS.SafeRegisterEvent     = lib.SafeRegisterEvent
NS.SafeRegisterUnitEvent = lib.SafeRegisterUnitEvent
NS.SafeRegisterEvents    = lib.SafeRegisterEvents

-- The shared window edge, published flat so a re-skin lands everywhere at once (standalone-windows).
-- WRAPPED, TO SAY WHO IS ASKING (skinning-§1): with no skin table, Core paints the frame through the
-- skin owner core/SkinSetup.lua registers (Core minor 13: the owner's `S.Shell`), so the window wears
-- this addon's skin and follows a switch. A skin table of the caller's own is drawn as given.
NS.SKIN      = lib.SKIN
NS.ApplySkin = function(frame, skin)
    return lib.ApplySkin(frame, skin, addonName)
end
-- The bottom-right sizing grip (standalone-windows).
NS.MakeResizable = lib.MakeResizable
-- A toplevel DIALOG window re-raises a shown StaticPopup when it shows, so a confirmation shown first
-- is never buried under it (frame-layering-§4).
NS.RaiseStaticPopups = lib.RaiseStaticPopups or function() end
-- A stored swatch through its Use class color companion, four numbers out (options-ui-§17): the
-- outfit bar's background, borders and label color.
NS.ResolveColor = lib.ResolveColor

-- WRAPPED, TO SAY WHO IS ASKING -- a MUST (standalone-windows, anti-patterns #64/#65). Core draws the
-- catalog's `close` mark only when told which addon FOLDER to build the path from. Every close
-- control in this addon is built through here, so this grep returns this definition and calls to
-- NS.MakeCloseButton and nothing else:
--   grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/'
NS.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end

-- The prefix goes in as a FUNCTION so a later change to NS.PREFIX is not frozen in at load.
local printer = lib:New({ prefix = function() return NS.PREFIX end })

-- NS.Print and NS.Util.print MUST be the SAME function object: AceConsole's embed stamps its own
-- :Print over NS.Print, and core/OutfitterReborn.lua reclaims it from NS.Util.print (architecture-§2).
NS.Print = printer.Print
NS.Util.print = NS.Print
