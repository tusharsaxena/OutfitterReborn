Delta: LibKa0s v1.106.0 -> v1.106.0 (span: v1.106.0)

Written 2026-11-19 by AF-RV-OR, beside `../2026-11-19-v1.107.0/`. A records-only back-fill: the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-11-03
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt: v1.85.0 v1.86.0 v1.87.0 v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.94.0 v1.105.0 v1.106.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.106.0
```

v1.106.0 was vendored by `55ce778` (Re-vendor LibKa0s v1.106.0, Widgets minor 28: the HUD dock guards its measurements, RangeMaster#17), base v1.105.0, a one-file copy with the provenance roll and no bundle.
