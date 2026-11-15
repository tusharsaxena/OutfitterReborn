# Analysis: WoW Forever seed re-validation, 2026-11-15 (build 1.60.1.70938)

Hand-written. The run's data is `candidates.json`, its rulings `RULINGS.md` (generated) and its
sources `SOURCES.md`. This is the first run of `tools/seeds/seeds.py` on WoW Forever (wago.tools
product `wowf`), so there is no previous bundle to diff against. Forever's lists were coded from the
port inventory's best evidence (ARCHITECTURE.md, Per-client features), with the open values marked
`PROBE Pn`; this run is their first check against Forever's own DB2.

## What was checked

92 shipped ids that Forever reads: 9 spells, 3 difficulty ids, 8 map ids, 8 skill-line uses, 40 item
ids and 24 icon file ids. The Retail-only lists (quest NPCs, Vashj'ir, Find Fish, the cooking pets,
the Retail-only zone and trigger rows) are never read on Forever, so they were not checked here.

## What changed

Nothing shipped changed: every candidate was rejected and every flag kept, so `apply` wrote nothing.

## Candidates: 27, all rejected

- **Spell ranks and forms, 6.** Prowl ranks 6783 and 9913 (`AURA_SPELL_STATE`) and Stealth ranks
  1785, 1786 and 1787 (`FORM_SPELL_STATE`) are on Forever's druid and rogue lines with the same auras
  as the shipped rank 1, so a druid or rogue past rank 1 does not set STEALTH through these tables
  today. Dire Bear Form 9634 (a hand candidate) is the bear a level-40 druid wears, its own form (8),
  so FORM_BEAR misses it. All six are rejected as **needs owner review**: ruling D10 (match a base
  spell, or per-rank lists per client) waits on probes P3 and P4, and `TriggerData.lua` says
  Forever's higher ranks wait for that data. The data D10 waits for is now in this bundle.
- **Maps, 2.** Forever's `Map` has two InstanceType 3 maps no row holds: 2997 Darkspear Islands and
  3005 Battle for Gilneas (Retail's Gilneas is 761). Ruling D3 lists only AV, WSG and AB for
  Forever, so a row is the owner's call. Both already set the generic Battleground outfit, which
  matches by instance type. Rejected as **needs owner review**.
- **Difficulty ids, 19.** Forever's `Difficulty` has several rows of each name: six Normal party
  rows (1, 184, 198, 201, 207, 215), five 20 Player raid rows (148, 185, 226, 242, 255) and two 40
  Player rows (9, 186). Which one a Forever instance answers is exactly what PROBE P17 and P18
  (smoke F2-3, F2-4) settle, so those ten are **needs owner review**. The three 10 Player rows (197,
  243, 256) are rejected on D7, which gives Forever no 10-player group; 214 (DNT - Internal only) is
  rejected as internal; 202 to 204 (Difficulty A, B, C), 213 (Infinite) and 231 are **needs owner
  review**, since DB2 alone does not say which instance uses them.

## Flags: 30, all kept

- **Zone map ids, 5**: 2197, 1681, 2107, 2177 and 2106 are Retail ids on rows both clients share
  (AV, AB, WSG). Forever's `Map` lacks them, so they never match there; the Zones.lua note already
  says Forever matches these rows by their Classic ids (30, 529, 489), all three present here.
- **Item ids, 25**: the Argent Tournament lances, Shadowstrike (17074), the Legion artifact phantoms,
  Brumdysla (136350) and the two TBC corrections. `Items.lua`'s tables are shared by both clients
  and compared with the legacy capture; an id Forever's `ItemSparse` lacks never reaches a Forever
  bag, so the row is inert there.

Every spell, skill line and icon Forever reads exists on this build with the expected name and kind,
Shadowmeld 20580 (probe P4), Lockpicking 633 and the three Classic battleground maps among them.

## Re-check next time

- The D10 ruling and probes P3, P4: once ruled, the rank candidates above become accepts or stay
  rejected by that ruling.
- Smoke F2-3 to F2-5: each reports the difficulty or map id an instance answered; the matching
  candidate here is then added to its group by hand, the rest rejected on the probe.
- Any new InstanceType 3 map (a Forever battleground) and any new Difficulty row.
- Whether the shared item and zone tables should split per client (clients-§5), which would turn the
  25 item keeps and 5 zone keeps into removals from Forever's half.
