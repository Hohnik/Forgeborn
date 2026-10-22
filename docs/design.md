# Forgeborn — Design & Implementation Writeup

Oct 22, 2026 · @Niklas

## Summary

Forgeborn is a push-your-luck forging minigame addon for World of Warcraft: Forever. You take a copy of an item you really looted and strike it up the gray → white → green → blue → purple → orange ladder, one hit at a time. Every hit can break it, so you sell before it does.

Status: the rules are at v0.3 after a chat playtest on 22 Oct 2026. No addon code exists yet. Forever launches on 4 Nov 2026 on a client whose UI source we have read (build 1.60.1.70450).

The five pillars:

- **Native look.** One window built only from Blizzard's stock templates: one item slot, a big red Forge button, a Sell button. Forever's own art shows up automatically.
- **Real loot feeds it.** Only items you actually looted can be forged. Your real item, gold and stats are never touched.
- **Fixed odds, real loss.** A break destroys the item. There is no pity protection and no safety net.
- **Slow, long-term progression.** Addon gold is spent in a Shop on lockboxes, one-use items and faction wares. Lockboxes drop rare tools named after Classic blacksmithing items. The tool shelf is fixed at 4 slots.
- **A reason to come back.** One daily and one weekly crafting order from four factions pay extra gold and reputation, and each faction unlocks its own rewards.

## Research background

Forgeborn borrows its core from ForgeTax and its structure from Balatro and Luck be a Landlord. It gets its risk culture from Korean MMO item enhancement.

