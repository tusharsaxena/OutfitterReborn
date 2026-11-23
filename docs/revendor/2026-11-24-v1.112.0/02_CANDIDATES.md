# 02 Candidates, LibKa0s v1.110.0 -> v1.112.0

Sources: LibKa0s CHANGELOG.md, the v1.111.0 and v1.112.0 blocks; `docs/api/Widgets/version-30.3.7.17.3.8.8.7.2.2-docs.md`; `docs/api/Core/version-20.1-docs.md`.

**Class A, delivered on the copy alone**
- SkinPaintControls 21: the disabled primary Done of the New Outfit dialog paints the plain button box with `text.disabled` (owner finding O2).
- SkinDefsOthers 11: High Contrast HUD shadow 1,-1 on the bar's labels.
- IconBrowserWindow 3: the icon browser is a companion.

**Class B, host change required**
- `W.HeaderButtons(bar, { companion = true })` (WidgetsHeader 2) for the dialogs, in place of `settings = false` plus `settingsOptOut`. adopt: FB-OR-01 (the run's decision), with the degraded `hostStrip` taught the same key.
- `lib.FollowColor` / `standIn`: every color here is the player's, which always resolves, and the bar's ladders are already class first. Not adopted (no defect to fix).

**Blockers (3g):** none.
