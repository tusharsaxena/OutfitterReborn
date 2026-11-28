# Ka0s Outfitter Reborn — Architecture

The engineer brief and the hub of the doc set (documentation-§3). Each section below summarizes and
links its topic doc; the registers at the end (`## Documentation map`, `## Documented deviations`)
are read here. The design the addon is built to is
[`superpowers/specs/2026-11-03-design.md`](superpowers/specs/2026-11-03-design.md) (the design), and
the build order is
[`superpowers/plans/2026-11-03-ka0s-conversion.md`](superpowers/plans/2026-11-03-ka0s-conversion.md)
(the plan).

## Overview

Ka0s Outfitter Reborn is an equipment manager for Retail (Midnight, 12.x) and WoW Forever, from one
codebase (`## Interface: 120105, 16001`; see Per-client features below). A player builds named
outfits, wears them by hand from a window docked to the character sheet, from an outfit bar, from key
bindings or from `/or`, and lets **native triggers** wear and remove them automatically: fishing,
gathering, a battleground or arena by map, a druid form, a spec, a mount, and about seventy more
(77 in all). It is a rewrite of the community fork of Outfitter by John Stephen (mundocani), MIT
licensed, as an Ace3 addon in the standard's modular layout, on the vendored `LibKa0s` (the release
the `CLAUDE.md` provenance line names).

Three ideas carry the design:

- **One store, one writer per key.** `OutfitterRebornDB` holds settings per profile and outfits per
  character (`db.char`), and no profile callback touches `db.char` (H7, H30). Every settings write goes
  through one seam, `NS.SetByPath`; every outfit-record write goes through `NS.Outfits`.
