local _, NS = ...
-- core/ForeverDBSetup.lua — NS.ForeverDB, the LibKa0s-ForeverDB-1.0 lease: what the ForeverDB data
-- addon knows about an item the client has not cached yet (LibKa0s#105, SF-OR-02).
--
-- ForeverDB is a WoW Forever data addon, LoadOnDemand and about 12 MB, and OPTIONAL for every player:
-- the TOC names it in `## OptionalDeps` only, never `## Dependencies` (clients-§11). The lease is the
-- two members this addon reads, `Available` and `Item`; the rest of the major (NPC, Quest,
-- ItemSources, VendorPrice, Spots, TrainerSpells, Meta, Status) is not leased, because nothing here
-- calls it. The library's diagnostics report prints ForeverDB's own line without this file.
--
-- WHEN IT LOADS. Never at login and never from this file: the library's `Available()` is the one
-- place `C_AddOns.LoadAddOn("ForeverDB")` runs, and its first caller is the outfit tooltip's missing
-- list (modules/OutfitTooltip.lua), when the player hovers an outfit with missing items. Retail
-- answers `false, "client"` there and loads nothing (the library's gate, through Compat).
--
-- DEGRADED (the library absent): the library's documented all-absent values, `false, "missing"` and
-- nil, so the tooltip draws as it did before ForeverDB existed. tests/test_surface_parity.lua pins
-- both arms.

local F = LibStub and LibStub("LibKa0s-ForeverDB-1.0", true)

NS.ForeverDB = {}

--- Whether ForeverDB can answer now: `ok, reason`. The first call on WoW Forever is what loads it.
--- @return boolean ok
--- @return string|nil reason  "client", "missing", "reshaped" or the client's load failure
function NS.ForeverDB.Available()
    if not F then return false, "missing" end
    return F.Available()
end

--- ForeverDB's item row as a new table ({ id, name, quality, requiredLevel, ... }), or nil.
--- @param id number
--- @return table|nil
function NS.ForeverDB.Item(id)
    if not F then return nil end
    return F.Item(id)
end
