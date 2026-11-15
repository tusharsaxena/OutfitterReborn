# Analysis: Retail seed re-validation, 2026-11-15 (build 12.1.5.70783)

Hand-written. The run's data is `candidates.json`, its rulings `RULINGS.md` (generated) and its
sources `SOURCES.md`. This is the first run of `tools/seeds/seeds.py` on Retail, so there is no
previous bundle to diff against: the baseline is the seed files' own notes, last confirmed
2026-11-03 against wago.tools (`Difficulty`, `Map`, `BattlePetSpecies`).

## What was checked

172 shipped ids that Retail reads, across the four seed files: 11 spells, 23 creatures, 15
difficulty ids, 44 map ids, 3 uiMaps, 8 skill-line uses, 2 battle-pet species, 40 item ids and 26
icon file ids (an id in two lists counts once per list). The 23 creatures (the Argent Tournament
mounts, Aviana's Guardians and the Ulduar vehicles) are **not checkable**: Retail's `Creature.db2`
has 23,167 rows and none of them; the server supplies those NPCs. They carry no flag and no ruling,
and `RULINGS.md` lists them.

## What changed

Nothing shipped changed. No candidate was accepted and no flag was ruled `remove`, so `apply` wrote
nothing. One bundle cannot date when any result below first became true.

## Candidates: 16, all rejected

- **Prowl 102547** (`AURA_SPELL_STATE`, same-name): a Druid-line Prowl with the stealth aura (16), the
  variant a druid casts in combat under Incarnation: Avatar of Ashamane. If the player's aura carries
  this id rather than 5215, DRUID_PROWL misses it. Rejected as **needs owner review**: the table both
  clients share has no shape for a Retail-only key (an `NS.PerClient` key with no Forever value is
  nil on Forever), and the in-game aura id is unconfirmed.
- **Difficulty ids, 15.** Six are ids the `TriggerData.lua` header already leaves out (O24): 24 and
  33 (Timewalking), 151, 205 (Follower), 220 (Story), 233; a seventh, 257, is a raid Timewalking row
  of the same class as 33. Rejected on that precedent. Eight more fit no group the design lists and
  the header does not name: 18, 19 and 232 (Event), 150 (Normal Scaling 1-5), 216 (Quest), 236 and
  241 (Lorewalking), 250 (World). Rejected as **needs owner review**: whether Lorewalking, Quest or
  World difficulties belong in a group is a design call, not a DB2 one.
- **No map candidates.** Every `Map` row of InstanceType 3 or 4 on this build is in `Z.rows` or
  `Z.ALL_BRAWL_MAP_IDS`, as the Zones.lua header says.
- **No uiMap candidates.** Vashj'ir's parent (203) has exactly the three shipped children.

## Flags: 7, all kept

- **783 Travel Form** (`FORM_SPELL_STATE`, wrong-kind): no shapeshift aura on the id itself, a dummy
  (aura 4) that applies the form through the spell it selects. `GetShapeshiftFormInfo` reports the
  button's id, so the row stands (legacy parity).
- **1784 Stealth** (wrong-kind): this build gives rogue Stealth aura 443 in place of the shapeshift
  aura 36. `modules/States.lua` reads Stealth as a form with no aura, through this id only. Kept as
  **needs owner review**: confirm in game that the form bar still reports 1784 while stealthed; if
  Stealth stopped being a form, ROGUE_STEALTH needs another source.
- **633 Lockpicking** (`SKILL_LINES`, gone): Retail's `SkillLine` has no row 633.
  `GetTradeSkillDisplayName(633)` then reads nothing and D4's `L["Requires Lockpicking"]` fallback
  carries the LOCKPICKING trigger. Kept as **needs owner review** for O22's client check.
- **Three phantom artifacts** (renamed): 134552, 128479 and 134553. `ItemSparse` names the artifact
  pair (The Dreadblades, Fangs of the Devourer, Warswords of the Valarjar) where the legacy comment
  names the half (Fortune, Akaari's Will, Helya's Wrath). Same item, still a weapon; kept, comments
  untouched (legacy parity).
- **27503** (`CORRECTIONS`, renamed): the build calls it Scroll of Strength V; the legacy comment
  says Scroll of Protection V, which is 27500. Kept as **needs owner review**: the correction fits
  either scroll, and whether the legacy meant 27500 is the owner's call.

## Re-check next time

- Whether Stealth (1784) gets its shapeshift aura back, or the owner's in-game check settles it.
- Whether `SkillLine` 633 returns, and O22's outcome.
- New Retail difficulty ids (the candidate list shows every ungrouped party or raid row) and new
  InstanceType 3 or 4 maps (a new battleground, arena or brawl is a new row, by hand).
- Prowl 102547 once the owner rules on Retail-only aura keys.
