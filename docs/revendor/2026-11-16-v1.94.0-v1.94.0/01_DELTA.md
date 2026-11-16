Delta: LibKa0s v1.94.0 -> v1.94.0 (span: v1.94.0)

Written 2026-11-16 by RV-OR, beside `../2026-11-16-v1.105.0/`. A records-only back-fill: the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-11-03
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt: v1.85.0 v1.86.0 v1.87.0 v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.94.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.94.0
```

v1.94.0 was vendored by `3b82737` (OR-F1: Re-vendor LibKa0s v1.94.0; the default skin per client), base v1.93.0, under the WoW Forever port, whose run kept no revendor bundle.
