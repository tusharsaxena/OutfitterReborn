# 02 Candidates, LibKa0s v1.113.0 -> v1.114.0

Sources: LibKa0s CHANGELOG.md, the v1.114.0 block; `docs/api/ForeverDB/version-1-docs.md`.

**Class A, delivered on the copy alone**
- DebugLogDiagnostics 12: `/or diag` names ForeverDB among the running majors and prints its present/loaded/version line, without loading it.

**Class C, whole-module adoption**
- `LibKa0s-ForeverDB-1.0` (`version-1-docs.md`, *Lib-level surface*, `Item(id)`): on WoW Forever, an outfit's missing items, which the client often cannot describe until they are cached, can take quality and required level from ForeverDB. Additive: a new setup file, a new setting, and the outfit tooltip's missing list. Recommendation: adopt (the run decides it, SF-OR-02).

No other new surface: the kit's `mock_foreverdb.lua` is the fake the adoption's suite uses, and the seed contract (SF-LK-02) is library-side only.

**Blockers (3g):** none.
