Delta: LibKa0s v1.112.0 -> v1.113.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.113.0 LibKa0s testkit tools` (tag commit cded10bb, a local tag, not on origin). Run under Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/R2_SMOKE_FEEDBACK.md`, item FB2-OR-01 (the copy, this bundle and the round-2 audits). That run decides the adoption, so no interview here.

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-24-v1.112.0` states base v1.110.0. The provenance line before its re-vendor commit (6091acd) named v1.110.0, so the check is ok.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` before the roll printed `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.112.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 6091acd (FB-OR-00), whose CLAUDE.md names v1.112.0.
- Library range: `git -C ../LibKa0s log --oneline v1.112.0..v1.113.0` lists 9 commits: FB2-LK-01 (two), FB2-LK-02 (two), FB2-LK-03, two FB2-LK-REL and two FB2-LK-REV.

## 3b/3c Per-file minors that moved (old = this addon at v1.112.0, new = v1.113.0)
```
Sim.lua                old: 4   new: 5
WidgetsDropdown.lua    old: 3   new: 4
```
No file is behind, none is new and none is removed.

## 3d Diffs
Before the copy, `diff -rq` of both payloads against the v1.113.0 extract printed only `Sim.lua`, `WidgetsDropdown.lua` and `Only in <extract>/LibKa0s/media: sounds`. After the copy and the prune, the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), as at v1.112.0.

## 3e Consumption
- `W.Dropdown` through `NS.MakeDropdown` and `W.ContextMenu` through `NS.OpenMenu` (core/WidgetsSetup.lua). WidgetsDropdown 4 paints a selected dropdown row and a ticked context-menu row (`radio`, `selected`) in the menu's selected color, held 20 CIEDE2000 off `menu.text`. The radios of the outfit menu now light; its toggles (`CreateCheckbox`) carried an inline tick in the label and no `selected`, so they stay plain until FB2-OR-01 hands them to the tick column.
- `W.SelectedColor(owner)` is new; this addon draws no menu of its own past the shared one, so it is consumed only by the suite.
- `LibKa0s-Sim-1.0`: this addon runs no sim (no `sim` verb, no Sim row on the launcher, H18). Its suites read `Sim.Sample()` for made-up players; `SampleCrowd` is not needed.

## 3f Kit
`Kit.VERSION` stays 60 (`tests/_kit/framework.lua:20`). `docs/testing.md` already names it.

## 3g Contract delta
- No suite here pins `Sim 4` or `WidgetsDropdown 3`, or an Azeroth selection at `menu.textSel`.
- No suite stubs the Sim table, so `SampleCrowd` and `CROWD_MAX` need no stub.
- No blocker.

## 3h Span
No unrecorded vendored tag.

## 3i Icons
`LibKa0s icons: all (icon browser).` kept. Prune: icons kept whole, sounds removed 362 (unchanged).

## 3j Tests over the icon folder
Unchanged from `../2026-11-20-v1.108.0/01_DELTA.md` 3j.
