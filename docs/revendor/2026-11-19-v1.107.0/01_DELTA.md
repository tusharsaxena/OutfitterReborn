Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit 5e96365, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, item AF-RV-OR (the copy and bundle; that run lists its adoption items, so no interview here).

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-16-v1.105.0` states base v1.94.0; the provenance line before its re-vendor commit named v1.94.0. ok.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md`: `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).` before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 55ce778 (Re-vendor LibKa0s v1.106.0); its CLAUDE.md names v1.106.0. They agree.
- `diff -rq --strip-trailing-cr` of both payloads against a v1.106.0 extract printed nothing apart from the pruned `media/sounds/callout` voices (payload-matches; icons are `all`).
- Library range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` is 6 commits (AF-LK-01, AF-LK-02, AF-DR-LK, AF-LK-03 and the v1.106.0 merge); issue named in it: LibKa0s#96.

## 3b/3c Per-file minors that moved (old = this addon at v1.106.0, new = v1.107.0)
The loop over the tag's `LibKa0s.xml` (Step 3c), rows that differ only:
```
WidgetsDragHandle.lua  old: 14  new: 15
WidgetsDragHandleTip.lua  old: 1  new: 2
```
No file is behind (no cross-major skew), none is new and none is removed. `LibKa0s-Widgets-1.0` key 28.2.7.15.2.7.8.6.1.1.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr` of `libs/LibKa0s` and `tests/_kit` against the extract printed nothing. After the prune the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), the same as v1.105.0.

## 3e Consumption
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: this addon looks up Widgets among others, but it draws no `W.DragHandle` of its own (`grep -rn 'DragHandle(' --include='*.lua'` outside `libs/` finds nothing), and the only library caller, `Callout.lua`, is a module this addon does not consume. The two files that moved therefore draw nothing this addon shows.

## 3f Kit
`Kit.VERSION` 57 in the extract and in `tests/_kit/framework.lua`: the kit did not move (`diff -rq` of the two kit trees is empty).

## 3g Contract delta
The moved majors intersected with the consumed ones: Widgets, through WidgetsDragHandle and WidgetsDragHandleTip only. Their contract changes (the settings mark on by default, `tooltipPlace` and `place` retired, the marks' order and pitch) bind a host that builds a drag strip; this addon builds none. `grep -rn '__Attach[A-Za-z]*'` outside the payloads: no site. **Blockers: none.**

## 3h Span
`v1.106.0` was vendored and never recorded: the span bundle `../2026-11-19-v1.106.0-v1.106.0/` is written in this run.

## 3i Icons
`LibKa0s icons: all (icon browser).` kept, so `settings` (the icon the release's *What a consumer owes* names for a strip host) is declared. Prune: icons kept whole, sounds removed 362 (unchanged from v1.105.0).

## 3j Tests over the icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua'` outside `_kit`: `tests/test_credits.lua:153` and `tests/test_packaging.lua:153,229-231` read the license and author files, which ship under `all`. No blocker.
