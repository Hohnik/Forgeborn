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

## 6. Where to read more

- Generated API docs (643 files) for this exact client: `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua`. In game, use `/api` or `/dump`.
- Widget API: `SimpleFrameScriptObjectAPIDocumentation.lua`, `SimpleScriptRegionAPIDocumentation.lua`, `FrameAPITooltipDocumentation.lua`.
- Community docs: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API, https://warcraft.wiki.gg/wiki/Widget_API, https://warcraft.wiki.gg/wiki/TOC_format
- To refresh the source: `git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source`
