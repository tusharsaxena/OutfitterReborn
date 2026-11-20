Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b76, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, item SD-RV-OR (the copy, the forced fixes and this bundle; that run lists its adoption items, so no interview here).

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-19-v1.107.0` states base v1.106.0; the provenance line before its re-vendor commit (d48b667) named v1.106.0. ok.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md`: `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).` before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 7295c27 (the re-cut v1.107.0); its CLAUDE.md names v1.107.0. They agree.
- `diff -rq --strip-trailing-cr` of both payloads against a v1.107.0 extract printed only `Only in <extract>/LibKa0s/media/sounds: callout` (the pruned voices; icons are `all`): payload-matches.
- Library range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` is 15 commits (SD-LK-94, SD-LK-99, SD-LK-100, SD-LK-97 Batches A to D, SD-LK-GUARD, SD-LK-REL and the v1.107.0 merge); issues named in it: LibKa0s#94, #97, #99, #100.

## 3b/3c Per-file minors that moved (old = this addon at v1.107.0, new = v1.108.0)
The loop over the tag's `LibKa0s.xml` (Step 3c), rows that differ only:
```
Core.lua  old: 18  new: 19
Callout.lua  old: 4  new: 5
CalloutSettings.lua  old: 5  new: 6
WaypointArrow.lua  old: 2  new: 3
WaypointArrowSettings.lua  old: 2  new: 3
Charts.lua  old: 2  new: 3
ChartsRender.lua  old: 1  new: 2
SkinPaint.lua  old: 19  new: 20
SkinPaintHud.lua  old: 1  new: 2
SkinPaintControls.lua  old: 18  new: 19
Widgets.lua  old: 29  new: 30
WidgetsDropdown.lua  old: 2  new: 3
WidgetsDragHandle.lua  old: 15  new: 16
WidgetsDragHandleTip.lua  old: 2  new: 3
WidgetsLineChart.lua  old: 7  new: 8
WidgetsBar.lua  old: 1  new: 2
OptionsCompose.lua  old: 19  new: 20
```
No file is behind (no cross-major skew), none is new and none is removed.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr` of `libs/LibKa0s` and `tests/_kit` against the extract printed nothing. After the prune the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), the same as v1.107.0.

## 3e Consumption
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Bus, Compat, Core, Tooltip, DebugLog, Env, Item, Launcher, Lifecycle, Slash, Media, Perf, Pool, Skin, Widgets, IconBrowser, Options, Schema. Of the moved files this addon reaches: Core (`lib.ApplySkin`, core/CoreSetup.lua:249, no `skinBands`), Skin (`S.ApplyBarFill` at modules/Dialog_Progress.lua:42), Widgets (`W.Footer`, `W.ContextMenu`, `W.TestStrip`, `W.HeaderButtons`) and Options (OptionsCompose: `H.BorderGroup` x2, `H.FontGroup`, `H.ColorPair` in settings/OutfitBar.lua). Callout, WaypointArrow, Charts, WidgetsBar, WidgetsLineChart and `W.DragHandle` are not used.

## 3f Kit
`Kit.VERSION` 57 -> 58 (`tests/_kit/framework.lua:20`). Both payloads move together in one commit.

## 3g Contract delta
- **OptionsCompose minor 20 (Batch A, R-2).** A composer with no opt-out now emits a `<color key>FromSkin` companion for every swatch. The two BorderGroups and the FontGroup already declare their companions in `extra` (`borderColorFromSkin`, `fontColorFromSkin`, `fontShadowFromSkin`), so the composer emits none. The ColorPair (`bar.bgColor`) emitted a new `bar.bgColorFromSkin` with no AceDB default and no reader: the schema's load-time check and `test_schema` went red (`bar.bgColorFromSkin resolves in no defaults tree`). **Blocker, fixed in this commit:** the ColorPair passes `keys = { bgColorFromSkin = "bgFromSkin" }` (settings/OutfitBar.lua:236-240), so its companion is the addon's own *Use the skin's background*, already in `extra`, and the composer adds no row.
- **SkinPaintControls minor 19 (97.17).** `S.ApplyBarFill` gives a StatusBar with no texture the skin's `bar.texture`, recorded. That closes the audit's progress-fill row with no host change (the background stays SD-SK-OR.1).
- **Kit revision 58 (SD-LK-GUARD).** `test_skin_values` reads new literal shapes and reported 13 hits. Fixed in this commit by host rows: four Dock.lua tab-art coordinate tables and the HSV triple in Triggers_Families.lua (`category = "not a color"`), the two Sheet.lua host-look fallbacks (cause DEV-SKIN-SHEET-BUTTON), and five rows citing SD-SK-OR for the literals that item moves to the skin (Constants.lua:76, OutfitTooltip.lua:28-29, Tooltips.lua:38, IconBrowserSetup.lua:64); each of those goes with its fix. `test_skin_switch` passed under the family checks unchanged.
- `grep -rn '__Attach[A-Za-z]*'` outside the payloads: no site.

## 3h Span
Every vendored tag has a bundle; nothing to write.

## 3i Icons
`LibKa0s icons: all (icon browser).` kept. Prune: icons kept whole, sounds removed 362 (unchanged).

## 3j Tests over the icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua'` outside `_kit`: `tests/test_credits.lua:153`, `tests/test_packaging.lua:153,229-231` and `tests/test_skeleton.lua:105` read files that ship under `all`. No blocker.
