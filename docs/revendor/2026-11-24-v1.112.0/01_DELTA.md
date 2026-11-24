Delta: LibKa0s v1.110.0 -> v1.112.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.112.0 LibKa0s testkit tools` (tag commit 1f1904ee, a local tag, not on origin). Run under Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/`, item FB-OR-00 (the copy and this bundle). That run decides the adoption (companion dialogs, FB-OR-01), so no interview here.

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-22-v1.110.0` states base v1.109.0. The provenance line before its re-vendor commit (9cdb5b4) named v1.109.0, so the check is ok.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` before the roll printed `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.110.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 9cdb5b4 (K101-OR-01), whose CLAUDE.md names v1.110.0.
- `diff -rq --strip-trailing-cr` of both payloads against a v1.110.0 extract printed only `Only in <extract>/LibKa0s/media: sounds` (the pruned voices). The payload matches.
- Library range: `git -C ../LibKa0s log --oneline v1.110.0..v1.112.0` lists 9 commits: the strip right-click run (SRC-LK-01, two SRC-LK-REL, v1.111.0) and the feedback batch (FB-LK-01..04, FB-LK-03 follow-up, two FB-LK-REL, v1.112.0). v1.111.0 was never vendored here, so it needs no span bundle.

## 3b/3c Per-file minors that moved (old = this addon at v1.110.0, new = v1.112.0)
```
Core.lua               old: 19  new: 20
IconBrowserWindow.lua  old: 2   new: 3
SkinDefsOthers.lua     old: 10  new: 11
SkinPaintControls.lua  old: 20  new: 21
WidgetsCopyWindow.lua  old: 6   new: 7
WidgetsDragHandle.lua  old: 16  new: 17
WidgetsHeader.lua      old: 1   new: 2
```
No file is behind, none is new and none is removed.

## 3d Diffs
After the copy, before the prune, `diff -rq --strip-trailing-cr` and `diff -rq` (bytes) of `libs/LibKa0s` and `tests/_kit` against the extract printed nothing. After the prune, the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), as at v1.110.0.

## 3e Consumption
- `W.HeaderButtons` through `NS.HeaderButtons` (core/WidgetsSetup.lua). WidgetsHeader 2 adds `companion = true`; FB-OR-01 moves the dialogs (modules/UIDialogs.lua) to it.
- `NS.Skin.Button` with `{ primary = true }` (modules/UIDialogs.lua `D.Button`). SkinPaintControls 21 paints a disabled primary as the plain button box, which is the New Outfit dialog's Done while the name is empty (O2). No host remap of `opts.tokens.bg` exists here.
- The icon browser (`NS.IconBrowser`), now a companion through IconBrowserWindow 3. Core `ResolveColor` (player only, unchanged by the optional `standIn`). `FollowColor` is not consumed.
- The bar's drag strip is this addon's own (modules/Bar_Chrome.lua `dragStrip`), so WidgetsDragHandle 17 changes nothing here.

## 3f Kit
`Kit.VERSION` stays 60 (`tests/_kit/framework.lua:20`). `docs/testing.md` already names it.

## 3g Contract delta
- WidgetsCopyWindow 7: the copy window no longer builds a settings mark. No suite here clicks one (`grep -rn CopyWindow tests` outside the kit finds none).
- SkinDefsOthers 11: High Contrast's `hud.shadowX/Y` falls back to 1,-1. No suite here pins it.
- `tests/test_surface_parity.lua` runs no `assertSurfaceParity` on `LibKa0s-Core-1.0`, so `FollowColor` needs no stub.
- No blocker.

## 3h Span
No unrecorded vendored tag.

## 3i Icons
`LibKa0s icons: all (icon browser).` kept. Prune: icons kept whole, sounds removed 362 (unchanged).

## 3j Tests over the icon folder
Unchanged from `../2026-11-20-v1.108.0/01_DELTA.md` 3j.
