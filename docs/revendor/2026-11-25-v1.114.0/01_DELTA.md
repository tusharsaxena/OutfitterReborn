Delta: LibKa0s v1.113.0 -> v1.114.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.114.0 LibKa0s testkit tools` (tag commit 2eaa8fc9, a local tag, not on origin). Run under Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/` (`03_SPEC.md` §8 and §9), item SF-OR-02. That run decides the one adoption (LibKa0s-ForeverDB-1.0), so there is no interview here.

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-24-v1.113.0` states base v1.112.0. The provenance line before its re-vendor commit named v1.112.0, so the check is ok. The last payload commit since, 85446c2 (FB2-OR-02, the re-cut v1.113.0), was a refresh of the same tag: its parent's line already named v1.113.0.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` before the roll printed `47:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.113.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 85446c2, whose CLAUDE.md names v1.113.0.
- `diff -rq` of the v1.113.0 extract against the payload printed only `Only in <extract>/LibKa0s/media: sounds` (the sound prune), and the kit matched, so the payload is v1.113.0.
- Library range: `git -C ../LibKa0s log --oneline v1.113.0..v1.114.0` lists 7 commits: SF-LK-01 (two), SF-LK-02 (two), SF-LK-REL (three).

## 3b/3c Per-file minors that moved (old = this addon at v1.113.0, new = v1.114.0)
```
ForeverDB.lua            old: (none)  new: local MAJOR, MINOR = "LibKa0s-ForeverDB-1.0", 1
DebugLogDiagnostics.lua  old: 11      new: 12
```
ForeverDB.lua is new in this range (`LibKa0s.xml` loads it after `Item.lua`). No file is behind and none is removed.

## 3d Diffs
After the copy and before the prune, `diff -rq --strip-trailing-cr` and `diff -rq` of both payloads against the extract printed nothing. After the prune, the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), as at v1.113.0.

## 3e Consumption
- DebugLog (core/DebugLogSetup.lua): DebugLogDiagnostics 12 adds ForeverDB to the running-majors line and prints one `ForeverDB: present=... loaded=...` line through the new major's `Status()`, which never loads the data addon. It reaches `/or diag` on the copy alone.
- `LibKa0s-ForeverDB-1.0`: no lookup before this run. SF-OR-02 adopts it (core/ForeverDBSetup.lua).

## 3f Kit
`Kit.VERSION` 60 -> 62 (`tests/_kit/framework.lua:20`): revision 61 adds `mock_foreverdb.lua`, revision 62 regenerates `client_globals_forever.lua`. `docs/testing.md` now names 62. Both payloads move together, so the pairing rule holds by construction.

## 3g Contract delta
- DebugLogDiagnostics 12 only adds a line; no suite here pins the diagnostics line count or the majors list (test_diagnostics and the kit's test_diagnostics_contract stay green).
- The regenerated Forever globals file passed the kit's `test_client_globals` on both profiles.
- No blocker.

## 3h Span
No unrecorded vendored tag (the audit walk over `docs/revendor/` printed nothing).

## 3i Icons
`LibKa0s icons: all (icon browser).` kept. Prune: icons kept whole, sounds removed 362 (unchanged).

## 3j Tests over the icon folder
Unchanged from `../2026-11-20-v1.108.0/01_DELTA.md` 3j.
