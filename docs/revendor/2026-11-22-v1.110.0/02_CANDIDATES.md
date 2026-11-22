# 02 Candidates, LibKa0s v1.109.0 -> v1.110.0

Sources: `git -C ../LibKa0s log --oneline v1.109.0..v1.110.0`; LibKa0s CHANGELOG.md, the v1.110.0 block; `docs/api/Compat/version-6-docs.md` (lines 22-26, the members table rows 18-23); `docs/api/testkit/version-60-docs.md`.

**Class A, delivered on the copy alone**
- Kit revision 60: each client profile's `Enum.BagIndex`, `Enum.BankType` and `C_Bank.CanViewBank` in the harness.

**Class B, host change required (LibKa0s#101's surfaces)**
- `Compat.ContainerGroups()` (version-6-docs.md:22, row 18) would replace `Compat.BankBagIDs` (core/Compat.lua:852). It replaces code the addon owns. adopt: K101-OR-02.
- `Compat.BankerKind(interactionType)` (version-6-docs.md:25, row 21) would replace `Compat.IsBankerInteraction` (core/Compat.lua:867). It replaces code the addon owns. adopt: K101-OR-02.
- `Compat.CanViewCharacterBank()`, `Compat.NumPurchasedBankTabs(bankTypeName)`, `Compat.UnreadyBankContainers(shape, memory, purchased)` and `CONTAINER_PATTERNS_BY_CLIENT` (version-6-docs.md:23-26, rows 19-20, 22-23). These are part of the same issue, and K101-OR-02 decides whether any of them applies here. adopt: K101-OR-02, as that item scopes them.

**Class C, whole-module:** unchanged from `../2026-11-16-v1.105.0/02_CANDIDATES.md`, because the release adds no module.

**Other candidates:** none in this range. Anything outside LibKa0s#101 is deferred, out of scope for this run.

**Blockers (3g):** none.
