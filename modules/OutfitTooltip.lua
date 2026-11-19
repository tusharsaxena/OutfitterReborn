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
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get, NS.Inventory.Missing,
-- NS.Triggers.Get.

local OT = {}
NS.OutfitTooltip = OT

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

-- NORMAL_FONT_COLOR and HIGHLIGHT_FONT_COLOR, as the legacy tooltip drew the description in them.
local NORMAL = { 1, 0.82, 0 }
local HIGHLIGHT = { 1, 1, 1 }

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

-- "Missing: a, b" with the label in white and the items in `token`'s color.
local function itemList(label, token, items)
    local names = {}
    for i, item in ipairs(items) do names[i] = itemName(item) end
    local white = NS.SkinEscape("text.highlight") or ""
    return white .. label .. " " .. (NS.SkinEscape(token) or "") .. table.concat(names, ", ") .. "|r"
end

local function addList(tip, label, token, items)
    if #items == 0 then return end
    local r, g, b = NS.SkinColor(token)
    tip:AddLine(itemList(label, token, items), r, g, b, true)
end

local function full(tip, rec, desc, missing, banked, owner, group)
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearLines()
    tip:AddLine(tostring(rec.name))
    if desc then tip:AddLine(desc, HIGHLIGHT[1], HIGHLIGHT[2], HIGHLIGHT[3], true) end
    addList(tip, L["Missing:"], "of.outfit.missing", missing)
    addList(tip, L["Banked:"], "of.outfit.banked", banked)
    tip:Show()
    NS.PlaceBodyTip(tip, owner, group)
end

local function newbie(tip, rec, desc, owner, group)
    if Compat.GetCVar("UberTooltips") ~= "1" then return false end
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearLines()
    tip:AddLine(tostring(rec.name), HIGHLIGHT[1], HIGHLIGHT[2], HIGHLIGHT[3])
    tip:AddLine(desc, NORMAL[1], NORMAL[2], NORMAL[3], true)
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
