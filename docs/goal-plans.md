# Forgeborn: what is the goal?

Oct 23, 2026 · proposal, nothing built yet

**Follow-up:** the designer's idea of a forge fee every few crafts (close to Plan A) is worked out in detail in [run-design.md](run-design.md), which also answers whether Forgeborn becomes a session game.

## The problem

Today the loop is: loot an item, forge it, sell it, buy lockboxes, get tools, forge better. Crafting orders and records sit on the side. Two things are missing:

- **Nothing asks for a result.** Without a target, forging is a solved problem: swing while the next swing gains value on average, sell when it stops (around green under rules v0.4). Every successful push-your-luck game puts a target in front of the player that sometimes makes the risky swing the right one.
- **Nothing to work towards.** Gold buys tools, and tools only make forging better. The loop has no destination, and the forge never connects back to the WoW play that feeds it.

How a target changes play, under rules v0.4: 20,000 simulated "collections" of 4 typical low-level drops (40% gray, 35% white, 20% green, 5% blue), forged by a cautious and a greedy player (`tools/playtest/contract_quota.py`):

| Quota (× the drops' starting value) | Cautious player meets it | Greedy player meets it |
| --- | --- | --- |
| ×1.5 | 65% | 64% |
| ×2 | 40% | 51% |
| ×3 | 9% | 29% |
| ×4 | 1% | 15% |

Low quotas are met whatever you do; high quotas are met only by pushing. A quota that rises over time moves the player from safe play to greedy play, which is exactly the "one more swing?" moment the game is built on.

## What other games do

| Game | Short-term goal | Long-term goal | Failure | What Forgeborn can take |
| --- | --- | --- | --- | --- |
| [ForgeTax](https://www.forgetax.tools/guides/tribute) | Daily tribute: the dragon counts the value of the swords you hand in; the quota climbs from 1,800 G (day 1) to 232,000 G (day 21) | Survive 21 days; then endless days at +20% a day. 19 achievements, 16 of which unlock relics for every later run; forging a sword family to +20 unlocks its legendary masterwork | 3 short tributes end the run | A rising value quota; carry-over items as a safety net; achievements that unlock tools |
| ForgeTax sword forms | – | Every sword family gets a new name every 2 levels, ending in a named +20 form (Excalibur, Yggdrasil) | – | Named forms per grade: a reason to push one item far |
| [CloverPit](https://en.wikipedia.org/wiki/CloverPit) | Pay a growing debt at an ATM within 3 rounds | Unlock charms by meeting conditions | Miss a deadline and you fall into the pit | Short deadlines measured in rounds, not in real time |
| [Luck be a Landlord](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord) | Rent due every few spins, each payment larger | Pay 12 rents to beat the landlord, then climb [20 floors](https://twinfinite.net/guides/how-many-floors-are-in-luck-be-a-landlord/) of harder runs | Can't pay rent | A clear finish line, then a difficulty ladder |
| Balatro | Beat each blind's score; 3 blinds per ante | Beat ante 8; then stakes (difficulty) per deck; a collection of jokers and decks to unlock | Score short of the blind | Escalating targets with a boss rule; stakes as a ladder |
| Korean MMO enhancement (MapleStory, Black Desert) | The next + level | Gear good enough for the next content; status | The item breaks or drops levels | Bragging: server-wide announcements of big successes |
| World of Warcraft itself | Quests, dailies, weeklies | Achievements, collections (mounts, transmog), reputation to Exalted, legendary quest chains | – | Players already chase collections and Exalted; use the same shapes |

ForgeTax's reviews (see `docs/design.md`) praise the gamble and criticise the lack of meta progression; Forgeborn already has slow progression (tools, reputation) but no run goal. Most games above have both: a short goal with pressure and a long goal to collect towards.

## Four plans

### Plan A: Contracts (a goal for today)

The Thorium Brotherhood (or a dragon, as in ForgeTax) offers a contract. It asks for a rising amount of value, collected every few drops. This brings back the patron the playtest dropped, but measures time in **drops, not real days**, so it never forces anyone to log in.

- **How it plays.** A contract has 7 collections. A collection is due every 4 drops. At a collection you hand in forged items from the anvil or the Workbench; their value must reach the quota. Items you don't hand in stay with you (ForgeTax's "keep spares"), so a lucky high item can cover a bad stretch later.
- **The quota** is a multiple of the starting value of the 4 drops since the last collection, so it scales with your level, the zone and retail item levels by itself. Proposal: ×1.25, ×1.5, ×1.75, ×2, ×2.5, ×3, ×3.5. The first collections teach the loop; the last ones need pushing (see the table above).
- **Failure.** Three short collections break the contract: no reward, and the next contract waits a day. Nothing you own is lost.
- **Reward.** A cleared contract pays its quotas back as addon gold (like ForgeTax's tribute) plus a lockbox key and reputation. Clearing it unlocks the next **contract tier** (Balatro's stakes, Luck be a Landlord's floors): higher multipliers, better rewards. Tier 10 is the "Forgeborn" title.
- **What it reuses.** Selling, the Workbench, tools, Frenzy. Crafting orders stay as optional side jobs that pay extra.
- **Effort:** medium (a contract panel, the collection step, saved data, tests). **Risk:** a bad loot stretch (4 grays) can sink a collection; the multiplier on their low starting value keeps that fair.

### Plan B: The Forge Codex (a goal for months)

A collection, like WoW's mounts or transmog and ForgeTax's sword forms and masterworks.

- **How it plays.** The Codex has a page per equipment slot (11 armour slots, one-hand, two-hand, ranged: 14 pages). Each page has marks: forge an item of that slot to green, blue, purple and orange. Forging an item far past orange (+30, +40) earns a **named masterwork form** ("Boots of the Unbroken Anvil"), like ForgeTax's Excalibur at +20.
- **Zones.** Each item remembers the zone it dropped in. A second tab of the Codex is an atlas of Classic zones and dungeons: forge one item from each to blue to master it. Levelling 1 to 60 naturally walks you through the atlas, so the minigame follows the player's real journey.
- **Rewards.** Each completed page or zone row unlocks something (a tool rank, a Display case slot, a title). Completing the Codex is the long goal.
- **What it reuses.** Records, the Display case (masterworks are the trophies), tools as rewards.
- **Effort:** medium. **Risk:** low pressure on its own; it gives direction, not tension.

### Plan C: The Smith's Journey (a guided path)

A chain of chapters, like a WoW legendary quest line (Sulfuras, Thunderfury) or a season journey.

- **How it plays.** Six chapters gated by character level (1, 10, 20, 30, 45, 60). Each chapter has 4 to 6 tasks: "Forge a white item to green", "Sell an item worth 1 gold", "Survive a Frenzy at blue", "Finish a Thorium order". Each chapter pays a reward; the last one is the **Sulfuron Hammer** quest: forge 5 orange items of different slots, then one final forging that can break.
- **What it solves.** It explains the game step by step (the first chapter is the tutorial the addon lacks) and gives a story arc.
- **Effort:** small to medium (a task list and checks against events the addon already has). **Risk:** once finished it's done; it needs Plan A or B behind it.

### Plan D: Guild ladder (a goal among people)

Status, as in Korean MMOs where the whole server sees a +20 success.

- **How it plays.** Addon messages (`C_ChatInfo.SendAddonMessage`) share records with guildmates who run Forgeborn: a weekly ladder of the best sale, the highest +N and contracts cleared. An orange success can be announced in guild chat.
- **Effort:** small to medium. **Risk:** worth little to a player whose guild doesn't use the addon.

## Comparison

| Plan | Why forge today? | Why keep playing for months? | Ties to WoW play | Effort |
| --- | --- | --- | --- | --- |
| A Contracts | Strong: a quota is due in a few drops | Tiers 1–10 | Drops set the pace | Medium |
| B Codex | Weak | Strong: a collection to finish | Strong: slots and zones | Medium |
| C Journey | Medium: next task | Medium: ends at 60 | Medium: level-gated | Small–medium |
| D Ladder | Medium, if guildmates play | Medium | Social | Small–medium |

## Recommendation

Build **Plan A first**, then **Plan B**:

1. **Contracts** answer "why swing now?": the quota is the target that makes greed right at the end of a contract and wrong at its start. Measured in drops, it respects that WoW is the main game. It needs no new currency and reuses everything the addon has.
2. **The Codex** answers "what am I working towards?" with a collection, which WoW players already understand, and it ties forging to where you loot.
3. Use **Plan C's first chapter** as the in-game tutorial when it's time to polish; add **Plan D** when there are players to compare with.

Decisions for the designer:

- Who gives contracts: the Thorium Brotherhood (fits the factions), a dragon (ForgeTax) or Ragnaros (the playtest's first idea)?
- Drops per collection (4?) and the quota curve (×1.25 to ×3.5?). `tools/playtest/contract_quota.py` reruns the numbers for any curve.
- What a broken contract costs: only the reward and a day's wait (proposal), or something you own?
- Do crafting orders stay as they are, or become the contract's collections?

## Sources

- [ForgeTax.tools: tribute and anger](https://www.forgetax.tools/guides/tribute), [how to play](https://www.forgetax.tools/guides/how-to-play), [achievements](https://www.forgetax.tools/achievements), [masterworks](https://www.forgetax.tools/masterworks), [sword forms](https://www.forgetax.tools/swords)
- [CloverPit (Wikipedia)](https://en.wikipedia.org/wiki/CloverPit), [Indie Games Substack on CloverPit](https://indiegames.substack.com/p/hell-in-a-cell-cloverpit)
- [Luck Be a Landlord (Wikipedia)](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord), [Twinfinite: floors](https://twinfinite.net/guides/how-many-floors-are-in-luck-be-a-landlord/)
- Balatro's antes, stakes and unlocks: [Balatro trophy guide](https://platget.com/guides/balatro-trophy-guide), [Steam discussion on stakes](https://steamcommunity.com/app/2379780/discussions/0/4356744017096288611)
