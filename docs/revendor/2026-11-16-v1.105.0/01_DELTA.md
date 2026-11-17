Delta: LibKa0s v1.94.0 -> v1.105.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-OR (phase [2], the copy and bundle half only).

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-07-v1.93.0` states base v1.92.0; the provenance line before its re-vendor commit `0e45a48` named v1.92.0. ok.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md`: `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.94.0 (MIT).` before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 3b82737 (OR-F1); its CLAUDE.md names v1.94.0. They agree.
- `diff -rq --strip-trailing-cr` of both payloads against a v1.94.0 extract printed nothing (payload-matches; icons are `all`, so no icon lines either).
- Library range: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0` is 114 commits over tags v1.95.0 to v1.105.0; issues named in it: #75 #78 #79 #80 #81 #82 #84 #86 #87 #90 #92.

## 3b/3c Per-file minors that moved (old = this addon at v1.94.0, new = v1.105.0)
The loop over the tag's `LibKa0s.xml` (Step 3c), rows that differ only:
```
Core.lua  old: 17  new: 18
Tooltip.lua  old: none  new: 1
Role.lua  old: none  new: 1
Callout.lua  old: none  new: 4
CalloutSettings.lua  old: none  new: 5
WaypointArrow.lua  old: none  new: 2
WaypointArrowSettings.lua  old: none  new: 2
Charts.lua  old: 1  new: 2
Media.lua  old: 12  new: 13
SkinDefs.lua  old: 27  new: 28
SkinDefsOthers.lua  old: 8  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: 1  new: 2
WidgetsReorder.lua  old: 6  new: 7
WidgetsDragHandle.lua  old: 13  new: 14
WidgetsDragHandleTip.lua  old: none  new: 1
WidgetsCopyWindow.lua  old: 5  new: 6
WidgetsHeader.lua  old: none  new: 1
WidgetsBar.lua  old: none  new: 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: 7  new: 11
DebugLogWindow.lua  old: 4  new: 5
Launcher.lua  old: 9  new: 11
OptionsWidgets.lua  old: 45  new: 46
OptionsNav.lua  old: 6  new: 7
OptionsSkinPicker.lua  old: 11  new: 12
OptionsSkinPickerQueue.lua  old: none  new: 1
IconBrowserWindow.lua  old: 1  new: 2
IconBrowser.lua  old: 1  new: 2
PerfPanel.lua  old: 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: 10  new: 11
SimPanelRender.lua  old: 3  new: 4
```
`none` = new in this range. Every file not listed matched before the copy, so there was no cross-major skew.

## 3d Diffs
After `cp -r` of both payloads and before the prune, `diff -r --strip-trailing-cr` and `diff -rq` of `libs/LibKa0s` and `tests/_kit` against the extract printed nothing in either direction (content and bytes clean; no `Only in` line on this addon's side, so no upstream deletion to carry). After the prune the only difference is `media/sounds/` (below). `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside libs/ and tests/:
```
core/Bus.lua:61:LibStub("LibKa0s-Bus-1.0", true)
core/Compat.lua:43:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:16:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:11:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:4:LibStub("LibKa0s-Env-1.0", true)
core/ItemSetup.lua:16:LibStub("LibKa0s-Item-1.0", true)
core/LauncherSetup.lua:9:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:148:LibStub("LibKa0s-Slash-1.0", true)
core/LifecycleSetup.lua:18:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:4:LibStub("LibKa0s-Media-1.0", true)
core/PerfSetup.lua:15:LibStub("LibKa0s-Perf-1.0", true)
core/PoolSetup.lua:13:LibStub("LibKa0s-Pool-1.0", true)
core/SkinSetup.lua:86:LibStub("LibKa0s-Skin-1.0", true)
core/WidgetsSetup.lua:29:LibStub("LibKa0s-Widgets-1.0", true)
modules/IconBrowserSetup.lua:37:LibStub("LibKa0s-IconBrowser-1.0", true)
settings/OptionsSetup.lua:19:LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:140:LibStub("LibKa0s-Schema-1.0", true)
settings/Schema.lua:144:LibStub("LibKa0s-Slash-1.0", true)
settings/Slash.lua:123:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon: LibKa0s-Charts-1.0, LibKa0s-Glow-1.0, LibKa0s-Sim-1.0, LibKa0s-Toast-1.0, and the new-in-range LibKa0s-Role-1.0, LibKa0s-Callout-1.0, LibKa0s-WaypointArrow-1.0, LibKa0s-Tooltip-1.0.

## 3f Kit revision
`grep -n 'Kit.VERSION'`: old `20:Kit.VERSION = 53`, new `20:Kit.VERSION = 57`. Kit 57 pairs with v1.105.0 and both payloads are copied whole in one commit.

## 3g Contract delta and Blockers
Majors that moved and that this addon looks up: Core, Media, Skin (SkinDefs, SkinDefsOthers), Widgets (Widgets, Dropdown, Reorder, DragHandle, CopyWindow, new Header, Bar, DragHandleTip), DebugLog (DebugLog, Diagnostics, Window), Launcher, Options (OptionsWidgets, OptionsNav, OptionsSkinPicker, new OptionsSkinPickerQueue), IconBrowser, Perf (PerfPanel). Read from the v1.105.0 CHANGELOG blocks back to v1.95.0 (their "What a consumer owes" lists).
`grep -rn '__Attach[A-Za-z]*'` outside libs and the kit: none, so no host-supplied member can have moved its call site.

What reached this host and needed a change in this commit (all fixed here, none needing a decision):
- **Options stub `SideTabs`** (v1.100.0, OptionsNav minor 7): `Kit.assertSurfaceParity` read the live Helpers surface by name; `settings/OptionsSetup.lua` gains the no-op.
- **`icon.hot` white under WoW, Midnight and Forever** (v1.105.0, SkinDefsOthers minor 10, LibKa0s#82): `of.bar.worn` followed `icon.hot`, so the outfit bar's worn mark would have turned white under three skins. Repointed to `text.accent` (design D-7 of the run; R5 D-7) in `core/SkinSetup.lua`, design §7.1's token table, and the `tests/test_skinsetup.lua` token pin (a moved pin: both its cases read the row). Ka0s Default's pixel is unchanged (gold, 1, 0.82, 0).
- **Debug console title-bar pin moved** (v1.105.0, DebugLogWindow minor 5, LibKa0s#86): Copy and Clear are now `W.HeaderButtons` extras rows rather than two `makeIconButton(titleBar, ...)` calls. `tests/test_packaging.lua`'s scan of the vendored window re-reads them from the `{ key = ..., icon = ... }` rows and still asserts exactly two; the new `settings` mark is in the kit's `VendorSync.LIBRARY_MARKS` (revision 57), which the same case already reads.
- Launcher `name` vs windows' `addonName` (R9 C8): both are the folder (`core/LauncherSetup.lua:145`, `core/DebugLogSetup.lua:81`, `core/PerfSetup.lua:34`), so the new settings marks open this addon's settings.

Owed and **not** red here: DebugLog stub `Report`/`Serialize` (this addon's DebugLog parity case is reached-member, so it stays green), Compat identity (already wired), Sim sample members (no Sim stub), XML-order loader lines (the harness reads `LibKa0s.xml`), the kit-57 frame hold (no suite changed).

**Blockers: none.**

## 3h Unrecorded vendored tags
The listing (horizon 2026-11-03; vendored: v1.85.0 v1.86.0 v1.87.0 v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.94.0):
```
v1.94.0
```
Span bundle written beside this one: `../2026-11-16-v1.94.0-v1.94.0/`.

## 3i Icon and sound declarations
- `grep -n 'LibKa0s icons:' CLAUDE.md`: `45:LibKa0s icons: all (icon browser).` Kept as written (the icon browser is the chooser).
- No `LibKa0s sounds:` line: the tag's prune removed all 362 Callout voice files (`prune-icons: .: sounds none (no ``LibKa0s sounds:`` line); kept 0 file(s), removed 362`). The addon draws no Callout. Icons: `declares all icons (icon browser); nothing removed`.
- Credits: the same three icon sets ship (all), so README `## Credits` is unchanged.

## 3j Tests that assume the whole icon folder
```
tests/test_credits.lua:153, tests/test_packaging.lua:153/227-229/238, tests/test_skeleton.lua:105
```
All valid under `all`; none is red.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none.
