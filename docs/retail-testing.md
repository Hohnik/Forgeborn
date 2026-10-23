# Testing Forgeborn in retail WoW before Forever launches

This branch (`retail-test`) is a test build of Forgeborn for **retail WoW (Midnight, 12.1.5)**. It runs the same
addon code as `main`, the WoW Forever release, so problems found here are problems in the Forever addon.
If you have access to the Forever beta, test `main` there instead: that is the real thing.

## Why retail

Forever runs on the retail engine and UI framework with its own art on top ("Camelot"). Measured against
Blizzard's UI source for each client (`tools/apicheck`), this is how much of Forever's API each live client has:

| Client | API functions | UI templates | Events | Atlases | Sounds |
| --- | --- | --- | --- | --- | --- |
| Retail 12.1.5 | 96.6% | 93.2% | 98.2% | 93.0% | 98.8% |
| Classic Era 1.15.9, Anniversary 2.5.6, Classic 5.5.4 | 60.4% | 56.5% | 79.1% | 29.1% | 42% |

Of everything Forgeborn uses, retail lacks only Forever's own progress bar template (the Shop then uses a
plain status bar) and Forever's game ID, which the addon uses to tell the two clients apart.

## Install

1. On GitHub, switch to branch `retail-test`, then Code → Download ZIP.
2. Unzip it into `World of Warcraft/_retail_/Interface/AddOns/` and rename the folder to `Forgeborn`
   (the path must end in `Interface/AddOns/Forgeborn/Forgeborn.toc`).
3. In game, enable **Forgeborn (retail test)** in the AddOns list.
4. Show Lua errors: type `/console scriptErrors 1`, or install BugGrabber and BugSack.

The saved data of the retail and Forever installs are separate, so testing here never touches Forever.

## What is different in retail (not bugs)

- **The look** is retail's art, not Forever's. Layout and behaviour are the same.
- **The Shop's reputation bar** is a plain status bar; Forever has its own bar template.
- **Item levels** are far higher in retail, so sale values and order rewards are far larger and lockboxes
  feel cheap. Balance can only be judged in Forever.
- **Order item levels** are your average equipped item level ±10 (Forever: your character level ±5).
- **Drops:** retail mobs drop few weapons and armour, and boss loot goes straight to the bags without a
  loot window, so it doesn't count. Use `/forge test drop` to copy items from your bags to the Workbench.
- **Capital city:** races added after Classic (pandaren, allied races, …) get Stormwind or Orgrimmar.
- **Test commands** (`/forge test`) exist only in this build.

## Test commands

| Command | Does |
| --- | --- |
| `/forge test drop [n \| item link]` | Copies weapons or armour from your bags to the Workbench, as if looted |
| `/forge test gold <gold>` | Adds addon gold |
| `/forge test rep <thorium\|steamwheedle\|city\|argent> <amount>` | Adds reputation (Friendly 3000, Honored 9000, Revered 21000, Exalted 42000) |
| `/forge test orders` | A daily and a weekly reset now |
| `/forge test level <n>` | Sets the anvil item to +n |
| `/forge test embers` | Fills the embers to one swing before Frenzy |
| `/forge test tool <TOOL_ID> [rank]` | Gives a tool, e.g. `FIERY_CORE 3` (IDs in `Data.lua`) |
| `/forge test stones [n]` | Adds sharpening stones |
| `/forge test state` | Prints gold, reputation, shelf and orders |

## Checklist

Tick what works; note what doesn't, with a screenshot and the Lua error text.

**Loading**
- [ ] The addon list shows "Forgeborn (retail test)"; logging in gives no Lua error and one chat line.

**Window**
- [ ] `/forge` opens the window beside the Character frame; Esc and the X close it.
- [ ] It opens and closes in combat (attack a training dummy), with no "action blocked" message.
- [ ] The minimap addon menu lists Forgeborn: left-click opens the window, right-click the Shop; hovering shows a tooltip.
- [ ] Settings → AddOns → Forgeborn has two checkboxes; turning sounds off silences the addon.
- [ ] Hovering the portrait shows the forge records.

