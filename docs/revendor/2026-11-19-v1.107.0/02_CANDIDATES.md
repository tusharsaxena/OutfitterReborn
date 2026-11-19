# 02 Candidates, LibKa0s v1.106.0 -> v1.107.0

Sources: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0`; LibKa0s CHANGELOG.md, the v1.107.0 block and its *What a consumer owes at its re-vendor* list; `docs/api/Widgets/version-28.2.7.15.2.7.8.6.1.1-docs.md`.

**Class A, delivered on the copy alone**
- The drag strip's marks read `?` · settings · close in the window header's tints, tighter pitch, the settings mark on by default (WidgetsDragHandle minor 15), and its tooltip always above the strip (WidgetsDragHandleTip minor 2); `ApplyLevel` re-levels the gear (LibKa0s#96). This addon draws no drag strip, so none of it shows here.

**Class B, host change required**: none for this addon. The owed host changes (pass `onClose`, delete a `tooltipPlace` hook, re-pin strip literals, declare `settings`) apply only to a strip host; the icon is already declared under `all`.

**Class C, whole-module**: unchanged from `../2026-11-16-v1.105.0/02_CANDIDATES.md`; the release adds no module.

**Blockers (3g)**: none.
