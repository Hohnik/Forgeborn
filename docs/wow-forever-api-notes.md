# WoW Forever addon notes — UI and API reference

Notes for building a native-looking addon (a forging minigame) for **World of Warcraft: Forever**.
They come from reading Blizzard's own UI source for the Forever client:
`Gethe/wow-ui-source`, branch `forever`, build **1.60.1.70450** (Oct 16, 2026).
Nothing here was tested in a running client.

---

## 1. What Forever is, technically

- **Internal codename: "Camelot".** `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT == 18`
  (`Blizzard_ProjectConstants/Camelot/ProjectConstants.lua`).
- It runs on the **modern retail engine and UI framework**. In TOC terms it belongs to the `mainline` family, not `classic`.
  - It is not built on the Classic Era codebase, even though the game world is the 2004 one.
  - So all retail-era APIs apply: `C_*` namespaces, mixins, ScrollBox, the new Menu system, the Settings API and the addon compartment.
- How the UI is assembled: Blizzard TOCs load `[Family]` files (= `Mainline`), then `[Game]` files (= `Camelot`) as overrides.
  - About 200 lines across the UI are Forever-only.
  - Forever has its own Character frame, PaperDoll, Skills, Reputation, Bags (ContainerFrame), Bank, Stable, Friends, Micro menu, Unit frames, World map, Minimap, Collections tabs and Talent overrides.
  - There are Forever-only systems too: `Blizzard_LegacySystem` and `Blizzard_HardcoreUI` (shared with Vanilla).
- **Forever reuses the retail atlas and template names, but the client ships Forever art behind them.**
  - From `Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua`: *"the art made for Camelot doesn't match the exact size of the Mainline Standard art and needs to be offset differently."*
  - So `PortraitFrameTemplate`, `ButtonFrameTemplate`, `UIPanelButtonTemplate` and the rest automatically render in Forever's style.
  - **This is the main rule for blending in: build only from stock templates and atlases, and don't ship custom frame art.**
- Retail's addon restrictions ("secret values") exist here too. The docs mark 3,680 functions as `AllowedWhenUntainted` and 92 as `NotAllowed`.
  - This matters for combat data, not for a self-contained minigame.

## 2. TOC

- **Interface: `16001`** (beta/test value from warcraft.wiki.gg). Verify the live number with `select(4, GetBuildInfo())`.
- **Per-flavor file names**: `MyAddon_Forever.toc` or `MyAddon_Camelot.toc` load first. `_Mainline.toc` also matches Forever, plus retail and Plunderstorm.
- Alternatively, use one `MyAddon.toc` with `## AllowLoadGameType: camelot`, or put `[AllowLoadGameType camelot]` on individual file lines.
- **Path variables** in file lines: `[Family]` (Mainline), `[Game]` (Camelot), `[TextLocale]`.
- Other useful directives:
  - `SavedVariables` and `SavedVariablesPerCharacter`
  - `IconTexture` or `IconAtlas` (icon in the addon list)
  - `AddonCompartmentFunc`, `AddonCompartmentFuncOnEnter`, `AddonCompartmentFuncOnLeave`
  - `Category`
  - `LoadOnDemand`

```toc
## Interface: 16001
## Title: Forgeborn
## Notes: A push-your-luck forge for the items you loot.
## AllowLoadGameType: camelot
## SavedVariablesPerCharacter: ForgebornCharDB
## IconTexture: Interface\Icons\Trade_BlackSmithing
## AddonCompartmentFunc: Forgeborn_OnCompartmentClick
Core.lua
UI.xml
UI.lua
```

## 3. Native windows (the look)

**Base window templates** (Mainline versions are used in Forever, with Forever art):

| Template | Use |
|---|---|
| `PortraitFrameTemplate` | Standard window: round portrait in the top-left, title bar, close X. Used by Forever's own `LegacySystemFrame` and `PetStableFrame`. |
| `ButtonFrameTemplate` | Portrait window with a built-in `Inset` and a bottom button bar. |
| `PortraitFrameTemplateMinimizable` / `ButtonFrameTemplateMinimizable` | Same, with a minimize button. |
| `DefaultPanelTemplate`, `BasicFrameTemplate(WithInset)` | Plainer dialog windows. |
| `InsetFrameTemplate` | Recessed inner panel. |
| `ThinGoldEdgeTemplate`, `DialogBorderTemplate`, `TooltipBackdropTemplate` | Borders. |

