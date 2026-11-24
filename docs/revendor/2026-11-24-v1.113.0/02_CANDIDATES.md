# 02 Candidates, LibKa0s v1.112.0 -> v1.113.0

Sources: LibKa0s CHANGELOG.md, the v1.113.0 block; `docs/api/Widgets/version-30.4.7.17.3.8.8.7.2.2-docs.md`; `docs/api/Sim/version-5.3.11.4-docs.md`.

**Class A, delivered on the copy alone**
- WidgetsDropdown 4: a dropdown's selected row (the outfit and trigger dialogs' pickers) and a ticked radio in the outfit menu paint the menu's selected color, Ka0s Default's gold under Azeroth.

**Class B, host change required**
- The outfit menu's and the Outfits broker's toggles (`CreateCheckbox`): a ticked toggle drew its tick inline beside plain text, which skinning-§4 (*A selected entry reads apart*, v2.120.0) rules out. adopt: FB2-OR-01 hands the toggle's predicate to the row's `selected`, so the library draws the tick in its column and the label in the selected color.
- `Sim` minor 5 (every start shows the step panel) and `Sim.SampleCrowd`: no sim here, and no named sample person in shipping code. Not adopted (nothing to move).

**Blockers (3g):** none.