| Game | What it is | What Forgeborn takes |
| --- | --- | --- |
| [ForgeTax](https://store.steampowered.com/app/5245810/ForgeTax/) (GraveYardDev, Sep 2026, $2.99) | First-person roguelite: strike swords on an anvil from a 1,000-ticket deck (Success, Great, Hold, Damage, Break). Pay a dragon's rising tribute for 21 days. Frenzy = 4 s with no breaks. About 90 relics on an 8-slot shelf. | The strike-and-risk core, visible odds, auto-charged Frenzy, and a relic shelf. |
| ForgeTax reviews (Mixed, 53% of \~1,200) | Praised: the gamble feeling, cheap, nice swords. Criticised: short (1.5–4 h), odds feel rigged, too few relic slots, no meta progression, exponential late game. | Show the odds openly. Build long-term progression. Keep the shelf small anyway (a deliberate choice). |
| [CloverPit](https://en.wikipedia.org/wiki/CloverPit) (Panik Arcade, 2025) | First-person slot-machine roguelite. Pay a growing debt at an ATM or lose. 150+ charms. Over 1M copies sold. | Dark, simple, one-machine presentation. |
| Balatro (2024) | Poker roguelike: score targets per ante, jokers as passive synergies, booster packs. | Passive tools that combine, and packs (here: lockboxes) instead of a direct shop. |
| Luck be a Landlord (2021–23) | Slot-machine deckbuilder with rent due every few spins. A very plain interface. | Proof that a few buttons and a grid of icons are enough. |
| Korean MMO enhancement (Lineage, MapleStory Star Force, Black Desert) | +N upgrades where a failure can destroy the item. | The quality ladder fantasy and the "one more hit?" tension. |

The ForgeTax details come from its [Steam page](https://store.steampowered.com/app/5245810/ForgeTax/) and from Grind'n'Strat's [beginner](https://grindnstrat.com/forgetax-beginner-guide-and-walkthrough-controls-tips/), [relic](https://grindnstrat.com/forgetax-relics-and-swords-guide/) and [achievement](https://grindnstrat.com/?p=8050) guides. Balatro, Luck be a Landlord and the MMO systems are described from general knowledge.

## Design decision log

The design moved from a run-based roguelite with quotas to an open-ended push-your-luck game with a slow economy. Every change below was decided by the designer during the chat playtest.

| Topic | First idea | Decision now | Why |
| --- | --- | --- | --- |
| Screen | Grids of items like Luck be a Landlord | One item slot in the centre plus a red Forge button | Simpler, and it reads like a native bag slot |
| Pressure | A patron (dragon, Ragnaros) demanding tribute | No patron, no work orders | Nothing fancy; the item and the odds are the game |
| Goals | Hit X gold within 10 swings, then level up | Dropped. No swing limit; you swing until you sell or it breaks | Every swing becomes a real decision |
| Failure | No failing at all | A break destroys the item. Nothing is kept | The risk gives each swing its weight; frustration is part of it |
| Odds by quality | One bag for every item | The bag gets harsher with each quality, from the first swing | Better items should be riskier to push |
| Value by quality | Same formula for all | Value starts from item level × quality, so blue and purple finds are worth far more | Rare loot cost more effort in game, so it pays more |
| Frenzy | 5-second break-free window (ForgeTax) | Auto-fires every 7 normal swings and makes the next 3 swings safe | No timing skill and no saving it for later |
| Glut on quality-up | A quality-up refilled the glut | Removed | Keeps Frenzy on a steady, readable rhythm |
| Items | Looted items plus bonus offers | Only items you looted yourself | Ties the minigame to real play |
| Tools | Relics picked on level-up | Real Classic blacksmithing items, bought through lockboxes | Flavour, and slow long-term progression |
| Shelf | Expandable | Fixed at 4 slots (range 4–6 discussed, 4 chosen) | Every tool choice should hurt |
| Currency | A separate token, to avoid confusion with real gold | Shown as gold, silver and copper | Everyone understands it is a game |
| Bad luck | A pity timer | None. Fixed chances, always | Frustration is part of it |
| Seeds | Seeded, shareable runs | Not needed now | Items come from personal loot, so runs can't be identical anyway |
| Difficulty modes | Normal, Heroic, Hardcore | Dropped. Same rules for everyone, Hardcore realms included | The forge is already harsh; modes only mattered for runs with goals |

Decided after this writeup (22 Oct 2026): only real drops count as loot; only weapons and armour can be forged; everything is saved per character; and tools, not softer bags, are what make purple and orange worth forging.

Also decided: embers reset per item; items can be parked back on the Workbench at any time; the Workbench holds 4 items and drops the weakest on a new pickup; orange has no level cap.

Round three: duplicate tools grow one rarity step; displayed trophies give a small passive bonus; no difficulty modes; personal forge records as the long-term goal.

Round four added crafting orders as the reason to keep playing: 1 daily and 1 weekly order from a random one of four factions, asking for a slot and a minimum quality near your level, paid in gold and WoW-style reputation, held on a 3-slot board next to the anvil, never expiring but rejectable for a small reputation loss.

Then: the weekly gets its own slot and asks for several items at the daily quality; the capital city unlocks a 4th daily slot at Honored; the window gives no match hints.

Later the same day: the window shows the next swing as a coloured odds bar; lockboxes are sold in a Shop together with one-use items and faction wares; each order's faction is random instead of rotating.

Then: only two action buttons remain, Forge and Sell. Moving an item to the Display case, the Workbench or an order is drag and drop.

Then: reputation moved into the Shop, one tab per faction, so the footer has only the Shop button.

## Rules v0.3

Each swing draws one token from a 20-token bag set by the item's current quality. From blue upward, at least 3 tokens in 20 break the item.

**Terms** (German names from the playtest in brackets): Hit (Treffer), Great hit (Volltreffer), Miss (Fehlschlag), Crack (Riss), Break (Bruch), Embers (Glut), Frenzy (Raserei), Workbench (Werkbank), Shelf (Regal), Display case (Vitrine), Lockbox (Kassette).

![Game loop](images/game-loop.png)

*game loop · rules v0.3*

The inner loop is one item and one decision per swing. The outer loop turns sold items into tools that change the odds for every later item. Crafting orders add a fourth choice after any swing: hand the item in for extra gold and reputation.

### The anvil

1. Loot an item in game. It appears on the Workbench.
2. Click it to put a forge copy on the anvil. The real item is never changed.
3. Press **Forge**. One token is drawn, with replacement.
4. After any swing you may **Sell** (value → addon gold) or drag the item into the **Display case** (kept as a trophy, no gold).
5. A Break destroys the copy. Nothing is refunded.

### Workbench

- Holds 4 items: new drops and parked half-forged items.
- When a new drop arrives and all 4 slots are taken, the lowest quality item goes. Lowest item level breaks ties. The new drop itself can be the one that goes.
- The item on the anvil can be parked back on the Workbench at any time and keeps its level.

### Strike bag by quality (tokens out of 20)

| Quality | Hit +1 | Great hit +2 | Miss 0 | Crack −1 | Break | Break chance per swing | Levels to next quality | Value factor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Gray | 14 | 3 | 2 | 1 | 0 | 0% | 4 | 1 |
| White | 13 | 3 | 2 | 1 | 1 | 5% | 4 | 1.5 |
| Green | 11 | 2 | 4 | 1 | 2 | 10% | 5 | 2.2 |
| Blue | 8 | 2 | 5 | 2 | 3 | 15% | 6 | 3.2 |
| Purple | 6 | 1 | 6 | 3 | 4 | 20% | 7 | 4.6 |
| Orange | 4 | 1 | 7 | 3 | 5 | 25% | last quality; +N keeps rising | 6.5 |

A Crack never drops the level below the start of the current quality, so an item can't lose a quality.

### Value

```latex
\text{value (silver)} = \text{item level} \times \text{quality factor} \times (1 + 0.1 \times \text{level})
```

Example: blue boots of item level 20 at +16 are worth 20 × 3.2 × 2.6 = 166 silver (1g 66s).

### Embers and Frenzy

- Every normal swing adds 1 ember.
- At 7 embers, Frenzy fires automatically. The next 3 swings can't Miss, Crack or Break; such tokens are redrawn.
- Swings during Frenzy add no embers. A quality-up adds no embers. Embers reset to 0 whenever an item is put on the anvil.

### Tools on the shelf

Tools are passive and change the bag or the value, for example Fiery Core (Feuerkern): Great hits give +3 instead of +2. The shelf holds 4 tools, permanently. Tools come only from lockboxes (see Economy).

## Economy

Sold items give addon gold. Gold buys lockboxes, and lockboxes drop tools at fixed odds with no pity protection. All prices and odds below are first drafts.

- **Addon gold** is shown as gold, silver and copper. It belongs to one character, is not that character's real gold, and can't be traded.
- **The Shop.** Addon gold is spent in a Shop. It sells lockboxes in several tiers (named after Classic rogue lockboxes), one-use items, and faction wares that reputation unlocks. Ordinary tools are never sold directly; they come from lockboxes. Reputation lives in the Shop too: each faction has its own tab with its reputation bar and the wares its ranks unlock.
- **Shelf of 4.** A new tool replaces an old one when the shelf is full. The shelf never grows.

### Lockboxes (draft)

| Lockbox | Price | Contents |
| --- | --- | --- |
| Bronze | 5g | Mostly one-use items; 10% chance of a rare tool |
| Iron | 20g | 30% rare tool, 3% epic tool |
| Thorium | 100g | One rare tool guaranteed; 15% epic, 1% legendary |

At the playtest's value level (1–3 gold per sold item at character level 20), a Bronze box costs 2–5 good sales. Prices need tuning against level-60 values.

### Tool catalogue (draft)

Tools have their own quality colour. Names are real Classic blacksmithing items.

| Tool | Rarity | Effect |
| --- | --- | --- |
| Blacksmith Hammer (Schmiedehammer) | Common | +2 Hit tokens |
| Weak Flux (Schwaches Flussmittel) | Common | −1 Crack token |
| Heavy Sharpening Stone (Schwerer Wetzstein) | Common | Weapons are worth +25% |
| Strong Flux (Starkes Flussmittel) | Rare | −2 Crack tokens |
| Thorium Bar (Thoriumbarren) | Rare | Armour is worth +20% |
| Fiery Core (Feuerkern) | Rare | Great hits give +3 instead of +2 |
| Lava Core (Lavakern) | Rare | +2 Great-hit tokens |
| Dark Iron Bar (Dunkeleisenbarren) | Rare | After a Miss, the next Hit gives +2 |
| Arcanite Bar (Arkanitbarren) | Epic | −1 Break token |
| Blood of the Mountain (Blut des Berges) | Epic | Frenzy lasts 5 swings instead of 3 |
| Elemental Flux (Elementarflussmittel) | Epic | Frenzy fires every 5 swings instead of 7 |
| Righteous Orb (Rechtschaffene Kugel) | Epic | Orange counts ×9 instead of ×6.5 |
| Sulfuron Ingot (Sulfuronbarren) | Legendary | The first Break of each item becomes a Crack |

### One-use items (draft)

- Coarse Sharpening Stone: the next swing is safe.
- Dense Sharpening Stone: the next 3 swings are safe.
- A small purse of addon gold.

### Duplicates, Display case and records

- **Duplicate tool:** the owned tool rises one rarity step and its effect grows, e.g. a rare Fiery Core becomes epic. The exact values per step are still to be tuned.
- **Display case:** putting an item there instead of selling it gives a small passive bonus, e.g. +1% value per displayed orange item. The bonus size and the number of slots are still to be tuned.
- **Forge records:** highest +N reached per quality, most valuable sale, longest run of swings without a break, number of gray items taken to orange.

### Pacing target (proposal)

The designer wants tools to be hard to get, because WoW is played for months. A proposed target: the first rare tool after 2–3 hours of play, the first epic after about 2 weeks, a legendary as a months-long goal. Item supply is capped by real loot, which slows everything down naturally.

## Crafting orders

Crafting orders give every session a goal: one daily and one weekly order arrive from four factions, picked at random, and finishing one pays more gold than selling plus reputation. Decided on 22 Oct 2026; numbers marked as proposals still need tuning.

### How orders work

- **Arrival:** 1 daily order per day and 1 weekly order per week, at WoW's daily and weekly reset. The giving faction is picked at random from the four.
- **The ask:** a slot and a minimum quality, e.g. "Blue boots". The item level must be near the character's level (proposal: within 5 levels), so orders grow with you. The weekly asks for several items at that same quality, e.g. 3 blue armour pieces, handed in one at a time during the week. There are no match hints: you judge yourself which item fits.
- **Board:** 3 daily slots plus 1 weekly slot, shown next to the anvil; the capital city adds a 4th daily slot at Honored. When all daily slots are taken, today's new order waits in a queue. A queued daily that is still waiting at the next daily reset is dropped.
- **No expiry:** an order stays until you finish or reject it.
- **Hand-in:** drag a forged copy from the anvil or the Workbench onto the order's item slot, then click **Send**. The copy is used up instead of sold.
- **Fulfilment:** at least the asked quality counts. Each quality step above the ask pays a bonus (proposal: +50% gold and reputation per step).
- **Rewards (proposal):** daily = 2× the item's sale value and 500 reputation; weekly = 4× each item's sale value and 2,000 reputation once the last item is in.
- **Rejecting:** allowed at any time; costs about a quarter of the reputation finishing would have given.

### Factions and reputation

Ranks work like WoW reputation: Neutral, Friendly, Honored, Revered, Exalted, with the same kind of bar as the reputation window, shown on each faction's tab in the Shop. Each faction asks for its own kind of gear and unlocks a different kind of reward.

| Faction | Asks for | Unlocks (proposal) |
| --- | --- | --- |
| Thorium Brotherhood | Weapons and plate armour | Exclusive tools, one per rank from Honored; Sulfuron Ingot at Exalted |
| Steamwheedle Cartel | Any slot, high-value items | Iron lockbox at Honored, Thorium lockbox at Revered, cheaper lockboxes at Exalted |
| Capital city quartermaster (Stormwind, Ironforge, Orgrimmar or Undercity) | Everyday cloth, leather and mail | A 4th order slot at Honored and one-use items in its shop |
| Argent Dawn | Armour | More Display case slots and stronger trophy bonuses |

Pace check with the proposed numbers: each faction gets about 1,375 reputation a week on average, so Exalted (42,000 from Neutral) takes about 30 weeks. That matches the months-long goal.

## Playtest log and balance findings

Under v0.3, one more swing gains value only on gray and white items; from blue up, selling at once is the better bet. All playtest swings were real random draws from a seeded engine on 22 Oct 2026.

| Rules | Item | What happened | Lesson |
| --- | --- | --- | --- |
| v0.3 (no limit, break) | Tattered boots, blue +15, 1g 60s | Miss, Hit (+16, 1g 66s), then a Break on swing 3. The designer pushed every time and lost it all. | At 15% per swing, surviving 3 swings is only 61%. The loss stings, as intended. |
| v0.2 (goal from item level) | Tattered boots, gray, item level 20 | Gray → blue +15 in 10 swings. Frenzy on swings 8–10 brought two Great hits. Goal 1g 20s, reached 1g 60s. | Gray items climb fast because their bag is kind. |
| v0.2 (simulation) | Same boots, carried into goal 2 | Goal 2 was reached before the first swing. | Goals tied to item level break when an item carries over. Goals were later dropped. |
| v0.1 (fixed gold goals) | Chain shirt of the bear, green | Green → blue +8, 1g 58s. Missed the 2g goal by 42s. | With fixed gold goals, blue items succeeded 90% of the time and gray 2%. That led to quality-based odds. |

![Expected value of one more swing per quality](images/ev-per-swing.png)

*computed from the v0.3 strike bag · item started gray · no tools, Frenzy not counted*

What this means for play:

- Gray and white items are free money: forge them until they turn green.
- Green is break-even. It pays only on the swing just before a quality-up.
- Blue loses about 8% per swing. Purple loses 17% and orange 25%, so pushing them is pure gambling.
- Frenzy swings can't break, so each Frenzy is always worth taking. Tools that cut Break tokens are the only way to make purple and orange worth forging.

Decided: the base curve stays. A strong tool set should be able to bring purple and orange to break-even.

## Interface

The whole game is one small native window: the anvil with only two buttons, Forge and Sell, on the left, and the crafting orders on the right. Everything else is drag and drop. Every part maps to a stock Blizzard template, so Forever's own art is used automatically.

![Forge window mock-up](images/window-mockup.png)

*mock-up · not to scale · values from the playtest*

The odds bar above the item shows every outcome of the next swing (Break, −1, 0, +1, +2) as coloured sections with their percentages, here for a blue item. It changes with the item's quality, with tools, and during Frenzy, when only +1 and +2 remain. The item slot looks like a bag slot with its quality border.

| Element | Native building block | Notes |
| --- | --- | --- |
| Window | `PortraitFrameTemplate`, registered in `UIPanelWindows` with area left | Opens beside the Character frame and closes with Esc, like Forever's own Legacy window |
| Odds bar | 5 textures in one row, widths set from the current bag; percentages in `GameFontHighlightSmall` | Break red, −1 orange, 0 grey, +1 light green, +2 green |
| Anvil slot | `CreateFrame("ItemButton")` / `LargeItemButtonTemplate` + `SetItemButtonQuality` | Real icon, quality border, count hidden; drag source |
| Item name and value | `GameFontNormalLarge` in the quality colour; `GetMoneyString` | Value in gold, silver and copper |
| Forge button | `BigRedThreeSliceButtonTemplate` or `SharedGoldRedButtonTemplate` | The only big button |
| Sell button | `UIPanelButtonTemplate` | The only other action button |
| Embers | 7 small textures | Fill toward the automatic Frenzy |
| Workbench and Shelf | `SmallItemButtonTemplate` rows inside an `InsetFrameTemplate` | Drag between Workbench and anvil; tooltips via `GameTooltip` |
| Display case | A row of `SmallItemButtonTemplate` drop slots | Drag the anvil item here to keep it as a trophy |
| Shop button | `UIPanelButtonTemplate` in the footer | Opens the Shop; the only footer button |
| Shop | A second panel from `ButtonFrameTemplate` with tabs (PanelTabButtonTemplate): a General tab plus one tab per faction | General: lockboxes and one-use items. Each faction tab: its reputation bar (ColoredProgressBarTemplate) and the wares its ranks unlock |
| Lockbox opening | `StaticPopupDialogs` to confirm, then a reveal in the slot | Rare drops use the quality colour |

The orders panel shows 4 order cards, 3 daily and 1 weekly, each with faction, ask, item-level range, reward, an item drop slot, Send and Reject, plus the number of queued orders. Forged copies are not real items, so drag and drop runs on our own item buttons (`RegisterForDrag`, `OnDragStart`, `OnReceiveDrag`) rather than the game cursor.

Entry points and behaviour:

- Minimap addon menu (the addon compartment exists in Forever), `/forge`, and a page in the standard Settings panel.
- Sounds from `SOUNDKIT`, e.g. the artifact-forge rank-up sound on a quality-up and the legendary loot toast on orange. All sounds still need checking in game.
- `AnimatedShineTemplate` on a quality-up. A short red flash and the slot emptying on a Break.
- German and English text from day one. The window stays usable in combat; nothing is locked.

## WoW Forever: technical facts

Forever runs on the modern retail engine and UI framework under the internal codename Camelot, with its own art behind retail's template names. So a retail-style addon built from stock templates looks native in Forever. The facts below come from Blizzard's UI source for build 1.60.1.70450 (16 Oct 2026), mirrored in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), branch `forever`.

| Fact | Value | Where it comes from |
| --- | --- | --- |
| Launch | 4 Nov 2026; level cap 60; 2004 world plus new zones, raids and Hardcore realms | [Blizzard](https://worldofwarcraft.blizzard.com/en-us/forever), [Warcraft Wiki](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever) |
| Game type | `camelot`; `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT = 18` | `Blizzard_ProjectConstants/Camelot/ProjectConstants.lua` |
| Family | `mainline` (retail), not `classic` | TOC load rules: `[Family]` = Mainline, `[Game]` = Camelot |
| Interface number | 16001 on beta/test; check live with `select(4, GetBuildInfo())` | [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) |
| TOC file names | `MyAddon_Forever.toc` or `_Camelot.toc`; `_Mainline.toc` also matches | [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) |
| Native art | Camelot ships its own art under retail atlas names; only offsets are patched | `Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua` |
| Forever-only UI | Character frame, paper doll, skills, reputation, bags, bank, stable, friends, unit frames, minimap, addon compartment, Legacy system | About 200 `[Game]` lines across Blizzard's TOCs |
| Addon restrictions | Retail's "secret values" are present (3,680 functions allowed only when untainted, 92 not allowed) | `Blizzard_APIDocumentationGenerated` |
| API docs | 643 generated documentation files for this exact client | Same folder; `/api` in game |

The secret-value rules protect combat data. A self-contained minigame does not touch it, so they should not matter here.

## Implementation plan

The addon is about six Lua files around a pure-Lua rules engine. The engine can be tested and balanced outside the game, the same way the Python playtest engine was.

![Planned architecture](images/architecture.png)

*planned architecture · no code yet*

Loot enters from bag events, the engine owns all rules, and everything is saved after each swing so a disconnect never loses a forge.

### TOC

```toc
## Interface: 16001
## Title: Forgeborn
## Notes: A push-your-luck forge for the items you loot.
## AllowLoadGameType: camelot
## SavedVariablesPerCharacter: ForgebornCharDB
## IconTexture: Interface\Icons\Trade_BlackSmithing
## AddonCompartmentFunc: Forgeborn_OnCompartmentClick
Locales.lua
Rules.lua
Loot.lua
Economy.lua
Orders.lua
UI.xml
UI.lua
Core.lua
```

### Files

| File | Job |
| --- | --- |
| `Rules.lua` | Bags per quality, draws, value formula, embers and Frenzy, break. No WoW API calls, so it runs in plain Lua. |
| `Loot.lua` | Detects newly looted weapons and armour and puts them on the Workbench. |
| `Economy.lua` | Addon gold, lockbox odds, tools, one-use items, the 4-slot shelf. |
| `Orders.lua` | Daily and weekly arrivals, the 3-slot board and queue, hand-in checks, rewards, reputation and faction unlocks. |
| `UI.xml` / `UI.lua` | The window from stock templates, the orders panel, tooltips, sounds, animations. |
| `Core.lua` | Events, slash command, compartment entry, Settings page, saving. |
| `Locales.lua` | German and English strings. |

### Saved data (draft)

```lua
ForgebornCharDB = {            -- everything is per character
  version = 1,
  gold = 0,                    -- addon gold, in copper
  shelf = { "FIERY_CORE" },    -- up to 4 tool ids
  consumables = { COARSE_STONE = 0 },
  display = {},                -- trophies: itemID, startQuality, level, value, date
  stats = { swings = 0, breaks = 0, sold = 0 },
  seen = {},                   -- item GUIDs already counted as loot
  workbench = {},              -- up to 4: itemID, guid, quality, itemLevel, level
  anvil = nil,                 -- itemID, startQuality, level, embers, frenzy
  orders = { daily = {}, weekly = nil, queue = {}, nextDaily = 0, nextWeekly = 0 },
  rep = { THORIUM = 0, STEAMWHEEDLE = 0, CITY = 0, ARGENT = 0 },
}
```

### Key techniques

- **Loot detection:** on login, record every item GUID already in the bags as seen. On `BAG_UPDATE_DELAYED`, any new GUID of a weapon or armour piece goes to the Workbench. WoW files rings, necklaces and trinkets under armour, so they are filtered out by equip slot (finger, neck, trinket). To count only real drops, also note the item links shown in the loot window (`LOOT_READY`, `GetLootSlotLink`) and accept only matching items. Chat parsing is avoided: it is localised and may be restricted in instances.
- **Item data:** `C_Item.GetItemInfo` gives name, quality, item level and icon. Use `Item:CreateFromItemID(id):ContinueOnItemLoad(...)`, because data arrives asynchronously.
- **Randomness:** `math.random` over the token bag, with replacement. No seeds and no pity protection.
- **Native window:** `PortraitFrameTemplate` plus `UIPanelWindows["ForgebornFrame"] = { area = "left", pushable = 1 }`, opened with `ShowUIPanel`.
- **Saving:** state is written on every swing; WoW writes SavedVariables on logout and reload.

### Build order

1. Window, slash command and compartment entry, with a fake item on the anvil.
2. Rules engine in pure Lua, ported from the playtest engine, with a small simulator.
3. Loot watcher and Workbench.
4. Sell, Display case and addon gold.
5. Lockboxes, tools and the shelf.
6. Polish: sounds, shine, tooltips, Settings page, German and English.
7. Check on the live Forever client from 4 Nov: interface number, art, sounds.

## API reference

Every template and function below exists in the Forever UI source. None has been run on a live Forever client yet.

### Window and controls

| Need | Template or API |
| --- | --- |
| Standard window | `PortraitFrameTemplate` (`SetTitle`, `SetPortraitToAsset`); also `ButtonFrameTemplate`, `DefaultPanelTemplate` |
| Open like a native panel | `UIPanelWindows[name] = { area = "left", pushable = 1 }`, `ShowUIPanel`, `HideUIPanel`; or `tinsert(UISpecialFrames, name)` for Esc only |
| Inner panel, borders | `InsetFrameTemplate`, `ThinGoldEdgeTemplate`, `DialogBorderTemplate` |
| Buttons | `BigRedThreeSliceButtonTemplate`, `SharedGoldRedButtonTemplate`, `UIPanelButtonTemplate`, `SharedButtonTemplate` |
| Item slots | `CreateFrame("ItemButton")`, `SmallItemButtonTemplate`, `LargeItemButtonTemplate`, `GiantItemButtonTemplate`; `SetItemButtonTexture`, `SetItemButtonQuality`, `SetItemButtonDesaturated` |
| Progress bar | `ColoredProgressBarTemplate` (Forever has its own version) |
| Money | `SmallMoneyFrameTemplate`, `GetMoneyString(copper)` |
| Tabs, checkbox, slider, input | `PanelTabButtonTemplate`, `LargeSideTabButtonTemplate`, `UICheckButtonTemplate`, `MinimalSliderWithSteppersTemplate`, `InputBoxTemplate` |
| Menus | `MenuUtil.CreateContextMenu`, `MenuUtil.CreateButtonMenu`, `WowStyle1DropdownTemplate` |
| Confirm dialog | `StaticPopupDialogs`, `StaticPopup_Show` |
| Tooltip | `GameTooltip:SetOwner`, `AddLine`, `AddDoubleLine` |
| Effects | `AnimatedShineTemplate`, `AnimationGroup` |
| Fonts | `GameFontNormal` (gold), `GameFontHighlight` (white), `GameFontNormalLarge`, `NumberFontNormal` |

### Game data and system

| Need | API |
| --- | --- |
| Item info | `C_Item.GetItemInfo`, `GetItemInfoInstant`, `GetItemQualityByID`, `GetItemIconByID`, `GetDetailedItemLevelInfo`, `IsEquippableItem`, `DoesItemExistByID` |
| Async item loading | `Item:CreateFromItemID(id):ContinueOnItemLoad(fn)`; events `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED` |
| Quality colours | `Enum.ItemQuality` (Poor 0 to Legendary 5), `C_Item.GetItemQualityColor`, `ITEM_QUALITY_COLORS` |
| Bags | `C_Container.GetContainerNumSlots`, `GetContainerItemInfo`, `GetContainerItemID`; `C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))` |
| Loot window | `LOOT_READY`, `LOOT_OPENED`, `GetNumLootItems`, `GetLootSlotLink` |
| Timers | `C_Timer.After`, `C_Timer.NewTicker` |
| Sound | `PlaySound(SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_RANKUP)`, `UI_LEGENDARY_LOOT_TOAST`, `UI_EPICLOOT_TOAST`, `UI_BONUS_LOOT_ROLL_START`, `LOOT_WINDOW_COIN_SOUND` |
| Settings page | `Settings.RegisterVerticalLayoutCategory`, `Settings.RegisterAddOnCategory`, `Settings.RegisterCanvasLayoutCategory` |
| Minimap entry | TOC `AddonCompartmentFunc`, or `AddonCompartmentFrame:RegisterAddon{ text, icon, func }` |
| Slash command | `SLASH_FORGEBORN1 = "/forge"`, `SlashCmdList.FORGEBORN` |
| Export strings (later) | `C_EncodingUtil.SerializeCBOR`, `CompressString`, `EncodeBase64` |
| Debugging | `/fstack`, `/etrace`, `/dump`, `/api` |

For crafting orders: `C_DateAndTime.GetSecondsUntilDailyReset` and `GetSecondsUntilWeeklyReset` time the arrivals, and the reputation bars reuse `ColoredProgressBarTemplate`.

Source paths for each entry are in [wow-forever-api-notes.md](wow-forever-api-notes.md).

## Open questions

Two decisions are still open: tuning and release. Fourteen were decided on 22 Oct 2026, including the four that blocked the first build, and the crafting order system was added the same day.

**Decided on 22 Oct 2026**

- [x] Looted means drops only: mobs, chests and won loot rolls. Quest rewards, crafted, bought and mailed items don't count.
- [x] Only weapons and armour qualify. Rings, necklaces and trinkets are excluded.
- [x] Everything is per character: gold, shelf, tools, Display case and Workbench.
- [x] The base bags stay harsh, but a strong tool set should be able to bring purple and orange to break-even.

**Rules**

- [x] Embers reset to 0 whenever an item is put on the anvil, including a parked item that comes back.
- [x] An item can go back from the anvil to the Workbench at any time and keeps its level.
- [x] The Workbench holds 4 items. On a new drop, the lowest quality item is removed (lowest item level breaks ties); that can be the new drop itself.
- [x] No cap at orange: +N keeps rising at 25% break chance per swing.
- [x] No difficulty modes. Same rules for everyone, Hardcore realms included.

**Economy**

- [x] A duplicate tool makes the owned tool one rarity step stronger.
- [x] The Display case holds trophies, and each one gives a small passive bonus.
- [x] Long-term goal: personal forge records.
- [ ] Tuning: lockbox prices and odds against level-60 values, the one-use items, the Display case bonus and its slot count, each tool's stronger rarity steps, and the order rewards and reputation amounts.

**Crafting orders**

- [x] The weekly order has its own slot next to the 3 daily slots.
- [x] The capital city unlocks a 4th daily slot at Honored.
- [x] The weekly asks for several items at the daily quality, e.g. 3 blue armour pieces.
- [x] No match hints in the window.

**Presentation and release**

- [x] Name: Forgeborn.
- [x] No combat restriction: the window and Forge button work in combat.
- [ ] Release: CurseForge reviews every new project. The first file shows "Under Review" until a moderator approves it, asks for changes or rejects it ([CurseForge support](https://support.curseforge.com/en/support/solutions/articles/9000197241-creating-and-submitting-a-project)). Wago publishes through an API key and a `## X-Wago-ID` line in the TOC, usually via the BigWigs packager ([Wago docs](https://docs.wago.io/)). Who tests on the live client from 4 Nov, and when to go public?

## Sources

- [ForgeTax on Steam](https://store.steampowered.com/app/5245810/ForgeTax/): store page, review stats, developer patch notes
- [Grind'n'Strat: ForgeTax beginner guide](https://grindnstrat.com/forgetax-beginner-guide-and-walkthrough-controls-tips/)
- [Grind'n'Strat: ForgeTax relics guide](https://grindnstrat.com/forgetax-relics-and-swords-guide/)
- [Grind'n'Strat: ForgeTax achievements guide](https://grindnstrat.com/?p=8050)
- [CloverPit on Wikipedia](https://en.wikipedia.org/wiki/CloverPit)
- [World of Warcraft: Forever (Blizzard)](https://worldofwarcraft.blizzard.com/en-us/forever)
- [World of Warcraft: Forever (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever)
- [TOC format (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/TOC_format)
- [Gethe/wow-ui-source, branch forever](https://github.com/Gethe/wow-ui-source): Blizzard UI source, build 1.60.1.70450
