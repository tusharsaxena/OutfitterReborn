# Sources: Retail seed re-validation, 2026-11-15

Written by `tools/seeds/seeds.py derive`. Do not edit by hand.

- Product: wago.tools `wow` (Retail)
- Build: `12.1.5.70783` (created 2026-11-04 00:38:01)
- Run date: 2026-11-15
- Builds API: https://wago.tools/api/builds

`raw/` holds each table this run read as `.csv.gz`. The big tables are trimmed to the rows
the derivation reads (the TRIM note in `tools/seeds/seeds.py`, class `DB`); a replay admits
the same rows. The full download's size and sha256 are recorded here so the trim can be
checked against the source.

| Table | Why | URL | Full size | Full sha256 | Rows in raw/ |
| --- | --- | --- | --- | --- | --- |
| SpellName | spell names: existence, the comment check, the same-name candidates | https://wago.tools/db2/SpellName/csv?build=12.1.5.70783 | 11360399 | 1b8fcd3546d042f9897ddd2897ff53f7f60c72d5aba9ccf5cfb372134af6226a | 377 |
| SpellEffect | Effect / EffectAura on DifficultyID 0: the aura, shapeshift and tracking kind checks | https://wago.tools/db2/SpellEffect/csv?build=12.1.5.70783 | 57345581 | cd9c42bb86e807f6ce0b680162ec551d75c3a79d28b253e60c61a56267561d73 | 720 |
| SkillLineAbility | Spell -> SkillLine: a same-name candidate must be learnable on a player line | https://wago.tools/db2/SkillLineAbility/csv?build=12.1.5.70783 | 941378 | 0fa7ed0fdd2004c405e574115412c4bc11c9df2e9a9122059b63782af9f71b64 | 19 |
| SkillLine | DisplayName_lang of the profession lines; the line names that fence pet lines out | https://wago.tools/db2/SkillLine/csv?build=12.1.5.70783 | 28460 | fefa339fbbaec7de820efcc8650eab142fda67aebf47e3753dcb41aac54932ee | 397 |
| Difficulty | InstanceType of each difficulty id; the difficulty candidates | https://wago.tools/db2/Difficulty/csv?build=12.1.5.70783 | 2957 | 5b5909ea3319a9596ba4472256ef8901e24c67d2b10638259bfabc652268a23e | 60 |
| Map | InstanceType 3 (battleground) / 4 (arena) of every zone row's map id; the instance candidates | https://wago.tools/db2/Map/csv?build=12.1.5.70783 | 165366 | 9039064c63905730a8112cbb9b805de2f43520040fc9c04cf36d1c548434b524 | 1187 |
| Item | ClassID / InventoryType: the phantom and lance kind checks | https://wago.tools/db2/Item/csv?build=12.1.5.70783 | 9104906 | 9dc76656a83fa67f036b7748b29c534949f08ca7cdd9d861ee3317378a5ab7b3 | 40 |
| ItemSparse | Display_lang: item existence and the comment check | https://wago.tools/db2/ItemSparse/csv?build=12.1.5.70783 | 51699329 | 89910dad9e9a56a4446a0f8ad9c64f79c10267c26ee4f866bd7265db32e433a8 | 40 |
| ManifestInterfaceData | FilePath of each icon file id | https://wago.tools/db2/ManifestInterfaceData/csv?build=12.1.5.70783 | 9376595 | 9436292e89b49ac62401053ed6c464002065cc54faeaa815addad17acc989a59 | 25 |
| Creature | Name_lang of the quest NPCs and the cooking pets (Retail-only lists) | https://wago.tools/db2/Creature/csv?build=12.1.5.70783 | 1563559 | fbc828f3a355d9448aea86007801406cd5de00b8de1f7229476ce8996750d8bb | 3 |
| UiMap | Name_lang / ParentUiMapID of the Vashj'ir uiMaps (a Retail-only list) | https://wago.tools/db2/UiMap/csv?build=12.1.5.70783 | 99372 | c07589d908b00d7d079e9e88b8c50d80ae8bd36631a661615bd7e636e5bbb7b3 | 1967 |
| BattlePetSpecies | CreatureID of the cooking pets' species (a Retail-only list) | https://wago.tools/db2/BattlePetSpecies/csv?build=12.1.5.70783 | 510451 | c38ac4b6b85d31bbcb7ae56b696907a4d0ec807f1409b4d2cb0a5dc29b88a450 | 2 |