Portrait helpers on `PortraitFrameMixin`: `SetTitle(text)`, `SetPortraitToAsset(fileID)` and `SetPortraitTextureRaw(path)`.

**Make it behave like a native panel** (opens beside the Character frame and closes with Esc):

```lua
UIPanelWindows["ForgebornFrame"] = { area = "left", pushable = 1, whileDead = 1 }
-- Blizzard's own Forever panel uses: area="left", xoffset=35, pushable=1, allowOtherPanels=1, checkFit=1
-- (Blizzard_LegacySystem/Blizzard_LegacySystemRegistration.lua via RegisterUIPanel)
ShowUIPanel(ForgebornFrame)   -- HideUIPanel / ToggleFrame
-- or, for a free-floating window that only needs Esc to close it:
tinsert(UISpecialFrames, "ForgebornFrame")
```

Source: `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua` (`RegisterUIPanel`, `ShowUIPanel`, `HideUIPanel`, `UISpecialFrames`).

**Controls confirmed in the Forever source:**

| Need | Template / API |
|---|---|
| Big red action button ("Strike") | `BigRedThreeSliceButtonTemplate`, `SharedGoldRedButtonTemplate`, `SharedGoldRedButtonSmallTemplate` |
| Normal buttons | `UIPanelButtonTemplate`, `SharedButtonTemplate`, `SharedButtonSmallTemplate`, `SharedButtonLargeTemplate` |
| Item slots with quality border | `CreateFrame("ItemButton", ...)`, `SmallItemButtonTemplate`, `LargeItemButtonTemplate`, `GiantItemButtonTemplate`, `CircularItemButtonTemplate`; helpers `SetItemButtonTexture`, `SetItemButtonQuality`, `SetItemButtonCount`, `SetItemButtonDesaturated`, `SetItemButtonOverlay`, `SetItemButtonBorder` (`Blizzard_ItemButton`) |
| Progress bar | `ColoredProgressBarTemplate`. Forever has its own version in `Blizzard_SharedXML/Camelot/ProgressBars`, used by its Skills and Reputation bars. |
| Gold display | `SmallMoneyFrameTemplate`, `GetMoneyString(copper)` |
| Tabs | `PanelTabButtonTemplate` (bottom), `LargeSideTabButtonTemplate` (side; used by Forever's bank) |
| Checkbox / slider / input | `UICheckButtonTemplate`, `MinimalSliderWithSteppersTemplate`, `InputBoxTemplate`, `SearchBoxTemplate` |
| Dropdown | `WowStyle1DropdownTemplate` + `MenuUtil.CreateButtonMenu` |
| Right-click menu | `MenuUtil.CreateContextMenu(owner, generator)` (`Blizzard_Menu`) |
| Lists | `WowScrollBoxList` + `ScrollUtil`, `CreateDataProvider()` |
| Confirm dialogs | `StaticPopupDialogs["X"] = {...}`, `StaticPopup_Show("X")` |
| Tooltips | `GameTooltip:SetOwner`, `AddLine`, `AddDoubleLine`, `SetItemByID`, `SetHyperlink`; data access via `C_TooltipInfo.*` |
| Sparkle on success | `AnimatedShineTemplate` (`Blizzard_AnimatedShine`); proc glow via `ActionButtonSpellAlertManager` (action buttons only) |
| Tutorial callouts | `HelpTip:Show(...)`, `HelpPlate` (Forever has its own override) |

**Fonts** (inherit, don't ship fonts): `GameFontNormal` (gold), `GameFontHighlight` (white), `GameFontNormalLarge`, `GameFontHighlightLarge`, `GameFontNormalMed3`, `SystemFont_Shadow_Huge1`, `GameFontDisable`, `NumberFontNormal`.

**Reference windows to copy layouts from:**
- `Blizzard_LegacySystem/Blizzard_LegacySystem.xml`: a Forever-native `PortraitFrameTemplate` window with tabs.
- `Blizzard_StableUI/Camelot/Blizzard_StableUI.xml`: portrait window, inset, item-like slots, purchase button and money frame. This is the closest in spirit to a small game window.
- `Blizzard_UIPanels_Game/Camelot/BankFrame.xml`: grid of item slots, side tabs, money and a purchase button.
- `Blizzard_ItemUpgradeUI` (Mainline, loads in Forever): an "upgrade an item" window with `itemupgrade_*` atlases. It's thematically perfect, but check in game that its art is present and looks right in Forever.

## 4. Items and quality

- **Quality enum** (`Enum.ItemQuality`): Poor 0, Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, Artifact 6, Heirloom 7, WoWToken 8.
- **Colors**: `C_Item.GetItemQualityColor(q)` returns r, g, b, hex; also `ITEM_QUALITY_COLORS[q]` and `ColorManager.GetColorDataForItemQuality(q)`.
- **C_Item** (121 functions):
  - Item info: `GetItemInfo`, `GetItemInfoInstant`, `GetItemNameByID`, `GetItemIconByID`, `GetItemQualityByID`, `GetDetailedItemLevelInfo`, `GetItemInventoryTypeByID`, `GetItemClassInfo`, `GetItemSubClassInfo`, `GetItemStats`
  - Loading and existence: `DoesItemExistByID`, `IsItemDataCachedByID`, `RequestLoadItemDataByID`
  - Event when data arrives: `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED`
- **Async-safe pattern**: `Item:CreateFromItemID(id):ContinueOnItemLoad(function() ... end)` (`Blizzard_ObjectAPI`).
- **Forever's item database is the 2004 world plus new Forever items.** Retail item IDs may not exist.
  - Build the item pool from what the player actually sees: bags (`C_Container.GetContainerItemID` / `GetContainerItemInfo`), equipped gear (`GetInventoryItemID`) and loot.
  - Or use a curated list of classic IDs checked with `DoesItemExistByID`.
- **An addon can't change real items, gold or stats.**
  - Everything forged lives only in SavedVariables.
  - Use real item **names, icons and quality colors** as presentation only.
  - Show your own tooltip. Don't use `SetItemByID`, because the real item's stats would confuse players.

## 5. Other APIs you'll use

| Area | API |
|---|---|
| Timers | `C_Timer.After`, `C_Timer.NewTicker`, `C_Timer.NewTimer` |
| Sound | `PlaySound(SOUNDKIT.X)`, `C_Sound.PlaySound`. Forge-flavored kits in `SoundKitConstants.lua` include `UI_70_ARTIFACT_FORGE_TRAIT_RANKUP`, `UI_70_ARTIFACT_FORGE_TRAIT_FINALRANK`, `UI_REFORGING_REFORGE`, `UI_EPICLOOT_TOAST`, `UI_LEGENDARY_LOOT_TOAST`, `UI_BONUS_LOOT_ROLL_START/LOOP/END` (good for a slot-machine moment) and `LOOT_WINDOW_COIN_SOUND`. Check in game that each one plays in Forever. |
| Save / share | `C_EncodingUtil.SerializeCBOR/DeserializeCBOR`, `SerializeJSON`, `CompressString`, `EncodeBase64`, which are good for seed and run export strings |
| Settings | `Settings.RegisterVerticalLayoutCategory(name)` + `Settings.RegisterAddOnCategory(cat)`; `Settings.RegisterCanvasLayoutCategory(frame, name)` for a custom page |
| Minimap entry | Addon compartment exists in Forever (with its own art): TOC `AddonCompartmentFunc` or `AddonCompartmentFrame:RegisterAddon{ text=, icon=, func= }` |
| Events | `frame:RegisterEvent`, `EventRegistry:RegisterCallback`, `EventUtil.ContinueOnAddOnLoaded(name, fn)` |
| Addon info | `C_AddOns.GetAddOnMetadata`, `C_AddOns.IsAddOnLoaded`, `C_AddOns.LoadAddOn` |
| Slash command | `SLASH_FORGEBORN1 = "/forge"; SlashCmdList.FORGEBORN = fn` |
| Combat check | `InCombatLockdown()` and the `PLAYER_REGEN_DISABLED/ENABLED` events (optionally pause or hide during combat) |
| Debugging | `/fstack`, `/etrace` (Blizzard_DebugTools, Blizzard_EventTrace), `DevTools_Dump` |

**Randomness**: `math.random` is fine for play. Use your own seeded generator (for example xorshift32) if you want shareable seeds and "this deck really had these odds" replays. That answers ForgeTax's biggest complaint, which was players believing the odds were rigged.

## 6. Game events (the event log)

The Forever client documents **1,814 events** in `Blizzard_APIDocumentationGenerated`. You can watch them live in game with `/etrace` (Blizzard_EventTrace).
Everything below was read from that documentation for build 1.60.1.70450. None of it has been tested on a live client.

**Listening:** `frame:RegisterEvent("NAME")` with an `OnEvent` script, `frame:RegisterUnitEvent("NAME", "player")` for unit events, or `EventRegistry:RegisterFrameEventAndCallback("NAME", fn)`.

### Flags on events

| Flag | Count | Meaning for us |
|---|---|---|
| `SynchronousEvent` | 1,690 | Fires immediately while the game state changes. The normal case. |
| `UniqueEvent` | 147 | Our reading: coalesced, so it fires at most once per batch. Example: `BAG_UPDATE_DELAYED` fires once after a burst of `BAG_UPDATE`s. |
| `SecretInChatMessagingLockdown` | 62 | The payload becomes a secret value while chat is locked down (e.g. `CHAT_MSG_SYSTEM`, `GUILD_MOTD`, `READY_CHECK`). |
| `SecretWhenUnitIdentityRestricted`, `SecretWhenUnitSpellCastRestricted`, `SecretWhenAurasRestricted` … | 23 | The payload is secret while that restriction is active (e.g. `PARTY_KILL`, `UNIT_DIED`, `UNIT_AURA`). |
| `SecretPayloads` | 7 | The payload is always secret (e.g. `UNIT_IN_RANGE_UPDATE`). |
| `HasRestrictions` | 7 | Restricted to secure code (combat log events, below). |
| `CallbackEvent` | 12 | Delivered through a callback rather than a plain frame event. |

### Addon restriction states

`C_RestrictedActions` says when the restrictions above are active:

- `C_RestrictedActions.IsAddOnRestrictionActive(type)`, `GetAddOnRestrictionState(type)` and `InCombatLockdown()`.
- `ADDON_RESTRICTION_STATE_CHANGED(type, state)` fires *before* a restriction becomes active and *after* it ends.
- `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN(isTainted, function)` report a blocked call.

`Enum.AddOnRestrictionType`:

| Value | Name | When |
|---|---|---|
| 0 | Combat | The player is actively affecting combat |
| 1 | Encounter | The player is in an instance encounter |
| 2 | ChallengeMode | An active challenge or keystone dungeon |
| 3 | PvPMatch | An active PvP match |
| 4 | Map | A map that applies addon restrictions |
| 5 | Chat | Addon chat communications are restricted |

### The combat log is closed to addons

`COMBAT_LOG_EVENT_UNFILTERED` still exists but is flagged `HasRestrictions`.
`GetCurrentEventInfo` moved to `C_CombatLogSecure`, also restricted. Blizzard's own combat log window (`Blizzard_CombatLogProcessor`) is its only reader.
`C_CombatLog.IsCombatLogRestricted()` reports the state. The old alias `CombatLogGetCurrentEventInfo` points at a function the docs no longer list in `C_CombatLog`.
Plan as if the combat log is unavailable. Forgeborn doesn't need it.

### Events Forgeborn uses

Parameters in brackets are the payload; `?` means it can be nil.

**Addon lifecycle**

| Event | Payload | Use |
|---|---|---|
| `ADDON_LOADED` | addOnName, containsBindings | Saved data is ready; initialise |
| `PLAYER_LOGIN` | | Build the UI |
| `PLAYER_ENTERING_WORLD` | isInitialLogin, isReloadingUi | Seed the "already seen" item GUIDs on first login |
| `PLAYER_LOGOUT`, `ADDONS_UNLOADING` | closingClient | Last chance to tidy saved data |

**Loot (what counts as a drop)**

| Event | Payload | Use |
|---|---|---|
| `LOOT_READY` | autoloot | The loot window's contents are known: read `GetNumLootItems`, `GetLootSlotInfo`, `GetLootSlotLink` (global functions, used by Blizzard's loot frame) |
| `LOOT_OPENED` | autoLoot, isFromItem | `isFromItem` is true when looting a container item (e.g. a lockbox), not a corpse |
| `LOOT_SLOT_CLEARED` | lootSlot | A slot was taken |
| `LOOT_CLOSED` | | Loot window closed |
| `START_LOOT_ROLL` / `LOOT_ROLLS_COMPLETE` | rollID, rollTime, lootHandle? / lootHandle | Group loot rolls |
| `LOOT_ITEM_ROLL_WON` | itemLink, rollQuantity, rollType, roll, upgraded | You won a roll; gives the item link directly |
| `ENCOUNTER_LOOT_RECEIVED` | encounterID, itemID, itemLink, quantity, itemName, fileName | Boss loot that went to someone |
| `SHOW_LOOT_TOAST` | typeIdentifier, itemLink, quantity, … personalLootToast … | The loot toast; a backup signal |
| `ITEM_PUSH` | bagSlot, iconFileID | An item entered a bag |
| `CHAT_MSG_LOOT` | text, playerName, … | "You receive loot" lines. Not flagged as secret, but localised; use only as a fallback |

**Sources that are not drops (to exclude)**

| Event | Payload | Use |
|---|---|---|
| `QUEST_LOOT_RECEIVED` | questID, itemLink, quantity | Quest reward items |
| `QUEST_TURNED_IN` | questID, xpReward, moneyReward | Quest hand-in |
| `MERCHANT_SHOW` / `MERCHANT_CLOSED` | | Items arriving while a vendor is open were bought |
| `MAIL_SHOW` / `MAIL_CLOSED` | | Mailed items |
| `TRADE_SHOW` / `TRADE_CLOSED` | | Traded items |
| `TRADE_SKILL_SHOW` | | Crafted items |
| `AUCTION_HOUSE_SHOW` | | Auction house purchases |

**Bags and items**

| Event | Payload | Use |
|---|---|---|
| `BAG_UPDATE` | bagID | One bag changed |
| `BAG_UPDATE_DELAYED` | | All bag changes settled (unique); scan for new GUIDs here |
| `BAG_NEW_ITEMS_UPDATED` | | The "new item" glow changed |
| `ITEM_COUNT_CHANGED` | itemID | Count of an item changed (unique) |
| `ITEM_CHANGED` | previousHyperlink, newHyperlink | An item's link changed |
| `ITEM_DATA_LOAD_RESULT` / `GET_ITEM_INFO_RECEIVED` | itemID, success | Async item data arrived |
| `PLAYER_EQUIPMENT_CHANGED` | equipmentSlot, hasCurrent | Gear changed |

**Character, world and time**

| Event | Payload | Use |
|---|---|---|
| `PLAYER_LEVEL_UP` | level, … | Orders scale to the new level |
| `PLAYER_REGEN_DISABLED` / `ENABLED` | | Entering / leaving combat |
| `ZONE_CHANGED_NEW_AREA` | | Zone changed |
| `PLAYER_DEAD` | | The player died |
| `HARDCORE_DEATHS` | memberName | A Hardcore death alert |
| `ENCOUNTER_START` / `ENCOUNTER_END` / `BOSS_KILL` | encounterID, encounterName, … | Boss fights |
| `PARTY_KILL` / `UNIT_DIED` | attackerGUID, targetGUID / unitGUID | Kills; payload is secret while unit identity is restricted |
| `TIME_PLAYED_MSG` | totalTimePlayed, timePlayedThisLevel | Answer to `/played` |

There is **no daily or weekly reset event**. For crafting orders, read `C_DateAndTime.GetSecondsUntilDailyReset()` and `GetSecondsUntilWeeklyReset()` on login and set a `C_Timer` for the next reset.

### Loot pipeline (recommended)

1. On `PLAYER_ENTERING_WORLD` with `isInitialLogin`, record every item GUID in the bags as seen.
2. On `LOOT_READY`, store the item links of the loot window's equippable weapon and armour slots as "expected drops". Also add `LOOT_ITEM_ROLL_WON` links.
3. On `BAG_UPDATE_DELAYED`, scan the bags for new GUIDs. A new item whose link matches an expected drop goes to the Workbench.
4. Ignore new items while a merchant, mailbox, trade, auction house or trade-skill window is open, or when `QUEST_LOOT_RECEIVED` names them.

## 7. Lessons from building Forgeborn

Found while building the addon (22 Oct 2026), by reading the Forever UI source:

- **`ShowUIPanel` and `HideUIPanel` refuse addon calls in combat.** Both start with `CheckProtectedFunctionsAllowed()`, which fails when `InCombatLockdown()` is true and the caller is tainted. A window that must work in combat shows and hides itself with `frame:Show()` / `frame:Hide()` while in combat. If a frame isn't in a panel slot, `HideUIPanel` falls back to a plain `frame:Hide()` once combat is over.
- **The close button calls `HideUIPanel`.** `UIPanelCloseButton_OnClick` first calls `parent.onCloseCallback(button)` and only hides the panel if that returns true. Set `frame.onCloseCallback` to close the frame yourself (and return false) so the X works in combat. `ButtonFrameTemplate` has the same close button (from `ButtonFrameBaseTemplate`).
- **Bag-style slots are the intrinsic `ItemButton`** (`CreateFrame("ItemButton", ...)`, 37×37, used by Forever's own equipment flyout). `LargeItemButtonTemplate` and `SmallItemButtonTemplate` are quest-reward rows with a name plate. Set `button.emptyBackgroundAtlas = "bags-item-slot64"` for the empty-slot art the bags use. `SetItemButtonQuality(button, quality)` draws no border for Poor (gray), like real bags.
- **`ColoredProgressBarTemplate` exists only in Forever** (`Blizzard_SharedXML/Camelot/ProgressBars`). Its mixin has `SetFillPercent(0..1)` and `SetText(text)`; Forever's Reputation window colours the fill with `bar.Fill:SetVertexColor(FACTION_BAR_COLORS[standing]:GetRGB())`.
- **`AnimatedShineTemplate` lives in `Blizzard_AnimatedShine`,** a separate Blizzard addon only the socketing UI depends on. An addon that wants a glow can animate its own texture instead (`ButtonHilight-Square`, `ADD` blend, an `Alpha` animation).
- **StaticPopup text goes through `SetFormattedText(dialog.text, text_arg1, text_arg2)`.** With `text = "%s"` and the message passed as `text_arg1`, a `%` inside the message is safe. `OnAccept` receives `(dialog, data, data2)`; returning nothing closes the popup.
- **Settings:** `Settings.RegisterVerticalLayoutCategory(name)`, then `Settings.RegisterProxySetting(category, "VARIABLE", Settings.VarType.Boolean, label, default, getter, setter)` and `Settings.CreateCheckbox(category, setting, tooltip)`, then `Settings.RegisterAddOnCategory(category)`. `Settings.OpenToCategory(category:GetID())` opens it. Proxy settings read the saved table every time, so they keep working after the addon replaces its saved data.
- **Addon compartment:** `AddonCompartmentFunc` is called as `func(addonName, mouseButtonName)`; `AddonCompartmentFuncOnEnter` and `OnLeave` get `(addonName, menuButton)`.
- **Tabs:** `PanelTabButtonTemplate` has `parentArray="Tabs"`. `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab` and `PanelTemplates_TabResize(tab, padding, nil, minWidth, maxWidth)` find tabs through `frame.Tabs[i]` or, without that table, the global `<FrameName>Tab<i>`; naming tabs that way works in both cases. The tab's `OnShow` reads `parent.maxTabWidth`.
- **Loot functions** (`GetNumLootItems`, `GetLootSlotType`, `GetLootSlotLink`, `GetLootSlotInfo`) are not in the generated docs but Forever's loot frame calls them, so they exist.
- **Item GUIDs** (`C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))`) are plain values, not secret, so a bag scan can compare them.
- **`UnitRace` returns secret values** while unit identity is restricted (`SecretWhenUnitIdentityRestricted`, e.g. boss encounters), in Forever as in retail. A secret can't be used as a table key or compared; test with `issecretvalue(value)` first, or read the race at login and keep it. Of every API Forgeborn uses, it is the only one with a secret return.
- **Sounds:** Forever loads the Mainline `SoundKitConstants.lua`. `IG_ABILITY_ICON_PICKUP` doesn't exist; `UI_CURSOR_PICKUP_OBJECT` and `IG_ABILITY_ICON_DROP` do.

## 8. Where to read more

- Generated API docs (643 files) for this exact client: `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua`. In game, use `/api` or `/dump`.
- Widget API: `SimpleFrameScriptObjectAPIDocumentation.lua`, `SimpleScriptRegionAPIDocumentation.lua`, `FrameAPITooltipDocumentation.lua`.
- Community docs: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API, https://warcraft.wiki.gg/wiki/Widget_API, https://warcraft.wiki.gg/wiki/TOC_format
- To refresh the source: `git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source`
