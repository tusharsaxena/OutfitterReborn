# 02 Candidates, LibKa0s v1.94.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.95.0 to v1.105.0 blocks; site counts from Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/inputs/research/R8-consumers-b.md` (OR row) and that run's `03_ADOPTION_PLAN.md`. This run is the copy half only: candidates are listed here as **owed in phase [3]**, not interviewed.

**Class A, delivered on the copy alone**
- The library's own tooltips go through the placers (LibKa0s#92 part B): the icon browser's cells and toolbar, library dropdown entries, the minimap tooltip's gap toward the screen's center.
- One strip of header marks on every library window (LibKa0s#86): a settings mark beside the close on the debug console, the copy window and the perf panel; the skin picker's gear moves into its header.
- Reports go to the console, Copy is plain text (LibKa0s#79), the console's status line is a 24 px Widgets footer (LibKa0s#90).
- Slider-box junk text reverted on Enter and focus loss (OptionsWidgets minor 46), skin contrast fixes (LibKa0s#82, #84), kit 57's registered-frame hold (LibKa0s#75).

**Class B, host change required (owed in phase [3])**
- **#92** `LibKa0s-Tooltip-1.0` placers: 10 `ANCHOR_*` sites (RIGHT 7, LEFT 1, TOP 1, NONE 1) in `modules/Bar_Buttons.lua`, `Bar_Chrome.lua`, `Dock.lua`, `OutfitTooltip.lua`, `Tooltips_Compare.lua`, `Window_Rows.lua`. Replaces host code.
- **#79** `D:Report` / `D:Serialize`: the `missing` and `iteminfo` (and possibly `zone`) report verbs move onto `D:Report`; the degraded DebugLog stub gains `Report` and `Serialize` at that time. Replaces host code.
- **#86** `W.HeaderButtons` on this addon's own windows: `modules/Bar_Chrome.lua:219` close, `modules/Window.lua:224` close and `:241` gear, `modules/UIDialogs.lua:150`. Replaces host code.
- **#88** docked test strip: the two undocked `NS.MakeTestStrip` sites (`modules/Bar_Chrome.lua:244`, `modules/Window.lua:132`). A known non-conformance (standard v2.110.0) until adopted.
- **#89** `W.Footer` 24 px: hand-built footers at `modules/Dialog_Outfit.lua:226`, `modules/Dialog_Trigger.lua:232`, `modules/Window.lua:60` (`selectedFooter`). A known non-conformance until adopted.
- **#87** `Sim.Sample(client)`: only where this addon's test or preview data names sample characters (to verify in phase [3]); additive.

**Class C, whole-module**: Charts, Glow, Sim, Toast, Role, Callout and WaypointArrow have no lookup here; none is proposed (#85 Callout does not apply: no Callout consumer). Tooltip is the module #92 adopts.

**Blockers (3g)**: none; the forced fixes are in 01_DELTA.md and the RV-OR commit.
