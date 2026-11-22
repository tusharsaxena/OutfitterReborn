Delta: LibKa0s v1.109.0 -> v1.109.0 (span: v1.109.0)

Written 2026-11-22 by K101-OR-01, beside `../2026-11-22-v1.110.0/`. This is a records-only back-fill for the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-11-03
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt: v1.85.0 v1.86.0 v1.87.0 v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.94.0 v1.105.0 v1.106.0 v1.107.0 v1.108.0 v1.109.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.109.0
```

v1.109.0 was vendored by `c6658c4` (FU-RV-OR: Re-vendor LibKa0s v1.109.0 (kit revision 59) and standard v2.117.0) from base v1.108.0, with `b404b72` re-copying Compat.lua and Sim.lua from the re-cut tag. Neither commit wrote a bundle.