- **One equipment bracket that cannot strand.** Every change to what is worn runs inside
  `NS.Equip.Batch(fn)`, an `xpcall` bracket that always restores its counter, so an error in a trigger
  or a secret value can no longer stop equipment updates for the session (the fork's worst bug).
- **Triggers are data.** A trigger is a shipped descriptor (events, typed parameters, a condition
  from a family factory). An outfit stores only the trigger's id, its flags and its parameters, so
  behavior always comes from the code that ships. There is no `loadstring` and no script editor (R3).

**What ships in 1.1.0.** The whole port is in the tree: the seams over `LibKa0s`, the AceDB store
with its migration runner, the equipment engine (inventory scan, outfit store, stack, the equip
bracket, the Equipment Manager mirror, the bank verbs, the stat optimizer, the battle-pet companion),
the native trigger catalog with its binder and state producers, the docked outfit window and its
slot checkboxes, the outfit bar, the dialogs and menus, the tooltips and quick slots, test mode, the
public API, four settings pages (General, Outfit Bar, Outfit Window, Profiles), 36 slash verbs and 15 key bindings (as measured on 2026-11-06)
and six translation overlays. What it does not do yet, and what a client has still to confirm, is
under Known Limitations.

### Per-client features

The addon serves Retail and WoW Forever from one codebase (clients-§1; the roster's Clients value is
`Retail · Forever`). The client is asked in one place: `core/ClientSetup.lua` reads `NS.CLIENT` once at
load from `NS.Compat.ClientKey()` (`LibKa0s-Compat-1.0`, clients-§3; without the library it answers
Retail) and publishes `NS.PerClient(pair)` and `NS.ForClientRows(list)`, which the `defaults/` files and
the modules call at **file scope** (clients-§5). Feature code never asks which client it runs on. A
Retail-only feature is declared `clients = { "retail" }` and never built on Forever: no descriptor,
picker entry, schema row or setting (clients-§4), so it is absent, never hidden. The owner's rulings
D1 to D10 and the probes behind each value are in
[`superpowers/specs/2026-11-08-forever-port-design.md`](superpowers/specs/2026-11-08-forever-port-design.md);
a value an open probe has still to confirm is marked `-- PROBE Pn` at its site and has a smoke row in
`smoke-tests.md` sections 14 to 18. Every seeded game id (aura, form, NPC, difficulty, map, skill
line, pet, item and icon ids) is re-validated per client against that client's own wago.tools build
by `tools/seeds/seeds.py` (clients-§10), under the contract in [`validate-seeds.md`](validate-seeds.md).

| Feature | Retail | WoW Forever | Picked in |
|---|---|---|---|
| Equipment slots (D2) | the 18 slots | the same 18 plus `RangedSlot` (18) after the two hands; ranged, thrown and relic invtypes go there | `defaults/Items.lua` (`ID.SLOT_NAMES`), `modules/SlotEnables.lua` |
| Ammo slot (D1) | — | not in outfits yet (needs a stack-aware equip path); the slot's arrow and empty-slot click open the addon's own ammo picker, since Blizzard's flyout lists no ammo | `modules/QuickSlots_Ammo.lua` |
| Stats (D9) | Haste, Versatility, Mastery | spell damage, healing, attack power, MP5, hit, defense (PROBE P14) | `modules/ItemStats.lua` (`STAT_KEYS`) |
| PvP zones (D3) | every battleground, arena and brawl row | the generic battleground row, AV, AB, WSG (PROBE P17); no brawls | `defaults/Zones.lua` (`Z.rows`, `Z.BRAWL_MAP_IDS`) |
| Instance difficulty (D7) | Retail's groups | open world, normal dungeon (PROBE P17), 20-player raid 148 and 40-player raid 9 (PROBE P18) | `defaults/TriggerData.lua` (`DIFFICULTY_GROUPS`, `DIFFICULTY_ORDER`) |
| Retail-only triggers (D5, D6) | the four content quests, Pet Battle, Tree of Life | absent; Quest Turn-in and Cooking's core stay | `defaults/Triggers.lua` (`clients`), `modules/Triggers.lua` (`Finalize`) |
| Retail-only params | arena, Vashj'ir, Find Fish, Cooking's fire pets | absent | `defaults/Triggers.lua`, `modules/Triggers.lua` (`buildParams`) |
| The Tree of Life state | `FORM_TREE` | absent | `defaults/TriggerData.lua`, `modules/States.lua` |
| Shadowmeld (P4) | 58984 | 20580 | `defaults/TriggerData.lua` |
| Titan's Grip | spec 2 grips | never | `modules/PlayerState.lua` (`TITANS_GRIP_SPEC`) |
| `TARGET` names | `Name-Realm` | `First Surname` (regional names) | `Compat.UnitCharacterName` |
| Bank containers | the character tabs (`CharacterBankTab_1..6`, 6 to 11); the warband tabs are not scanned (O19) | the character tabs (`CharacterBankTab_1..9`, 6 to 14); the keyring is not scanned, and there is no warband bank | LibKa0s-Compat `ContainerGroups().bank`, through `Compat.BankBagIDs` |
| Sheet button (D8) | the sidebar tab row (stock, EllesmereUI, Chonky), shown with the paper doll | the last button of `CharacterFrame.ModeTabs`, a `LargeSideTabButtonTemplate` CheckButton outside Blizzard's mode switching (PROBE P27), at the strip's scale, below the last tab or right of it on Chonky's skinned row, in Chonky's skin there; shown on every CharacterFrame tab (Forever smoke feedback S1, S4) | `modules/Sheet.lua` (`Sheet.ButtonAnchor`), `modules/Dock.lua` |
| Window under the side strip (S5) | none | widened by the strip's reach, its contents moved right of it, when the strip runs down the window's left edge; the footer's hairline still spans the whole window and only *New outfit* on it moves (FB-OR-02) | `modules/Sheet.lua` (`Sheet.StripInset`), `modules/Window.lua` (`Win.SetLeftInset`) |
| Flyout drawer (D4, S7) | the left column's arrows moved and mirrored, flyouts re-anchored to the slot | every arrow re-anchored and turned outward by F-UI's own rules, the flyout anchored by F-UI's formula for the outward direction, flush on a slot whose `BorderFrame` is hidden (S3) | `modules/QuickSlots.lua` (`FOREVER_DRAWER`) |
| Default skin | Ka0s Default | WoW Forever | `core/SkinSetup.lua` (`Skin:DefaultSkin()`) |

Both clients take the modern APIs first: `C_PaperDollInfo.GetInventorySlotInfo` and
`C_ChatInfo.PerformEmote`, with the bare globals behind them, and the host strata read passes the
secret guard. The suite runs under both kit profiles (`docs/testing.md`).

## Module Map

The TOC (`OutfitterReborn.toc`) is the load order and the authority on it: `libs → locales → core →
defaults → modules → settings`. The full table, every file with its one job and the reason for each
`LOAD-BEARING` line, is [`module-map.md`](module-map.md).

In outline: `core/` holds the seams, each a lease on one `LibKa0s` major with a degrade stub
(`core/Compat.lua` and `core/Secrets.lua` are the addon's own); `defaults/` holds pure data (the
profile defaults, the item and zone tables, the trigger catalog and its ID tables, the test-mode
outfits; `defaults/Profile.lua` is the only place a default is hardcoded); `modules/` holds, in load
order, the engine (`PlayerState` through `Companion`), the triggers and their state producers
(`Triggers_*`, `States`, `States_Zone`), then the UI (`Commands` through `Preview`, with `Sheet`
reading which character sheet is up for the dock, and `Broker` the Outfits data source), the public API
(`Api`) and the diagnostics sections; `settings/` holds the schema, the slash dispatcher and the
pages, last.

## Settings Schema

The store is `OutfitterRebornDB`, one AceDB object on the shared "Default" profile (H30), shaped by
`defaults/Profile.lua`. Settings live in `profile`; outfits live in `char`; `global` holds the
migration stamp, LibDBIcon's table and the skin notice. `global.schemaVersion` is the migration stamp,
advanced by `NS:RunMigrations` (`core/Database.lua`) after each step returns; a step may walk every
stored profile (`scope = "profile"`) or every stored character (`scope = "char"`).

There are two Schema instances (design §3.5). `NS.Schema` (`settings/Schema.lua`) holds every settings
row and is the only one Options, the slash CLI and Reset all read; `NS.OutfitSchema`
(`modules/Outfits_Schema.lua`) holds the per-outfit instance rows (`outfit.*`,
`trigger.<TID>.*`). `NS.SetByPath(path, value, instanceId)` is the one write seam for both: a non-nil
`instanceId` forwards to the outfit instance. Their roots are `NS.ResolveSettingsRoot` and
`NS.ResolveOutfitRoot` in `core/Database.lua`.

The full shape, every default, the migration path, the outfit and item records and the registry
detail are in [`schema.md`](schema.md). The section has spilled there, so `schema.md` is also the
one home of the **named non-setting state** (the window positions, LibDBIcon's minimap position, the
outfit store, the persisted stack and recents, the preserved equipment sets, the triggers' own
state): each piece's storage key, its one owner module and every function that writes it
(architecture-§5).

## Message Bus

`core/Bus.lua` declares the whole catalog: `NS.MSG`, 23 keys as measured on 2026-11-06, wire names
`Ka0s_OutfitterReborn_<Pascal>`, each with its one sending file on a `Sender:` line that
`tests/test_bus.lua` holds every `NS.SendBus` call site to. Handlers are isolated by LibKa0s-Bus (or
by the degraded arm's `xpcall`), and nothing is dispatched before `OnEnable` and the first LoadPass.
Every key has exactly one sending file in the tree, and `test_bus` holds the rule. Every key also
has a receiver: `STATS_CHANGED` and `LEGACY_DETECTED`, which nothing heard, were dropped.
Every message with its sender, payload and receivers: [`message-bus.md`](message-bus.md).

## Slash Commands

`/or` is the command and `/outfitterreborn` its alias; both reach one dispatcher (`settings/Slash.lua`, on
LibKa0s-Slash), behind a host routing wrapper that runs macro conditionals through
`SecureCmdOptionParse` (H25). `NS.COMMANDS` opens with the reserved verbs:

| Verb | What it does |
|---|---|
| `help` | Show this help |
| `config` | Open the settings panel |
| `skin` | Choose a skin: open the skin picker |
| `enable` | Turn the addon on |
| `disable` | Turn the addon off without unloading it |
| `list` | List every setting |
| `get` | Read one setting: `/or get path` |
| `set` | Write one setting: `/or set path value` |
| `reset` | Reset one setting: `/or reset path` |
| `resetall` | Reset every setting (asks first) |
| `debug` | Debug console; `on`/`off` set logging, `diagnostics` writes the report |
| `diagnostics` | Write the diagnostics report to the debug console |
| `perf` | Performance capture; try `/or perf help` |
| `version` | Print the addon version |

The outfit verbs (`show`, `hide`, `wear`, `unwear`, `toggle`, `update`, the bank verbs, `auto`,
`zone`, `iteminfo`, `test`, `bar`, `lock`, `unlock`, `deleteall` and the rest) follow `version`, with
their handlers in `modules/Commands.lua` (`bar show|hide|toggle` writes `bar.shown` in
`settings/Slash.lua`, or in test mode only dismisses the bar for that test session; the *Toggle outfit bar* key runs it). The live-while-disabled rules, the macro-conditional routing and
the full verb set are in [`slash-dispatch.md`](slash-dispatch.md). The three report verbs (`missing`,
`zone`, `iteminfo`) write to the debug console through `NS.DebugLog:Report` with one chat pointer,
and their refusals stay in chat (debug-logging-§15; [`debug.md`](debug.md#reports)).

## Public API

`modules/Api.lua` builds the one surface another addon may call, `NS.API.v1`, and publishes it
under the folder's name as `_G[addonName] = { API = NS.API }`, so a consumer reads
`OutfitterReborn.API.v1`, as public-api requires (standard v2.99.1). Only the
API table is global, never `NS`. **v1 is semver-stable**: a member is never removed or changed in
meaning inside v1, and a breaking change arrives as a sibling `v2`.

| Member | Answers |
|---|---|
| `FindOutfitByName(name)` | A copy `{ id, name, category }` of the outfit with that name (case-insensitive), or nil |
| `WearOutfit(name)` | `true` when the outfit was worn; `false` for an unknown name or while the addon is stood down |
| `RemoveOutfit(name)` | `true` when the outfit was taken off; `false` for an unknown name, an outfit not worn, or while stood down |
| `GetCurrentOutfitInfo()` | `name, id` of the top outfit; `""` when nothing is worn, the localized "Custom" for a temporary outfit |
| `GetOutfitsUsingItem(link)` | An array of copies `{ id, name }`; empty for a secret or unparsable link |
| `RegisterOutfitEvent(fn)` | `true` once `fn` is subscribed (a second call with the same `fn` is the same subscription); `false` for a non-function or with no event bus |
| `UnregisterOutfitEvent(fn)` | `true` when `fn` was subscribed |

The contract:

- **No member raises.** Called before the saved data exists (at the caller's own load), each answers
  its empty value.
- **Answers are fresh copies**, so nothing a caller writes into one can reach the store.
- **Stood down, the two wear calls refuse** (disabled means not running); the reads still answer.
  An addon's wear is not a hardware event, so it never changes the player's title.
- **Events.** A subscriber is called as `fn(event, id, ...)` for the six outfit messages
  (`OUTFIT_ADDED`, `OUTFIT_DELETED`, `OUTFIT_RENAMED`, `OUTFIT_WORN`, `OUTFIT_REMOVED`,
  `OUTFIT_EDITED`). `event` is the catalog key, never the wire name, and `...` is the rest of the
  bus payload ([`message-bus.md`](message-bus.md)). Each call is isolated with `xpcall` and a raise
  goes to the client's error handler; a return value is ignored. Nothing is delivered before the
  session's first LoadPass, and nothing while the addon is stood down.

The legacy `Outfitter_*` globals are gone and are not shimmed (H3, deviation row D1 below);
`tests/test_api.lua` pins the members and the global allow-list.

## Event Subscriptions

Game events are registered on module-local AceEvent targets through `NS.SafeRegisterEvent` (and a
player-only unit event through `NS.SafeRegisterUnitEvent` on a unit-filtered frame), so a name the
client rejects lands in `NS.rejectedEvents` and `/or diagnostics` instead of raising. The addon
object registers none: each module registers its own in its `Resume()` and drops them in its
`Suspend()`. In outline:

- **PlayerState**: combat, death, the player's casts and the spec.
- **Inventory**: the bag, bank and item-info events, and the player's `UNIT_INVENTORY_CHANGED`.
- **Equip** and **Outfits_Seed**: the loading-screen edges and the first LoadPass.
- **States** and **States_Zone**: the player's `UNIT_AURA`, the Dining and Spirit watches while a
  trigger needs them, the zone events, and a 0.5 s mounted and swimming poll.
- **Dock**: `PLAYER_REGEN_DISABLED`/`ENABLED`, to hide the window for combat. **Bar**: pet battles.
  **EquipmentManager**: `EQUIPMENT_SETS_CHANGED`. **ItemStats_Sources**: `ADDON_LOADED`, for a stat
  addon that loads late.
- **Triggers_Binder**: each bound trigger's descriptor events, on the outfit's own target.
- **core/SecureQueue.lua** and **core/SkinSetup.lua**: `PLAYER_REGEN_ENABLED`, only while something
  waits out combat.

The full table and the pipeline from event to equipped item are in [`data-flow.md`](data-flow.md).

## Frame layering

Every strata and level comes from `NS.Constants.LAYERS` (`core/Constants.lua`, frame-layering-§5);
there is no strata literal anywhere. The two docked surfaces take their layer from the character
sheet: the outfit window copies the sheet holder's strata and sits `LAYERS.LEVEL.DOCK_OVER_HOST`
above it. The slot checkboxes take the **host strata**, the highest among `CharacterFrame` and its 18
`Character<Slot>` buttons (ranked by `LAYERS.STRATA_ORDER`; ChonkyCharacterSheet lifts the slot
buttons to `HIGH` under a `MEDIUM` sheet, EllesmereUI lifts the sheet itself), and one level above
the highest frame **of that strata** under the sheet, capped at `LAYERS.LEVEL.MAX` (smoke round 2
design G3). So they beat the item buttons and any addon drawing over them, and a high level in a
lower strata no longer inflates theirs. While Blizzard's equipment flyout is open on a sheet slot, the
boxes take the higher of the host strata and the flyout's (`HIGH`) and a level over it, out of lockdown only, and drop back when it closes
(smoke round 3 E2). On WoW Forever the ammo picker is `FLYOUT` (`HIGH`), the strata of the flyout it
stands in for. Both docked surfaces re-sync from the window's follow tick, on a level or a
strata change, because raising the sheet changes its level. Neither ever gets a fixed strata, which
would poke it through a window that covers the sheet (the fork's lesson, kept). The bar is `HUD`
(its header band, test strip and labels ride its own levels; the separate drag handle is retired),
the dialogs and the icon browser `MODAL` (the browser in a band over the dialogs), the menus `POPUP`
(each cascading level of a menu in the same strata) and the compare tooltips `CURSOR`. The full stack
is in the design's §7.1 and the limitations it leaves are in [`known-limitations.md`](known-limitations.md).

**Window chrome** (standalone-windows' *Window chrome geometry* and *The footer*, preview-mode's *Where
the strip sits*; AD-88-OR and AD-89-OR, 2026-11-17). Both test strips are the library's `TestStrip`,
placed by its own docking (`dock = "title"`), never anchored by the addon: the window's under
`frame.titleBar`, a mouse-transparent frame over the title band down to 1 px under the divider, which
`Win.SetLeftInset` moves with the divider; the bar's under its header band (`Bar.Band`). Each body moves
down by `TEST_STRIP.HEIGHT` (plus the window's 2 px gap) while its strip shows, laid from config. The
window's bottom row is the library's `Footer` (`NS.MakeFooter`, `FOOTER.HEIGHT` 24 px, no fill, a
hairline in the skin's `divider`), with *New outfit* on its left and *Slots: All None* on its right;
the list ends above it. Under a side strip the footer keeps the window's whole width, so the hairline
runs edge to edge, and `Win.SetLeftInset` moves *New outfit* alone by the shift (owner O1, FB-OR-02). The bar has no footer. The dialogs' Done / Cancel rows are a modal's button
row, which the footer rule does not cover.

**Title-bar marks** (standalone-windows' *Title-bar controls*; AD-86-OR, LibKa0s#86, 2026-11-17). Every
window this addon draws builds its marks with the library's `W.HeaderButtons` through one seam,
`NS.HeaderButtons` (`core/WidgetsSetup.lua`): right-aligned, left to right extras · settings · close,
18 px marks with 12 px art, 6 px from the corner and 6 apart, `icon.tint` at rest and `text.link` under
the pointer (the close `close.hot`), each with its tooltip above it; the owner is always the addon's
folder, the launcher's `name`, and the close is built through `NS.MakeCloseButton`. Without the
library the seam builds the same strip by hand. The **outfit window** reads settings · close at the
top right (y -5); its settings mark opens the settings panel, refused while the addon stands down, and
leaves the window shown (it sits beside the character sheet, not over the panel). The **outfit bar**
reads lock · settings · close, laid on its title band by `S.Header` from the strip's offsets: the lock
keeps its state art and its two-line tooltip, the settings mark opens the bar's own settings page
(as the header's right click does), and the drag strip stops 2 px short of the lock; the bar's narrowest
width (`Bar.Layout.MIN_WIDTH`) is 136 to hold the title beside three marks. The **dialogs** (outfit,
trigger, rebuild, progress) are **companion windows** (standalone-windows v2.119.0, *A companion
window carries no settings mark*): each opens only from a control on the outfit window, a row menu
or the bar, edits only that owner's outfit or search and keeps no position of its own, so its strip
is built with `companion = true` and carries the close alone, with no gear and no waiver reason
(`headerButtons.companion`; the hand-built strip honors the same key). The icon browser is the
library's own companion. The addon builds no LibKa0s `DragHandle`, so the drag strip's settings mark does not arise.

**Tooltip placement** (standalone-windows' *Tooltip placement*, frame-layering-§4; AD-92-OR,
LibKa0s#92, 2026-11-18). Every tooltip the addon places itself is classified and placed through
LibKa0s-Tooltip-1.0, never at the cursor and never by a corner anchor:

| Element | Kind | Placed by | Group |
|---|---|---|---|
| An outfit window row (category, outfit, sample outfit, item) and a row's EM mark | body | `NS.PlaceBodyTip` (`core/CoreSetup.lua`) → `PlaceBeside` | the outfit window |
| An outfit bar button (an outfit, a sample) | body | `NS.PlaceBodyTip` → `PlaceBeside` | the whole bar |
| The outfit tooltip (`NS.OutfitTooltip.Show(id, owner, group, always)`) | body | `NS.PlaceBodyTip` → `PlaceBeside` | the group its caller passes |
| An ammo picker button (WoW Forever): the bag item's own tooltip | body | `NS.PlaceBodyTip` → `PlaceBeside` | the ammo picker |
| Title-bar controls: the window's and bar's marks, the bar's lock, every dialog's close | chrome | `NS.ShowTitleTip` / the library's `AttachTitleTip` → `PlaceAttached` | — |

`NS.PlaceBodyTip(tip, el, group)` runs after the tooltip is owned at `ANCHOR_NONE`, filled and shown:
right of the group, else left, top level with the element (the comparison side set to match). With
unreadable geometry it falls back to `PlaceAttached` above the element, then a plain `BOTTOM`-on-`TOP`
attach (0, 2). The outfit window is the whole group: it has no companion panel. A plain body
tooltip (a sample outfit, a category's description, the EM mark) is filled by `NS.ShowBodyTip`: line 1
in the skin's `gtip.title`, the rest in `gtip.body`, read at each show (skinning-§7). Every other line
this addon writes on a client tooltip or frame reads a token too: the outfit tooltip, the appended
*Equipment Sets:* line (`gtip.title`), the launcher's host line (`gtip.line`), the sheet button's
tooltip (`gtip.title`, owner U-7) and the hotkey message on `UIErrorsFrame` (the owner token
`of.message.equip`, following `sem.good`).

The side each body tooltip took is remembered with the element it was placed against
(`NS.BodyTipSide`, while the tooltip is still owned by that element). On an outfit window item row it
drives the addon's own compare tooltips (`OutfitterRebornCompareTooltip1..5`, body rule 5):
`Compare.Placement` chains them further out on that same side, off `ShoppingTooltip2`, else
`ShoppingTooltip1`, else `GameTooltip`, so they never open back over the item tooltip and the window.
The client may run its compare before the row places its tooltip, so the row calls `Compare.Reside`
after placing, which draws ours again from the side just chosen. An item tooltip that grows after it
is placed (item data arriving late, the outfit line added) is placed again from the item post-call
(`NS.Tooltips.OnItem` → `NS.ReplaceBodyTip`, the library's `Replace`); ours are drawn again when that
changes the side. A window docked on the
character sheet's right may, with no room right of it, open a row's tooltip on its left, over the
sheet; the sheet is Blizzard's, not part of the group.

Left where they are, out of scope (the rule's *What it does not bind*), each held by
`tests/test_tooltip_place.lua`'s guard:

- **The outfit tab on the character frame** (`modules/Dock.lua`, `SetOwner(self, "ANCHOR_RIGHT")`): a
  button parented to and drawn as part of Blizzard's `CharacterFrame`, in the host's look
  (DEV-SKIN-SHEET-BUTTON); tooltips over Blizzard's frames are not bound.
- **The compare tooltips on a client-placed item tooltip** (`modules/Tooltips_Compare.lua`, owned at
  `ANCHOR_NONE` and chained `TOPLEFT`/`TOPRIGHT` off the item tooltip) for an item hovered in a bag,
  on the sheet or in a link: they extend a tooltip the client placed, so with no side of this addon's
  to follow they take the screen half with more room. On an outfit window item row they are in scope
  and follow the row's side (above).
- **Item tooltips decorated in place** (`modules/Tooltips.lua`, the outfit lines added to the client's
  own item tooltips): client-placed.
- **The settings canvas pages** and **LibDataBroker displays** (the broker object's tooltip is drawn
  by the display) and the **minimap button** (the library's Launcher, `PlaceLauncher`, launcher-§7).

## Taint Notes

Every secure-environment write goes through `NS.SecureQueue.Run(key, fn)`: it runs at once out of
combat lockdown, otherwise it waits (latest per key) and replays on `PLAYER_REGEN_ENABLED`
(events-frames-taint-§2). Nothing is written into a Blizzard frame or table (skinning-§7), with one
accepted exception, the equipment flyout's rim tint (`DEV-SKIN-FLYOUT-TINT`, below; the ammo picker, an addon frame in Blizzard's flyout art, is `DEV-SKIN-AMMO-PICKER`): hooks are
`hooksecurefunc` or `HookScript`, and every hook body checks the stand-down latch first. The outfit
list's secure item buttons make the window protected, so it hides for the length of combat and is
moved rather than its rows re-anchored. While the paper doll is shown (Forever smoke feedback S7),
every slot's own popout arrow is shown per button (never `EquipmentFlyoutPopoutButton_ShowAll`/`HideAll`,
which write `flyoutLocked`), re-shown after Blizzard's `HideAll` through a post-hook, and turned
outward with its flyout (Retail: the left column moved and mirrored; Forever: by F-UI's own rules
through post-hooks, never writing `flyoutDirection`); all of it out of lockdown only and put back
when the doll goes. On Forever the ammo slot gets an arrow of the addon's own (not Blizzard's popout
template, whose OnLoad joins Blizzard's popout list), set as the slot's `popoutButton`, the one field
this addon writes on a Blizzard frame. It opens the addon's own ammo picker, which equips out of combat
only and never touches Blizzard's flyout or its list. On Forever
CharacterFrame is never opened from addon code: its OnShow compares secret health values, which
raises under taint, so the broker opens it through a secure click (`OutfitterRebornBrokerClick`) and
`NS.Dock.Open` keeps the wish instead. The full notes, with each secure surface and the client checks still
owed: [`taint.md`](taint.md).

## Known Limitations

- The window is hidden for the length of combat (a behavior change from the fork, O4).
- Old saved variables are not migrated: 1.1.0 starts from a fresh store (R4), and old key
  assignments are lost (H11).
- Both the old Outfitter and this addon may change gear if both are loaded; the addon warns once and
  does not hold its triggers (O2).
- The six translations carry only what the fork translated; a string the port rewrote or added shows
  in English on those clients.
- The sheet button copies each host sheet's tab, so it inherits that sheet's quirks: Chonky's tab row
  sits about 18 px right-heavy with it, and the EllesmereUI label takes EllesmereUI's face when it is
  placed, not when EllesmereUI changes it.
- On WoW Forever outfits do not hold ammo yet (the slot has the ammo picker only), triggers match one spell
  rank's ID, and `/or show`, the window key and the broker menu's *Open outfit window* cannot open a
  closed sheet (they keep the wish and say so); the port's step-1 limits are in `known-limitations.md`.

The full list, with the client checks still owed: [`known-limitations.md`](known-limitations.md).

## Documentation map

Frozen and generated stores are named once each and not enumerated: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` and `docs/investigations/` (documentation-§3).
Of those, `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/revendor/<date>-v<tag>/` and `docs/superpowers/` exist today; so does `docs/seed-research/`,
the frozen per-build seed bundles `tools/seeds/seeds.py` writes (one `<date>-<flavor>/` per run, not
enumerated; clients-§10). `docs/superpowers/` holds the design, the plan and the research behind
them, and `docs/reviews/2026-09-16/` is the fork's last review, kept frozen.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file: the hub |
| [`scope.md`](scope.md) | What the addon does, and what it deliberately leaves out |
| [`module-map.md`](module-map.md) | Every authored file, its job, and the TOC load order with its reasons |
| [`schema.md`](schema.md) | SavedVariables shape, defaults, migrations, the outfit and item records, named non-setting state |
| [`settings-panel.md`](settings-panel.md) | The `Page \| Covers` table and the page → tab → row tree, mapped to schema paths |
| [`data-flow.md`](data-flow.md) | Load and enable, the write seam, the stand-down latch, and the trigger → stack → equip pipeline |
| [`common-tasks.md`](common-tasks.md) | Recipes for the changes most often made here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| [`perf-analysis/README.md`](perf-analysis/README.md) | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| [`slash-dispatch.md`](slash-dispatch.md) | Present | `NS.COMMANDS` holds the reserved verbs and the outfit verbs, well past the trigger of eight or more |
| [`midnight-quirks.md`](midnight-quirks.md) | Present | `core/Compat.lua` carries client-version workarounds of its own (the table-detector ladder, the spec ladder's stub) and the secret-value rules |
| [`forever-quirks.md`](forever-quirks.md) | Present | The addon ships on WoW Forever (Clients `Retail · Forever`): it carries the Forever catalog (forever-quirks-§1); its own section holds none yet |
| [`compat-layer.md`](compat-layer.md) | Present | `core/Compat.lua` publishes far more than the trigger's three hand-written shims ([`compat-layer.md`](compat-layer.md) has the counting grep) |
| [`message-bus.md`](message-bus.md) | Present | 23 messages in `NS.MSG` as measured on 2026-11-06 (the trigger is more than ten) |
| [`profiles.md`](profiles.md) | Present | A Profiles page ships in the options UI (`settings/Profiles.lua`) |
| [`known-limitations.md`](known-limitations.md) | Present | Known Limitations spilled: the full list passes ~60 lines; the hub keeps a summary |
| [`taint.md`](taint.md) | Present | Taint Notes spilled: the secure surfaces pass ~60 lines; the hub keeps a summary |
| [`debug.md`](debug.md) | Present | The diagnostics report ships (always fired) |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| [`testing.md`](testing.md) | How to run the harness and lint; the green commit gate; the suite checkpoints |
| [`smoke-tests.md`](smoke-tests.md) | The owner's in-game checklist and every client assumption with its pass criterion |
| [`test-cases.md`](test-cases.md) | The generated case inventory (authoritative pass count) |
| [`performance.md`](performance.md) | The addon performance page |
| [`automated-tests/README.md`](automated-tests/README.md) | What the automated-test record is and how to produce it |
| [`automated-tests/RESULTS.md`](automated-tests/RESULTS.md) | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| [`validate-seeds.md`](validate-seeds.md) | The seed-validation contract `/dev-copilot:validate-seeds OutfitterReborn <retail\|forever>` runs: the tool, the id kinds and tables, the ruling precedent, the steps and the gate |

The fork's `users-manual.md` was retired in P10: its player content is the README (the one
player-facing document, documentation-§1), and its slash-command table was a second copy of
[`slash-dispatch.md`](slash-dispatch.md), which Tier 3 may not duplicate.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `versioning-git` (the semver line) | The release is 1.1.0, although the public API (the `Outfitter_*` globals are gone, H3) and the saved-data format (a fresh `OutfitterRebornDB`) both break, which would call for a MAJOR | D1. Owner ruling 2026-11-03 (the plan's Version decision): 1.1.0 continues the fork's numbering on CurseForge project 1698220. The consumers that lose globals are named in the Version History (design §5.16) | 2026-11-03 | The next MAJOR release |
| `standalone-windows` (plain non-secure window, movable, saved position, Lock/Reset, toplevel; the `UISpecialFrames` MUST is honored) | The main window is a protected frame: each outfit row carries a `SecureActionButtonTemplate` child (`modules/Window_Rows.lua`). It is docked to the character sheet: not movable, no saved position, no Lock or Reset, strata and level copied from `OutfitterRebornSheetHolder`, not toplevel. It is hidden for the length of combat and returns at `PLAYER_REGEN_ENABLED`. Its dialogs stay open through that combat suspend. Escape closes it through `UISpecialFrames`. **Test mode** (D10): while the session-only test mode is on and the sheet is closed, the window stands alone in the screen center (`NS.Dock.AloneSpot`, through the dock's one `TOPLEFT` point and `Dock.Refresh`, never in lockdown), listing the sample outfits under a test strip; alone, it is draggable for the test session, out of combat only, and its position is not saved (the drop clears the client's user-placed flag; the next session starts centered), and it stores nothing (no position, no outfit). X or Escape hides it for the rest of that test session without ending test mode, which still ends only on its own switch, combat or Reset all (preview-mode); opening the sheet docks it as usual | D2. Owner ruling R5 (H4). The outfit list's secure item buttons make every in-combat Show, Hide or SetPoint on the window a blocked action (the fork at `7ea3dc3:Outfitter.lua:1326-1331, 8448-8494`). Closing dialogs in combat would lose input (O30). The test-mode clause is D10 of the [2026-11-05 design](superpowers/specs/2026-11-05-smoke-round-2-design.md) (owner ruling 2026-11-05): the player places and skins the window without opening the sheet, as PGFE's test mode does; it reverses H17 ("the window shows real data"), marked so at H17 in the 2026-11-03 design. Smoke round 3 E3 (owner, 2026-11-05) amends the clause from "still unmovable" to "draggable for the session, position not saved" ([round 3 plan](superpowers/plans/2026-11-05-smoke-round-3.md)) | 2026-11-03; test clause 2026-11-05, E3 amendment 2026-11-05 | Blizzard ships a docking API, or the list stops needing secure buttons; for the test clause, preview-mode gains a rule for docked windows |
| `standalone-windows` (explicit window verbs `show` / `hide` / `toggle`, a SHOULD) | `/or show` and `/or hide` open and close the window, but there is no window `toggle` verb: `/or toggle <outfit>` stays the outfit verb. The key binding and the sheet button toggle the window | C35. `toggle` has been the outfit verb in players' macros since before this fork, and taking it for the window would break them. The reason is also at the comment above `NS.COMMANDS` (`settings/Slash.lua`) and in [`slash-dispatch.md`](slash-dispatch.md) | 2026-11-03 | `toggle` retires as an outfit verb, or the standard names a different window-toggle verb |
| `standalone-windows` (*Which marks a window owes*, v2.115.0: a primary window carries close, settings and lock in its header) | The outfit window, this addon's primary window (docked beside the character sheet), carries the close and the settings mark (`W.HeaderButtons` through `NS.HeaderButtons`, `modules/Window.lua:239-244`) and no lock mark | AF-WVR-OR. Owner waiver 2026-11-19 (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/inputs/OWNER_FEEDBACK.md`; `inputs/HUD_HEADER_AUDIT.md`): the window is docked to the sheet and follows it, so there is nothing to lock; it drags only when undocked in test mode (`modules/Dock.lua:225-228`, `canDrag`) | 2026-11-19 | The window becomes freely movable outside test mode |
| `localization-§4` | The IN_ZONES subzone list matches `GetMinimapZoneText()` strings captured on the player's own client | D3. No API exposes the current areaID; zones match on uiMapID (H9) | 2026-11-03 | Blizzard exposes the current areaID |
| `localization-§4` | LOCKPICKING matches the lockbox tooltip line against `LOCKED_WITH_SPELL` + `GetTradeSkillDisplayName(633)`, and falls back to `L["Requires Lockpicking"]` when that does not reproduce the line | D4. No GlobalString for the line is confirmed (O22); without the fallback the trigger is dead on any client where the composed form differs | 2026-11-03 | The client check confirms the composed GlobalString form on every shipped locale, after which the `L` fallback and this row go |
| `documentation-§1` | The README has no screenshots of the 1.1.0 UI | D6. They need a client capture of the reskinned docked window and settings pages after the smoke test; stale shots would mislead (H22) | 2026-11-03 | The first client capture of 1.1.0 |
| `localization-§4` | `Inv.SlotItemActive` (the TRINKET_QUEUE skip-while-active rule) parses the item's use-duration tooltip line with the `cUseDurationTooltipLineFormat*` patterns kept in `L` | D8. No GlobalString or ID route gives an active use effect's remaining duration yet (O15) | 2026-11-03 | `C_Item.GetItemSpell` plus spell-duration data (or an aura read) covers it, after which the `L` keys and this row go |
| `launcher-§1` | A second LibDataBroker object, `OutfitterRebornOutfits` (type `data source`, `modules/Broker.lua`), carries the old addon's outfit switcher; the launcher object is unchanged, and the second object is never put on the minimap | Owner ruling 2026-11-04: players used the old broker plugin to switch outfits, and the launcher's clicks and logo are fixed by launcher-§2/§4 | 2026-11-04 | The standard allows a feature data source next to the launcher |
| `skinning-§1`/`skinning-§9` (`DEV-SKIN-SHEET-BUTTON`) | The sheet button (`OutfitterRebornSheetButton`, `modules/Dock.lua`) draws the host sheet's tab look, not the Ka0s skin: on the stock sheet and ChonkyCharacterSheet a hand-built copy of Blizzard's `PaperDollSidebarTabTemplate` (TabBg, icon, Hider and Highlight from `Interface\PaperDollInfoFrame\PaperDollSidebarTabs` with the template's texcoords, selected while the window shows); on EllesmereUI a text tab, `L["Outfits"]`, in EllesmereUI's tab style (its face at size 10, white at 0.6 idle, 1.0 on hover, `EllesmereUI.ELLESMERE_GREEN` while the window shows). On WoW Forever, one more tab of the mode strip in that strip's template; on ChonkyCharacterSheet's skinned strip a copy of Chonky's skin (its `CCS_BG` file and coords and its tints copied live off the neighboring tabs, the outfit icon in Chonky's round mask, Chonky's fixed yellow glow while the window shows; Forever smoke feedback S1, [2026-11-09](superpowers/specs/2026-11-09-forever-smoke-feedback-design.md)). No `NS.Skin` call paints it, it left `Kit.skinSwitch.surfaces` (`tests/skin_surfaces.lua`), and its three typed values are `Kit.skinValues` rows citing this id (`tests/run.lua`) | Smoke round 2 design D3/D4 (G2), [2026-11-05](superpowers/specs/2026-11-05-smoke-round-2-design.md): the way in sits in the host's own tab row, and a skinned button there read as bolted on; matching the neighboring tabs is the point, so the skin must not reach it | 2026-11-05 owner ruling | The standard gains a host-matched ingress exception, or a host changes its tabs (Blizzard's sidebar tab art, Chonky's tab row, EllesmereUI's tab style) |
| `skinning-§7` (`DEV-SKIN-FLYOUT-TINT`) | While the outfit window is on screen and Blizzard's equipment flyout is open on one of the 18 paper-doll slots, `modules/QuickSlots.lua` (`QS.TintSync`) desaturates the flyout's rim (`EquipmentFlyoutFrame.buttonFrame.bg1..bgN` and `NavigationFrame.BottomBackground`), and on WoW Forever the open ammo picker's strips (`DEV-SKIN-AMMO-PICKER`), and gives it the skin's window border color (`win.border`) through `SetVertexColor`. Each texture's own color and desaturation are read before its first tint and written back exactly when the window closes, when another host's slot opens the flyout (Item Upgrade, Item Interaction, Runeforge) and at the stand-down (`QS.Suspend`); a skin change re-tints; nothing is written in combat lockdown. Tint only: no new art, no reparenting, no anchor change, and the slot `Highlight` is left alone. Under Ka0s Default the rim reads near black | Smoke round 3 E1 (screen 16): the flyout's gold `UI-GearManager-Flyout` rim beside the skinned window read as a different UI. The owner accepted a skin color on Blizzard's shared frame, held only while this addon holds the flyout, and the near-black rim under Ka0s Default that comes with it ([round 3 plan](superpowers/plans/2026-11-05-smoke-round-3.md), *Owner rulings on the held items*). Cited at `modules/QuickSlots.lua` and `core/SkinSetup.lua`; pinned by `tests/test_flyout_tint.lua` | 2026-11-05 owner ruling | The standard allows a host-held tint of a Blizzard frame, or Blizzard restyles the flyout |
| `skinning-§1`/`skinning-§9` (`DEV-SKIN-AMMO-PICKER`) | WoW Forever's ammo picker (`OutfitterRebornAmmoPicker`, `modules/QuickSlots_Ammo.lua`) is an addon frame drawn as Blizzard's equipment flyout, not in the Ka0s skin: the `UI-GearManager-Flyout` parchment strips cut and laid exactly as `EquipmentFlyout_UpdateItems` lays them (one slot, one row, several rows), the item frame sized and anchored as Blizzard's `buttonFrame` (TOPLEFT to the arrow's TOPRIGHT plus the paper doll's `anchorX`/`anchorY`), `ItemButton`s in Blizzard's grid painted by Blizzard's `SetItemButtonTexture`/`Count`/`Quality`, the worn type left out, and the gold `UI-GearManager-ItemButton-Highlight` glow centered on the ammo slot at the slot's own size (50 : 40). On Forever neither ChonkyCharacterSheet (no flyout code) nor EllesmereUI (its flyout skin stands down on Forever) restyles the flyout, so this is the flyout's look on every sheet; what they change is geometry, read live (the arrow the drawer sets flush on a hidden `BorderFrame`, the slot's size). Its rim follows `DEV-SKIN-FLYOUT-TINT` while the outfit window shows. No `NS.Skin` call paints it and it is not a `Kit.skinSwitch` surface (`tests/skin_surfaces.lua`); pinned by `tests/test_ammo_picker.lua` | The picker stands in for the flyout every other slot opens (Blizzard's lists no ammo; the owner's report, 2026-11-28), and a skinned panel beside Blizzard's flyout arrow read as a different UI. The owner asked for Blizzard's flyout art, accommodating Chonky and EllesmereUI, and ruled it an accepted deviation with the rim following the flyout tint | 2026-11-28 owner ruling | The standard gains a host-matched exception for a surface that stands in for a Blizzard one, Blizzard restyles the flyout, or a sheet addon starts restyling it on Forever (Chonky; EllesmereUI's `FlyoutSkinActive`) |
| `localization-§4` | The gathering triggers (GATHER_HERBALISM, GATHER_MINING) match the node tooltip's line against `C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)`, the client's own localized name for an ID, not a GlobalString constant | D10. Tooltip data exposes no skill line for a node; the name is never hardcoded or put in `L`, so the match is correct on every locale | 2026-11-03 | `TooltipDataProcessor` exposes the node's skill line |

One more row is conditional (the design's §10): **D7** (`localization-§7`, CJK and Cyrillic text
in Skin faces) is written only if smoke test X1 shows a box glyph. The vendored Skin major already
refuses a face the client's locale cannot draw, so only that client check remains. The client checks
the design's §14 still owes are mapped to their rows in
[`smoke-tests.md`](smoke-tests.md#10-what-the-headless-run-cannot-reach) section 10.

Not deviations, recorded for audit clarity: `UnitFactionGroup`'s first return is read with a comment,
and the standard's defect is raised upstream (H10); the per-outfit trigger parameters are instance
rows on LibKa0s-Schema v3, so no row is needed (H13); triggers translate onto AceEvent rather than a
dispatcher (H14); no simulator ships, a MAY (H18); the options ship in the addon with four
subcategories, below options-ui-§4's five-subpanel trigger, so this is compliance and is the comment in
`settings/OptionsSetup.lua` (H21); the macro-conditional wrapper is host routing, not a dispatcher fork
(H25); the quick slots' flyout post-hooks (`modules/QuickSlots.lua`) are not a skin path, since
`skinning-§7` governs what a skin paints and `events-frames-taint-§3` binds only an addon that
replaces a Blizzard frame (the design's D11, ruled out by the 2026-11-04 audit).

### Files over the 1500-line cap

Nothing is over the cap today.