**Loot**
- [ ] A weapon or armour piece looted from a mob or chest lands on the Workbench with a chat line.
- [ ] Bought, crafted, mailed and quest reward items don't. Rings, necklaces and trinkets don't.
- [ ] With 4 items on the Workbench, a weaker drop is skipped and a better one replaces the weakest.

**Anvil**
- [ ] Clicking a Workbench item puts it on the anvil; the odds bar shows percentages that add up to 100.
- [ ] The odds change after every Hit (Break goes up), a Crack lowers them again; the odds bar's tooltip shows the Break chance after a Hit.
- [ ] The value line shows the value and the value after a Hit; a Hit multiplies the value by 1.2.
- [ ] Forge: a sound, a status line, embers fill; after 7 normal swings Frenzy starts and the odds bar shows no break or miss.
- [ ] A quality-up glows in the new colour; a break flashes red, empties the anvil and writes to chat.
- [ ] Sell adds addon gold, shown in the footer.

**Drag and drop, menus, tooltips**
- [ ] Workbench ↔ anvil, Workbench ↔ Workbench, anvil → Display case, items onto order cards.
- [ ] Display case → anvil and → Workbench (the item comes back with its level); trophy onto trophy reorders; an item dropped on a trophy swaps with it.
- [ ] Order card → another card, → anvil, → Workbench; dragged off into empty space it leaves the card.
- [ ] Sharpening stone → any Workbench item; an item dropped on a stone uses it; a shelf tool dropped on the new tool swaps with it.

**Layout**
- [ ] Move something in `tools/layout-editor/index.html`, Copy Lua, paste over `UI/Layout.lua`, `/reload`: the window matches the editor.
- [ ] Right-click menus on Workbench items, the anvil, tools, trophies and a new tool.
- [ ] Every slot has a tooltip; empty slots explain what they are for.

**Crafting orders**
- [ ] Order cards show faction, ask, item levels and reward; `/forge test orders` brings new ones.
- [ ] Send with a wrong item says what doesn't fit; a fitting item pays gold and reputation.
- [ ] Reject asks first and costs reputation; a weekly counts items sent.
- [ ] `/forge test rep city 9000` opens a 4th daily card.

**Shop**
- [ ] Five tabs; faction tabs show a reputation bar, standing and the wares per rank.
- [ ] Buying a lockbox asks first, then shows what was inside, in the Shop and in chat.
- [ ] With a full shelf (`/forge test tool ...` four times), a new tool waits under the shelf; dragging it onto a slot asks first.
- [ ] Locked wares say what they need; `/forge test rep thorium 9000` unlocks the first Thorium tool.
- [ ] Sharpening stones: buy one, click it; the next swing (3 with the dense stone) shows no break or miss.

**Saved data**
- [ ] `/reload` and logging out keep gold, items, tools, trophies, orders and reputation.
- [ ] `/forge reset` asks first, then starts over.

**Language**
- [ ] On a German client (or with the game language set to German) all texts are German and fit.

## Keeping this branch up to date

All work happens on `main`. This branch adds only `Forgeborn.toc` (retail), `TestTools.lua`,
`tests/test_retail.lua`, the retail fixtures (`tests/fixtures/retail_widgets.lua`,
`tools/apicheck/retail_api.txt.gz`), this file and a note in the README. To bring in new work:

```sh
git checkout retail-test
git merge main          # if Forgeborn.toc conflicts: keep this branch's header, take main's file list, add TestTools.lua
lua5.1 tests/run.lua && luacheck . && python3 tools/apicheck/check_api.py tools/apicheck/retail_api.txt.gz
```

To refresh the retail fixtures after a retail patch:

```sh
git clone --depth 1 --branch live https://github.com/Gethe/wow-ui-source /tmp/ui-live
python3 tools/apicheck/gen_fixture.py /tmp/ui-live/Interface/AddOns /tmp/fixtures
cp /tmp/fixtures/widgets.lua tests/fixtures/retail_widgets.lua
cp /tmp/fixtures/api.txt.gz tools/apicheck/retail_api.txt.gz
```

Then update `## Interface` in `Forgeborn.toc` (12.1.5 is `120105`).
