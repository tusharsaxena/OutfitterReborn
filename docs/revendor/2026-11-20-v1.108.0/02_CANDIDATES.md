# 02 Candidates, LibKa0s v1.107.0 -> v1.108.0

Sources: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0`; LibKa0s CHANGELOG.md, the v1.108.0 block and its *What a consumer owes at its re-vendor* list; `docs/api/Options/version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md` (*Moving to this version*); `docs/api/testkit/version-58-docs.md`.

**Class A, delivered on the copy alone**
- The Optimize progress bar's fill draws the skin's statusbar texture and follows a switch (`S.ApplyBarFill`, SkinPaintControls 19, 97.17).
- The context menu's submenu arrow takes the menu palette's tint on every paint (WidgetsDropdown 3, 97.4), and the menu measures no secret label (U-21).
- The outfit window's footer lays out only its shown marks (Widgets 30, LibKa0s#94).
- The stricter kit guards (revision 58).

**Class B, host change required**
- `W.OwnerWarnings(owner, sink)` (Widgets 30, 97.1): reports an owner-less library widget built under a painted frame. Optional; every library widget this addon builds passes `owner` (core/WidgetsSetup.lua). Not adopted in this item; noted for the lead.
- `Core.ApplySkin` `skinBands` (Core 19, 97.16): for a host that draws its own edge. This addon hands no host skin table, so it does not apply.

**Class C, whole-module**: unchanged from `../2026-11-16-v1.105.0/02_CANDIDATES.md`; the release adds no module.

**Blockers (3g)**: the ColorPair's new `bar.bgColorFromSkin` companion, and the kit's new typed-value hits, both fixed in the re-vendor commit (01_DELTA.md 3g).
