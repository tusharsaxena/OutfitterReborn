# Seed validation: Outfitter Reborn

The seed-validation contract `/dev-copilot:validate-seeds OutfitterReborn <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Outfitter Reborn's procedure: the tool, the files it writes, the
precedent a ruling follows and each client's nuances. The headings below are the interface the
command reads, so keep their names.

The tool is `tools/seeds/seeds.py` (Python 3.8+, standard library only; its docstring is the
reference). Each run ends in a frozen bundle under `docs/seed-research/<date>-<flavor>/`. The first
runs are `docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/`.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `defaults/TriggerData.lua`, `defaults/Zones.lua`, `defaults/Items.lua`, `defaults/Triggers.lua` (icon and skill-line ids) | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever) | the same four files: the rows and lists WoW Forever reads | `tools/seeds/seeds.py --flavor forever` |

The roster's Clients value for the addon is `Retail · Forever`, so both flavors run. Each reads its
own client's product (clients-§10); a flavor checks only the ids its client reads. A list or row
marked `clients = { "retail" }`, or picked per client through `NS.PerClient`, is checked on that
client alone: the quest NPCs, Vashj'ir, Find Fish, the cooking pets and the Retail-only zone and
trigger rows are Retail's; `FOREVER_DIFFICULTY_GROUPS` and Forever's Shadowmeld are Forever's.

What the tool reads, per id kind, and the table that answers it:

| Kind | Lists | Table (columns) | Flags | Candidates |
| --- | --- | --- | --- | --- |
| spell | `AURA_SPELL_STATE`, `FORM_SPELL_STATE`, `FIND_FISH.spell` | `SpellName`, `SpellEffect` (`Effect`, `EffectAura`, DifficultyID 0), `SkillLineAbility`, `SkillLine` | gone, renamed, wrong-kind (no aura; no shapeshift aura 36 on a form; no tracking aura 45 on Find Fish) | same-name: a spell with a shipped spell's name, the list's aura, on a player skill line (pet lines fenced out) |
| creature | `ARGENT_MOUNTS`, `VIGILANCE_NPCS`, `LEVIATHAN_NPCS` | `Creature` (`Name_lang`) | renamed only (see Notes) | same-name |
| difficulty | `DIFFICULTY_GROUPS` (per client) | `Difficulty` (`InstanceType`) | gone, wrong-kind (a dungeon group needs 1, a raid group 2, Delves 5) | every party or raid row (InstanceType 1, 2) no group lists |
| map | `Z.rows` map ids, `Z.ALL_BRAWL_MAP_IDS` | `Map` (`InstanceType`) | gone, wrong-kind (bg and brawl 3, arena 4) | every InstanceType 3 or 4 map no row or brawl list holds |
| uiMap | `VASHJIR_MAP_IDS` | `UiMap` (`ParentUiMapID`) | gone, renamed | a sibling under the shipped maps' shared parent |
| skill line | `SKILL_LINES`, the gathering rows' `skillLine` | `SkillLine` (`DisplayName_lang`) | gone, renamed | none: no table encodes which line a trigger wants |
| battle pet | `COOKING_PETS` | `BattlePetSpecies` (`CreatureID`), `Creature` | gone, renamed, wrong-kind (another creature than the header cites) | none |
| item | `ID.ALIASES`, `IGNORED_UNUSED`, `PHANTOM_IDS`, `CORRECTIONS` | `ItemSparse` (`Display_lang`), `Item` (`ClassID`) | gone, renamed, wrong-kind (a phantom or lance that is not a weapon or armor) | none: no table says which item a player keeps or which off-hand is a phantom |
| icon | `AURA_ICON_STATE`, `FIND_FISH.texture`, the trigger rows' `icon`, `C.ZONE_ICONS` | `ManifestInterfaceData` (`FilePath`) | gone, wrong-kind (outside `Interface/Icons`) | none |

## Rules

- **Only the tools write their files.** `tools/seeds/rulings_<flavor>.json` is written only by
  `seeds.py rule`; a bundle's `candidates.json`, `SOURCES.md`, `raw/` and `RULINGS.md` only by
  `derive` and `report`. The seed files are hand-kept: `seeds.py apply` writes into them only where
  a list has a mechanical place for an id (the vehicle NPC sets and Vashj'ir's uiMaps), and refuses,
  naming the list, everywhere else. A new zone row, a difficulty group, a per-client key and every
  removal from a shared or per-client list are hand edits, made after the ruling and followed by a
  re-derive.
- **Rulings are data.** A ruling is keyed `<list>:<id>` for a candidate (accept or reject) and
  `shipped:<kind>:<list>:<id>` for a flag (keep or remove), never by build. It holds until the thing
  it ruled on stops being proposed. Each reason is one line; a ruling the owner still has to make
  is a reject or a keep whose reason starts `needs owner review:`.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the owner's rulings D1 to D10 in
     [`superpowers/specs/2026-11-08-forever-port-design.md`](superpowers/specs/2026-11-08-forever-port-design.md):
     D3 (Forever's zones are the generic battleground, AV, WSG and AB), D7 (Forever's difficulty
     groups), D10 (spell ranks: a base spell or per-rank lists per client, open until probes P3
     and P4);
  3. the seed files' own header notes: the difficulty ids `TriggerData.lua` leaves out (O24), the
     Zones.lua wear order and `PROBE Pn` markers, the per-client notes;
  4. legacy parity: every row from the legacy addon at `7ea3dc3` (cited `Outfitter.lua:N` beside
     the table, compared by `tests/fixtures/legacy/`) stands unless the DB2 shows a clear reason, and
     even then the ruling is `needs owner review`, never a silent fix.
- **What "accept" means here.** Accept an id the DB2 clearly supports that the list's own rule
  admits on that client and that has a mechanical place in the file. Everything else is rejected,
  or kept, with its reason.
- **What to reject.** A rank or variant while D10 is open; an id on a client the owner's ruling
  gives no row or group (D3, D7); an internal or test row; anything a header note leaves out.
- **Evidence.** Each candidate's and flag's own rows, in the bundle's `raw/*.csv.gz`, and the
  smoke rows (`smoke-tests.md` sections 14 to 18) that settle the open probes. A probe still open
  is a `needs owner review`, never a guess.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/seeds.py status --flavor retail
```

Prints `retail: CURRENT <build> (<bundle>)`, or `retail: NEW <build> (last ruled <build>, <bundle>)`.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> --build <build>
```

Downloads twelve tables (about 140 MB on a new build, cached in `tools/seeds/.cache/`, git-ignored)
and writes `raw/*.csv.gz` (trimmed, about 100 KB), `SOURCES.md` and `candidates.json`. **If the seed
parse comes up thin** (a list below its floor in `PARSE_FLOOR`), it exits non-zero: fix the parser,
never the floor. Report the shipped-id count, the candidate and flag counts and the unruled count.
`--replay` re-derives offline from the bundle's `raw/`.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1; it must print `OK` after `rule`.

- **Candidates** (`accept` or `reject`): `same-name`, `instance`, `difficulty`, `sibling`, `hand`
  (`HAND_CANDIDATES` in the tool). A candidate that belongs in another list is rejected here; add it
  to `HAND_CANDIDATES` with its reason, re-derive, and rule the new key.
- **Flags** (`keep` or `remove`): `gone` (the build has no row), `renamed` (the comment names
  something else: fix the comment by hand if the thing is the same, otherwise owner review),
  `wrong-kind` (the row no longer fits the list).
- Retail nuances: the form-bar ids (`FORM_SPELL_STATE`) are the ids `GetShapeshiftFormInfo`
  reports, which on Retail can be a dummy that applies the form through another spell (783 Travel
  Form), so a `wrong-kind` there is a keep unless the form itself changed.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`: once an id is applied, a re-derive no longer proposes it, so
`RULINGS.md` is written while the run's candidates still include it. `apply` refuses while anything
is unruled, keeps each file's line endings and layout, and a second `apply` changes nothing.

### After

- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundles' shape: what changed, what
  was accepted and rejected and why, what the next run re-checks.
- If a shipped list changed, re-derive once (the applied ids drop out of the candidates), roll the
  "Last confirmed" note in the header of the file that changed (`defaults/Zones.lua`,
  `defaults/TriggerData.lua`), and add a smoke check per newly shipped id to
  [`smoke-tests.md`](smoke-tests.md), plus its *Pending sign-off* note. A run that ships nothing
  new adds none.
- Re-resolve every `file:line` citation the docs suite flags.

### Stage

`docs/seed-research/<date>-retail`, `tools/seeds/rulings_retail.json`, any seed file `apply` or a
hand edit changed, `docs/smoke-tests.md`, plus any citation edits. Commit message:
`Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/seeds/seeds.py status --flavor forever
```

Prints `forever: CURRENT <build> (<bundle>)` or `forever: NEW <build> (...)`, comparing the live
`wowf` build with the newest `*-forever` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> --build <build>
```

Nine tables (about 21 MB on a new build); the Retail-only lists are not read, so `Creature`,
`UiMap` and `BattlePetSpecies` are not fetched. The parse floor holds as for Retail.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-forever
```

Nuances:

- **Ranks wait for D10.** Forever keeps each vanilla rank as its own id (Prowl 5215, 6783, 9913;
  Stealth 1784 to 1787). Until D10 is ruled, a rank is a reject with `needs owner review`.
- **The open probes decide the ids.** P17 (which difficulty and map ids a Forever dungeon and
  battleground answer) and P18 (the 20- and 40-player raid ids) are smoke rows F2-3 to F2-5. The
  Forever build has several rows of each name; none is accepted before the probe reports.
- **Shared tables are inert where the client lacks the id.** `Items.lua`'s tables and the zone rows
  both clients share carry Retail ids Forever's tables lack; a `gone` there is a keep, since the id
  never reaches a Forever bag or instance.
- **No Forever combat logs or captures exist**; the build's data is the evidence, so say so where a
  ruling would otherwise lean on them.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

As for Retail. An accepted Forever id in a list both clients share is a hand edit through
`NS.PerClient` (clients-§5), never an `apply`.

### After

As for Retail, with the smoke checks in `smoke-tests.md` sections 14 to 18 (the WoW Forever rows).

### Stage

`docs/seed-research/<date>-forever`, `tools/seeds/rulings_forever.json`, any seed file a hand edit
changed, `docs/smoke-tests.md`, plus any citation edits. Commit message:
`Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. Without pytest,
`python3 -m unittest discover -s tools/seeds -p 'test_*.py'` runs the same cases.

## Notes

- **Creature.db2 is a subset.** The client carries the creatures it draws itself (companions,
  mounts, some NPCs: 23,167 rows on Retail 12.1.5.70783, ids up to 276,385); most NPCs, the quest
  vehicles among them, come from the server. A quest NPC the table lacks is listed in `RULINGS.md`
  under *Not checkable*, with no flag and no ruling; only a row the table has is name-checked.
- **The raw bundle is trimmed.** `SpellName`, `SpellEffect`, `SkillLineAbility`, `Creature`, `Item`,
  `ItemSparse`, `ManifestInterfaceData` and `BattlePetSpecies` keep only the rows the derivation
  reads (the TRIM note in the tool); the small tables are whole. `SOURCES.md` records each full
  download's size and sha256, and `--replay` from the trimmed `raw/` reproduces `candidates.json`
  byte for byte. A bundle is about 100 KB.
- **`tools/gen-zones.lua`** is the older, Lua-only zone diff (`tests/test_zones.lua` covers it). It
  is pinned too: `--build <build>` is required, `--fetch` downloads
  `https://wago.tools/db2/Map/csv?build=<build>` with the User-Agent `OutfitterReborn-seed-check`,
  and the report's first line names the build. It diffs the whole table as Retail reads it, so it
  takes a `wow` build only (12.1.5.70961 on 2026-11-25 diffed clean). `seeds.py` covers the same
  check per client, so a re-validation run uses `seeds.py`; `gen-zones.lua` is the quick check when
  a zone row is added by hand.
- **No ForeverDB evidence** (clients-§10, *A second evidence source for Forever*). ForeverDB answers
  server-side facts for the classic-era world; the only ids here the DB2 cannot check are the 23
  Retail quest NPCs (Argent Tournament and Ulduar, *Not checkable* above), which ForeverDB does not
  hold. The `forever` flavor reads its DB2 alone.
- **Whether a shared helper** should carry the build pin, the cache, the bundle and the rulings for
  every Ka0s addon is decided in LibKa0s#91.
