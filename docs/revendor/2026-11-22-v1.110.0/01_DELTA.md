Delta: LibKa0s v1.109.0 -> v1.110.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.110.0 LibKa0s testkit tools` (tag commit e97bf187, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.110.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-22-LIBKA0S_101_CONTAINER_READER/`, item K101-OR-01 (the copy and this bundle). That run lists its adoption item, K101-OR-02, so no interview here.

## Step 0 pre-flight (this addon)
Newest single-tag bundle `2026-11-20-v1.108.0` states base v1.107.0. The provenance line before its re-vendor commit (eb2e271) named v1.107.0, so the check is ok.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` before the roll printed `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.109.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = b404b72 (the re-cut v1.109.0 Compat.lua and Sim.lua). Its CLAUDE.md names v1.109.0, so the two agree.
- `diff -rq --strip-trailing-cr` of both payloads against a v1.109.0 extract printed only `Only in <extract>/LibKa0s/media/sounds: callout` (the pruned voices; icons are `all`). The payload matches.
- Library range: `git -C ../LibKa0s log --oneline v1.109.0..v1.110.0` lists 6 commits (K101-LK-01, K101-LK-02, K101-LK-REV, two K101-LK-REL and the v1.109.0 merge). Issue named: LibKa0s#101.

## 3b/3c Per-file minors that moved (old = this addon at v1.109.0, new = v1.110.0)
The loop over the tag's `LibKa0s.xml` (Step 3c), rows that differ only:
```
Compat.lua  old: 5  new: 6
```
No file is behind (no cross-major skew), none is new and none is removed.

## 3d Diffs
After the copy, before the prune, `diff -rq --strip-trailing-cr` and `diff -rq` (bytes) of `libs/LibKa0s` and `tests/_kit` against the extract printed nothing. After the prune, the only difference is `media/sounds/callout/` (362 voice files, no `LibKa0s sounds:` line), the same as at v1.109.0.

## 3e Consumption
`LibKa0s-Compat-1.0` is looked up at `core/Compat.lua:43` (and in `tests/test_secrets.lua`). This addon still carries its own copies of what Compat 6 now ships: `Compat.BankBagIDs` (core/Compat.lua:852) and `Compat.IsBankerInteraction` (core/Compat.lua:867). K101-OR-02 adopts the library members for both.

## 3f Kit
`Kit.VERSION` moves from 59 to 60 (`tests/_kit/framework.lua:20`). Both payloads move together in one commit. `docs/testing.md` names the revision and is rolled in the same commit.

## 3g Contract delta
- `git -C ../LibKa0s diff v1.109.0 v1.110.0 -- docs/api/Compat/version-5-docs.md` adds only the superseded header and *Moving to version 6*, which says the change is additive and that the seventeen existing members and their behavior do not move. No sentence under an existing surface changed.
- Kit revision 60: the Forever and Retail profiles install `Enum.BagIndex`, `Enum.BankType` and `C_Bank.CanViewBank` only when the consumer's mock set and `_G` have none. This addon's `tests/wow_mock.lua` builds no `Enum.BagIndex` or `C_Bank`, so its harness now sees each client's real bank shape. Both profiles stayed green.
- No suite here pins `Compat.MINOR` or `KIT_VERSION`, and `tests/test_surface_parity.lua` runs no `assertSurfaceParity` on `LibKa0s-Compat-1.0`.
- `grep -rn '__Attach[A-Za-z]*'` outside the payloads found no site. No blocker.

## 3h Span
Unrecorded vendored tag: v1.109.0 (FU-RV-OR, c6658c4 plus b404b72). Written beside this bundle as `../2026-11-22-v1.109.0-v1.109.0/`.

## 3i Icons
`LibKa0s icons: all (icon browser).` kept. Prune: icons kept whole, sounds removed 362 (unchanged).

## 3j Tests over the icon folder
Unchanged from `../2026-11-20-v1.108.0/01_DELTA.md` 3j. Every file they read ships under `all`, so there is no blocker.
