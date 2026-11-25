local _, NS = ...
-- modules/OutfitTooltip.lua — NS.OutfitTooltip: an outfit's tooltip on GameTooltip, for the window's
-- rows and the bar's buttons (design §7.10, INV §3.8 "Outfit tooltip").
--
-- An outfit with missing or banked items gets the full tooltip: its name, its trigger's description,
-- then L["Missing:"] and the missing items in `of.outfit.missing`, and L["Banked:"] and the banked
-- items in `of.outfit.banked` (blue; the legacy banked line was drawn red). So does every outfit when
-- the caller asks for it with `always` (the bar's buttons: the legacy pShowEmptyTooltips,
-- OutfitterBar.lua:844). Otherwise an outfit with a description gets the newbie tip (name and
-- description), shown only while the UberTooltips CVar is on, as the legacy AddNewbieTip did; with
-- neither, nothing shows.
--
-- PLACEMENT (AD-92-OR, LibKa0s#92; standalone-windows, *Tooltip placement*). The tooltip is owned by
-- the hovered element at ANCHOR_NONE and, once shown, placed beside the window group the caller names
-- (the outfit window for a row, the whole bar for a bar button) by NS.PlaceBodyTip: right of the
-- group, else left, top level with the element. Never the cursor, never a corner anchor.
--
-- MISSING ITEMS ON WOW FOREVER (SF-OR-02, narrowed by ISF-OR-01). A missing item is one the player
-- does not carry. On WoW Forever each missing name is drawn in its quality color, and the level it
-- needs follows it while the player is below that level, from the client's answer (Compat.ItemInfo)
-- alone; nothing here reads ForeverDB. A field the client has not answered yet is left out: with
-- neither, the name is drawn in the line's color as it always was. Retail draws the plain list
-- (a file-scope per-client pick, clients-§5). Banked items are carried, so they stay plain.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get, NS.Inventory.Missing,
-- NS.Triggers.Get, NS.QualityColor.

local OT = {}
NS.OutfitTooltip = OT

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

-- The title and the description are lines this addon writes on GameTooltip, so they take the
-- skin's tooltip colors (skinning-§7, owner U-7, 2026-11-20): `gtip.title` and `gtip.body`, read at
-- each show so a skin switch reaches the next tooltip (SD-SK-OR.5; the legacy drew them in
-- HIGHLIGHT_FONT_COLOR and NORMAL_FONT_COLOR).
local function addTitle(tip, rec)
    local r, g, b = NS.SkinColor("gtip.title")
    tip:AddLine(tostring(rec.name), r, g, b)
end

local function addBody(tip, text)
    local r, g, b = NS.SkinColor("gtip.body")
    tip:AddLine(text, r, g, b, true)
end

-- The trigger's description, or nil.
local function description(rec)
    local tid = rec.trigger and rec.trigger.id
    if type(tid) ~= "string" or tid == "" then return nil end
    local desc = NS.Triggers.Get(tid)
    return desc and Secrets.PlainString(desc.desc) or nil
end

local function itemName(item)
    return Secrets.PlainString(item.name) or Secrets.PlainString(item.link) or ("item:" .. tostring(item.id))
end

local function escape(r, g, b)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- Whether missing items are described: WoW Forever only (Retail keeps the plain list it always drew).
local DESCRIBED = NS.PerClient({ retail = false, forever = true }) == true

-- A missing item's quality and required level, from the client's answer alone; nil for a field the
-- client has not loaded.
local function describe(item)
    local id = Secrets.PlainNumber(item.id)
    if not id then return nil, nil end
    local _, quality, _, minLevel = Compat.ItemInfo(id)
    return quality, minLevel
end

-- A missing name in its quality color (back to the line's color after it), with the level the
-- player still lacks. An unknown quality keeps the line's color; an unknown player level shows it.
local function describedName(item, playerLevel)
    local quality, minLevel = describe(item)
    local name = itemName(item)
    local r, g, b
    if quality ~= nil then r, g, b = NS.QualityColor(quality) end
    if r ~= nil then name = escape(r, g, b) .. name .. "|r" end
    if minLevel and minLevel > 1 and (playerLevel == nil or playerLevel < minLevel) then
        name = L["%s (level %d)"]:format(name, minLevel)
    end
    return name
end

-- "Missing: a, b" with the label in white and the items in `token`'s color; `described` draws each
-- one through describedName.
local function itemList(label, token, items, described)
    local names = {}
    local level = described and Compat.UnitLevel("player")
    for i, item in ipairs(items) do
        names[i] = described and describedName(item, level) or itemName(item)
    end
    local white = NS.SkinEscape("text.highlight") or ""
    return white .. label .. " " .. (NS.SkinEscape(token) or "") .. table.concat(names, ", ") .. "|r"
end

local function addList(tip, label, token, items, described)
    if #items == 0 then return end
    local r, g, b = NS.SkinColor(token)
    tip:AddLine(itemList(label, token, items, described), r, g, b, true)
end

local function full(tip, rec, desc, missing, banked, owner, group)
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearLines()
    addTitle(tip, rec)
    if desc then addBody(tip, desc) end
    addList(tip, L["Missing:"], "of.outfit.missing", missing, DESCRIBED)
    addList(tip, L["Banked:"], "of.outfit.banked", banked)
    tip:Show()
    NS.PlaceBodyTip(tip, owner, group)
end

local function newbie(tip, rec, desc, owner, group)
    if Compat.GetCVar("UberTooltips") ~= "1" then return false end
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearLines()
    addTitle(tip, rec)
    addBody(tip, desc)
    tip:Show()
    NS.PlaceBodyTip(tip, owner, group)
    return true
end

--- Show outfit `id`'s tooltip on GameTooltip, owned by `owner` and placed beside `group`. True when
--- it showed.
--- @param id string
--- @param owner table the hovered body element
--- @param group table|nil the window group (nil: the library finds it from `owner`)
--- @param always boolean|nil  draw the full tooltip even with nothing missing or banked (the bar)
--- @return boolean
function OT.Show(id, owner, group, always)
    local rec = NS.Outfits.Get(id)
    if not rec then return false end
    local desc = description(rec)
    local missing, banked = NS.Inventory.Missing(rec)
    missing, banked = missing or {}, banked or {}
    local tip = GameTooltip
    if always or #missing > 0 or #banked > 0 then
        full(tip, rec, desc, missing, banked, owner, group)
        return true
    end
    if desc then return newbie(tip, rec, desc, owner, group) end
    return false
end
