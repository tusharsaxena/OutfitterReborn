# Sources: WoW Forever seed re-validation, 2026-11-15

Written by `tools/seeds/seeds.py derive`. Do not edit by hand.

- Product: wago.tools `wowf` (WoW Forever)
- Build: `1.60.1.70938` (created 2026-11-13 01:36:09)
- Run date: 2026-11-15
- Builds API: https://wago.tools/api/builds

`raw/` holds each table this run read as `.csv.gz`. The big tables are trimmed to the rows
the derivation reads (the TRIM note in `tools/seeds/seeds.py`, class `DB`); a replay admits
the same rows. The full download's size and sha256 are recorded here so the trim can be
checked against the source.

| Table | Why | URL | Full size | Full sha256 | Rows in raw/ |
| --- | --- | --- | --- | --- | --- |
| SpellName | spell names: existence, the comment check, the same-name candidates | https://wago.tools/db2/SpellName/csv?build=1.60.1.70938 | 851160 | bd8dc963dd691c69aff531464636e7b5a944efeedb773895e7b2c4a0fb7c38b4 | 63 |
| SpellEffect | Effect / EffectAura on DifficultyID 0: the aura, shapeshift and tracking kind checks | https://wago.tools/db2/SpellEffect/csv?build=1.60.1.70938 | 3925743 | f419db3f95ef93b2cf052d9c3996ec355df60846f1fa24c671822aacfa8f59a3 | 125 |
| SkillLineAbility | Spell -> SkillLine: a same-name candidate must be learnable on a player line | https://wago.tools/db2/SkillLineAbility/csv?build=1.60.1.70938 | 407525 | 6696abd03ef90ad250a12ac23778616c292c46f6a0082130fbe187c96ead0aa0 | 21 |
| SkillLine | DisplayName_lang of the profession lines; the line names that fence pet lines out | https://wago.tools/db2/SkillLine/csv?build=1.60.1.70938 | 14266 | f3867d43ab42d1f5278e6e5028d0151bc06e4ef8e5cbd790a20df6ee57aa654d | 154 |
| Difficulty | InstanceType of each difficulty id; the difficulty candidates | https://wago.tools/db2/Difficulty/csv?build=1.60.1.70938 | 1167 | ffc9b9a62579ae3330d062c2c0f412f14d3bd500fa522b358fdcd7ce40146b78 | 22 |
| Map | InstanceType 3 (battleground) / 4 (arena) of every zone row's map id; the instance candidates | https://wago.tools/db2/Map/csv?build=1.60.1.70938 | 12296 | a4fa6474f5bba3dc815f0e78943b3a907840b8f44bba605d4ff0680048994908 | 78 |
| Item | ClassID / InventoryType: the phantom and lance kind checks | https://wago.tools/db2/Item/csv?build=1.60.1.70938 | 1443725 | 32ee11866ddee06477a4830105b084f68e972644fd6b067d77c859168cbf9df3 | 16 |
| ItemSparse | Display_lang: item existence and the comment check | https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70938 | 5345571 | fdc65396e8a1103ea5f552ea59aaebc0e73ba572612a3412c50e636b54c90b41 | 15 |
| ManifestInterfaceData | FilePath of each icon file id | https://wago.tools/db2/ManifestInterfaceData/csv?build=1.60.1.70938 | 8780683 | 71b82f75741b87ad38c82bb73cba99b3e3bdeb6c0c00e09dde1298dafce31441 | 23 |
