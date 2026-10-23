# Forgeborn as a run: the forge fee

Oct 23, 2026 · proposal for rules v0.5, nothing built yet

The idea: the forge isn't yours. Its owner charges a **forge fee every 3 crafts**, and the fee rises. Pay it from what you sell, spend the rest on tools and better faces for the anvil, and see how far you get. This document says exactly how that game plays, which build layers other games use and how Forgeborn borrows them, and what it means for the addon.

Everything here comes with numbers from a simulation (`tools/playtest/run_sim.py`) and is meant to be tuned. The full lists of what other games use are in [research/](research/): [ForgeTax](research/catalog-forgetax.md) (98 relics), [Balatro](research/catalog-balatro.md) (150 jokers and all other layers), [CloverPit](research/catalog-cloverpit.md) (171 charms), [Luck be a Landlord](research/catalog-landlord.md) (152 symbols, 114 items, 113 essences) and [Slay the Spire](research/catalog-slay-the-spire.md) (179 relics).

## Is it a session game now?

Yes. With a rising fee, Forgeborn becomes a **run**: it starts, it gets harder, and it ends when you can't pay or when you beat the last shift. That is what ForgeTax, Balatro, CloverPit and Luck be a Landlord are. A run takes about 20 to 30 minutes (8 shifts of 3 items) and is saved after every strike, so it can be split over flight paths, queues and evenings.

It stays a **WoW Forever addon**, and a thin layer still lasts forever:

| | Today (1.1) | As a run game |
| --- | --- | --- |
| Session | Open-ended, no end | A run of 8 shifts, then endless if you like |
| Items | Only real loot | 3 delivered per shift; real loot arrives as premium **commissions** |
| Gold | Kept forever, buys lockboxes | Run gold: earned, spent on fees and the shop, gone at the end |
| Tools | Kept forever, 4 slots | Bought during the run, 5 slots, gone at the end |
| What lasts | Gold, tools, reputation, records | Unlocks (tools, faces, starting forges), records, the codex, a hall of fame |
| Goal | None | Pay the fee; clear shift 8; climb the difficulty ladder |
| Losing | Only an item | The run |

The reasoning: a fee only creates pressure if it can end something. If gold and tools were kept forever, a missed fee would be a nuisance, not a stake. Every game in the research keeps the build inside the run and lets only unlocks persist.

## A run at a glance

```
Run start: pick a starting forge (deck) -> shift 1
  Shift: 3 items arrive on the rack (plus commissions from real loot)
    Forge: put an item on the anvil, strike, sell it or push on   } 3 crafts
    A craft ends when the item is sold, breaks or is handed in   }
  Fee due: Lokhtos collects. Short? you pay what you have and he holds a grudge (3 grudges end the run)
  Shop: tools, faces, consumables, extra items, reroll
  Shifts 3 and 6: an inspection with a special rule. Shift 8: Ragnaros.
Win: shift 8 paid -> unlocks, then endless shifts (fee x1.8 each)
```

## The rules, exactly

### Shifts and the forge fee

- A run has **8 shifts**. A shift is **3 crafts**. A craft ends when an item leaves the anvil sold, broken or handed in to a commission. Parking an item on the rack doesn't count, so you can carry a promising item into a later shift.
- At the end of each shift the fee is due. **Proposed fee** (gold; a gray item at +0 is worth 1g):

| Shift | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | Endless |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Fee | 4g | 6g | 9g | 14g | 24g | 42g | 75g | 135g | ×1.8 a shift |

  The curve is flat early (learn the anvil) and steep late (you need a build), like Balatro's antes (300, 800, 2,000 … 50,000) and Luck be a Landlord's rent (25, 50, 100 … 1,000).
- **Short of the fee:** you pay everything you have and Lokhtos holds a **grudge**. The third grudge ends the run (ForgeTax ends a run on the third short tribute). Higher difficulties allow fewer grudges.
- **Who collects:** Lokhtos Darkbargainer, the Thorium Brotherhood's quartermaster in Blackrock Depths, rents you the Black Anvil. Shift 8 is paid to Ragnaros.

**Why every 3 crafts and not every N strikes.** Counting crafts matches "one item, one decision per swing": each item can be pushed as far as you dare, and the fee tells you how far you need to. ForgeTax counts days of 3 swords the same way. Counting strikes (Luck be a Landlord counts spins) would add a second budget; it's a good **inspection rule** for one shift ("this shift: 18 strikes"), but too fiddly as the base rule.

### Items

- **Deliveries:** 3 items arrive on the rack (5 slots) at the start of each shift. Their quality improves over the run:

| Shift | Gray | White | Green | Blue | Purple |
| --- | --- | --- | --- | --- | --- |
| 1 | 50% | 35% | 15% | | |
| 2 | 40% | 38% | 20% | 2% | |
| 3 | 30% | 40% | 25% | 5% | |
| 4 | 20% | 40% | 30% | 10% | |
| 5 | 10% | 40% | 35% | 13% | 2% |
| 6 | 5% | 35% | 38% | 18% | 4% |
| 7 | | 30% | 42% | 22% | 6% |
| 8 | | 25% | 42% | 25% | 8% |

- **Value:** 1g × the quality factor (gray 1, white 1.5, green 2.2, blue 3.2, purple 4.6, orange 6.5) × 1.2 per level, as in rules v0.4. Delivered items use real Classic item names and icons from a list in `Data.lua`.
- **Commissions (real loot):** every weapon or armour piece you loot in WoW is saved as a commission (up to 5 waiting). At the start of each shift one commission can join the delivery as a 4th item, keeping its real name, icon, quality and suffix. Playing WoW makes your next run better without being required.
- **Suffixes:** green and better items can carry a Classic random suffix that changes how they forge, like Balatro's card editions and CloverPit's symbol modifiers. A real looted "of the Eagle" item brings its suffix along.

| Suffix | While this item is on the anvil |
| --- | --- |
| of the Bear | +2 Hit faces |
| of the Eagle | Each Hit: value +5% |
| of the Tiger | Great hits give +1 more level |
| of the Monkey | Every strike adds 2 embers |
| of the Owl | Each Miss: value +8% |
| of the Boar | Cracks don't lower the level |
| of the Falcon | Its first 2 strikes can't break |
| of the Wolf | +1 level each time Frenzy ends |
| of the Gorilla | Worth ×1.5, Break chance +3 points |
| of Power | Worth ×1.3 |

### The anvil: faces, odds and the Break curve

The anvil has **faces**, like a die (Dice Forge forges new faces onto dice; Balatro's tarots enhance cards in the deck; Luck be a Landlord adds symbols to the reel). Every strike draws one face.

- **Start:** 20 faces: 2 Crack (−1), 4 Miss (0), 12 Hit (+1), 2 Great hit (+2).
- **Break** stays outside the faces. Its chance comes from the item's grade (rules v0.4 curve: 0% at gray +0, 12% green, 20% blue, 30% purple, 40% orange, up to 70%). The faces decide what happens when it doesn't break. **Change from v0.4:** adding faces no longer lowers the Break chance (in v0.4 every token tool did, as in ForgeTax). In a run you can add many faces, and that dilution would make Break disappear. Only tools and consumables touch Break, and they say so.
- **Face services in the shop:** **Add** a face (choose 1 of 3, e.g. a Great or an inscribed Hit), **Remove** a face (Slay the Spire's card removal; price rises each time), **Inscribe** a face (Balatro's tarots).
- **Inscriptions** (one per face):

| Inscription | When this face is drawn | Like |
| --- | --- | --- |
| Gilded | Item value +10% | Balatro Gold card, CloverPit Golden modifier |
| Ember | +1 extra ember | CloverPit Battery modifier |
| Lucky | 1 in 4: a Hit counts as a Great, a Miss as a Hit | Balatro Lucky card |
| Obsidian | Counts double (Hit +2, Great +4); 1 in 4 it shatters and leaves the anvil | Balatro Glass card |
| Echo | Tools that react to this result react twice | Balatro Red seal, CloverPit Repetition |
| Runed | Pays 50s | Balatro Gold seal, CloverPit Ticket modifier |
| Cursed | Counts as a Miss and adds 2 Break points for this item (only from inspections and drawbacks) | Balatro debuffs, CloverPit's 666 |

- **Frenzy** stays as now: 7 normal strikes on the same item fire it, and the next 3 strikes can't Miss, Crack or Break. Embers belong to the item, so you can't charge Frenzy on a cheap item and spend it on a precious one (ForgeTax ties charge to the sword for the same reason).

### Tools (the shelf)

5 slots. The shop offers 3 tools per visit (rarity odds 70% common, 25% rare, 5% epic, as Balatro's 70/25/5); legendary tools come only from Ragnaros, an inspection reward or a Darkmoon card. A tool sells back for half its price. **Duplicates rank up** (Common → Rare → Epic → Legendary), Forgeborn's own twist that already exists in 1.x; CloverPit's surgery combines charms in a similar way.

Proposed tool list, by the build it supports. Names are Classic items; the 15 tools of 1.x are marked ★. "From" names the effect in another game that inspired it.

| Build | Tool | Rarity | Effect | From |
| --- | --- | --- | --- | --- |
| Odds | ★ Blacksmith Hammer | Common | +3 Hit faces | ForgeTax Bent Nail |
| Odds | ★ Lava Core | Rare | +2 Great faces | ForgeTax Golden Nail |
| Odds | ★ Weak Flux | Common | Turn 1 Crack face into a Hit | ForgeTax Blunt Mallet |
| Odds | ★ Enchanted Thorium Bar | Rare | Turn 2 Miss faces into Hits | ForgeTax Worn Whetstone |
| Great | ★ Fiery Core | Rare | Great hits give +3 | ForgeTax Silver Tuning Fork |
| Great | Golden Pearl | Rare | Each Great: item value +15% | ForgeTax Cracked Bell |
| Great | Star Ruby | Epic | After a Great, the next strike draws Greats twice as often | ForgeTax Blind Die |
| Great | Heart of Fire | Legendary | Greats during Frenzy give +4 | ForgeTax Glass Hourglass |
| Hits and streaks | Truesilver Bar | Common | Each Hit: item value +4% | ForgeTax Inspection Stamp |
| Hits and streaks | Mithril Casing | Rare | 2 Hits in a row: +1 extra level | ForgeTax Third Hand |
| Hits and streaks | Gyromatic Micro-Adjustor | Rare | Each Hit adds a Hit face to this item for its life | ForgeTax Bronze Cog |
| Hits and streaks | Thorium Widget | Common | 3 different results in a row: +1 level | ForgeTax Soot Censer, CloverPit patterns |
| Patience (Miss) | ★ Dark Iron Bar | Rare | After a Miss, the next Hit gives +2 | ForgeTax Little Wind Bell |
| Patience (Miss) | Solid Weightstone | Common | Each Miss: item value +6% | ForgeTax Cold Teacup |
| Patience (Miss) | Black Pearl | Rare | Each Miss: 50% chance of +1 ember | ForgeTax Chained Hourglass |
| Patience (Miss) | Iridescent Pearl | Epic | 2 Misses in a row: +1 level | ForgeTax Sealing Stone |
| Scars (Crack) | ★ Strong Flux | Common | Cracks keep half the value they take | ForgeTax Cracked Crown |
| Scars (Crack) | Elemental Earth | Rare | Each Crack lowers this item's Break chance by 15% (up to 60%) | ForgeTax Cracked Splice |
| Scars (Crack) | Heavy Grinding Stone | Rare | Each Crack: 70% chance of +1 level instead | ForgeTax Unbroken Oath |
| Scars (Crack) | Dark Iron Residue | Common | After a Crack, the next Hit gives +2 | ForgeTax Interlocking Weights |
| Breaker | Essence of Undeath | Common | When an item breaks, gain 1g per grade it had | ForgeTax Ash Sieve |
| Breaker | Guardian Stone | Rare | When an item breaks, the next item starts with 30% of its levels | ForgeTax Broken Holy Sword |
| Breaker | Living Essence | Epic | When an item breaks, add a Great face for the rest of the run | ForgeTax Ossuary King's Scabbard, Balatro Glass Joker |
| Breaker | Skull of Impending Doom | Epic | Break chance +3 points; breaks pay 60% of the item's best value | ForgeTax Undertaker's Chalice, Butterfingers |
| Protection | ★ Arcanite Bar | Epic | Break chance −20% | ForgeTax Black Knot, Dragonscale Tongs |
| Protection | ★ Sulfuron Ingot | Legendary | The first Break of each item becomes a Crack | ForgeTax Unyielding Cornerstone |
| Protection | Ankh | Rare | Once per run, a short fee costs no grudge (then it's used up) | CloverPit Ankh, Slay the Spire Lizard Tail |
| Frenzy | ★ Blood of the Mountain | Epic | Frenzy lasts 5 strikes | ForgeTax Red Hourglass |
| Frenzy | ★ Elemental Flux | Epic | Frenzy fires every 5 strikes | ForgeTax Cracked Wristwatch |
| Frenzy | Essence of Fire | Rare | An item's first strike adds 3 embers | ForgeTax Ember Locket |
| Frenzy | Elemental Fire | Rare | Each Frenzy strike: item value +5% | ForgeTax Bell Collar |
| Frenzy | Hourglass Sand | Rare | When Frenzy ends: +1 level | ForgeTax Headless Bell |
| Value | ★ Heavy Sharpening Stone | Common | Weapons +30% | Balatro suit jokers |
| Value | ★ Thorium Bar | Common | Armour +30% | Balatro suit jokers |
| Value | ★ Elemental Sharpening Stone | Rare | Purple and orange +35% | ForgeTax Black Iron Stone |
| Value | ★ Righteous Orb | Epic | Orange ×1.5 | ForgeTax Dragon Signet |
| Value | Runed Arcanite Rod | Rare | Items with a suffix +40% | Balatro edition jokers |
| Economy | Gold Bar | Common | At shift end, +1g per 5g you hold (up to 5g) | Balatro interest, CloverPit Stonks |
| Economy | Thorium Brotherhood Contract | Rare | Fees −10% | ForgeTax Sealed Rebate |
| Economy | Philosopher's Stone | Epic | Each Hit: item base value +1s that grows with every later level | ForgeTax Golden Cog |
| Scaling | Hammer of the Titans | Epic | +5% value for every item sold at blue or better this run | Balatro Ride the Bus, Constellation |
| Rule-bender | Ironfoe | Legendary | Every 2nd Great counts twice | Balatro Hack, CloverPit Hamsa |
| Rule-bender | Mirror of Truth | Legendary | Copies the tool to its right | Balatro Blueprint |
| Rule-bender | Thunderfury | Legendary | Each Hit: 25% chance of a free extra Hit | ForgeTax Echo Hammer |
| Rule-bender | Sulfuras, Hand of Ragnaros | Legendary | Crack faces count as Hits | ForgeTax Sickle and Hammer (rule change) |

### Consumables

2 slots; bought in the shop or found as rewards. Sharpening stones and potions are the small ones; **Darkmoon Cards** are the rare, strong ones, as Balatro's tarots and spectrals (the Darkmoon Faire is WoW's own carnival of cards and tickets).

| Consumable | Effect | From |
| --- | --- | --- |
| Coarse Sharpening Stone | The next strike can't Miss, Crack or Break | Forgeborn 1.x |
| Dense Sharpening Stone | The next 3 strikes can't Miss, Crack or Break | Forgeborn 1.x |
| Heavy Weightstone | This item's current level becomes its floor (Cracks can't go below it) | new |
| Elixir of the Mongoose | +3 embers | ForgeTax Cold Star Shard |
| Nightfin Soup | The next strike draws Greats twice as often | ForgeTax Red Chalk |
| Flask of Petrification | Undo the last strike, even a Break | ForgeTax Regret Clockwork |
| Goblin Sapper Charge | Next strike: Hits and Greats become Greats, everything else breaks | ForgeTax Powder Pouch |
| Darkmoon Card: Heroism | Inscribe 2 faces Gilded | Balatro The Devil |
| Darkmoon Card: Maelstrom | Turn 2 Miss faces into Lucky Hits | Balatro The Magician |
| Darkmoon Card: Blue Dragon | Copy a face | Balatro Death |
| Darkmoon Card: Twisting Nether | The next Break doesn't happen | ForgeTax Cracked Dragon Scale |
| Ace of Portals (a Darkmoon card) | Remove up to 2 faces | Balatro The Hanged Man |

### The shop between shifts

After the fee: 3 tools, 2 consumables, 1 face service (add, remove or inscribe) and 1 extra item for sale. A reroll costs 1g, +1g each time in the same shop. Prices rise 15% a shift. Proposed base prices: common tool 3g, rare 5g, epic 8g; consumable 2g; add a face 2g, remove 2g (+1g each time), inscribe 3g; extra item at its value. (The simulation's prices were set to these levels.)

### Inspections and Ragnaros

Shifts 3 and 6 bring an **inspection**: one random rule for that shift, like Balatro's boss blinds and Luck be a Landlord's fine print. Clearing it pays a reward (a free rare tool or consumable).

| Inspection | Rule for this shift |
| --- | --- |
| The Assayer | Only weapons count toward the fee |
| Dark Iron Ore | Great faces count as Hits |
| Cold Forge | No Frenzy |
| Brittle Ore | Break chance +5 points |
| Smoke | The odds bar is hidden |
| The Taxman | Fee +50%, one extra item delivered |
| Rust | Cracks cost 2 levels |
| Short Shift | 18 strikes for the whole shift |
| Cursed Ore | 2 random faces are Cursed until the shift ends |

**Shift 8, Ragnaros:** the fee is paid to the Firelord; every strike this shift adds 1 Break point for the rest of the shift. Clearing it wins the run, unlocks the next difficulty, and may drop a legendary tool for the next run's pool.

### Winning, losing and endless

- **Win:** pay shift 8. **Lose:** the third grudge.
- **Endless:** after a win you can keep going; the fee grows ×1.8 a shift (Balatro and ForgeTax both have endless modes).
- **Score** for the records: shifts cleared, total gold earned, the most valuable item.

### What lasts between runs

- **Unlocks:** new tools, inscriptions and suffixes enter the pool through achievements, as ForgeTax unlocks 16 relics through achievements and Balatro unlocks jokers and decks. Examples: "Sell an orange item" unlocks Righteous Orb; "Break 10 items in one run" unlocks Skull of Impending Doom; "Clear an inspection without Frenzy" unlocks Hourglass Sand.
- **Starting forges** (Balatro's decks, CloverPit's memory cards, Slay the Spire's characters). Some unlock through real WoW progress, read from the client (`C_Reputation`, achievements):

| Forge | Start | Unlock |
| --- | --- | --- |
| Village Smithy | Standard | Always |
| The Great Forge (Ironforge) / The Drag (Orgrimmar) | +1 tool slot, fees +10% | Clear shift 4 |
| The Black Anvil | Starts with Dark Iron Bar; Frenzy every 10 strikes | Thorium Brotherhood Friendly in WoW |
| Gnomeregan Workshop | +1 consumable slot, starts with 2 consumables | Win a run |
| Light's Hope Forge | The first Break each shift becomes a Crack; items −20% value | Argent Dawn Honored in WoW |
| Booty Bay Smithy | Gold Bar interest doubled; shop prices +25% | Earn 500g in one run |
| Molten Core | Items arrive 4 grades higher; fees ×1.5 | Defeat Ragnaros |

- **Difficulty ladder** (Balatro's stakes, Luck be a Landlord's floors, CloverPit's hard mode): **Anvil ranks 1 to 8**, each adding to the ones before: fees +10%; one grudge fewer; inspections also on shift 4; items one quality lower; shop rerolls cost double; Ragnaros adds 2 points a strike; only one grudge; Cursed face at the start.
- **Records, codex and hall of fame:** the best run per forge and rank, and the best item of each run kept as a trophy (the Display case becomes the hall of fame).

## Build archetypes

Build diversity comes from different ways to beat the same fee. Each of these needs 2 or 3 tools that work together; the simulation shows why combinations matter (below).

| Build | Plan | Core pieces |
| --- | --- | --- |
| Great | Fill the anvil with Great faces and make each Great worth more | Lava Core, Fiery Core, Golden Pearl, Star Ruby, of the Tiger |
| Streak | Many Hits, rewarded in a row | Blacksmith Hammer, Mithril Casing, Gyromatic Micro-Adjustor, of the Bear |
| Patience | Misses are good: they charge value, embers and the next Hit | Dark Iron Bar, Solid Weightstone, Black Pearl, of the Owl |
| Scars | Cracks protect and level | Elemental Earth, Heavy Grinding Stone, Strong Flux, of the Boar |
| Breaker | Push everything; breaks pay | Essence of Undeath, Guardian Stone, Living Essence, Skull of Impending Doom |
| Frenzy | Short, safe bursts as often as possible | Elemental Flux, Blood of the Mountain, Essence of Fire, of the Monkey |
| Collector | High-quality items and suffixes | Elemental Sharpening Stone, Righteous Orb, Runed Arcanite Rod, commissions |
| Banker | Hold gold, pay less, buy more | Gold Bar, Thorium Brotherhood Contract, Philosopher's Stone |

## How other games create build diversity

Every game in the research stacks the same few layers. Forgeborn needs most of them, kept small.

| Layer | ForgeTax | Balatro | CloverPit | Luck be a Landlord | Slay the Spire | Forgeborn (proposal) |
| --- | --- | --- | --- | --- | --- | --- |
| Passive build pieces | 98 relics, 8 slots | 150 jokers, 5 slots | 171 charms, 7 slots | 114 items | 179 relics, no limit | ~45 tools, 5 slots |
| The thing that rolls | 1,000-ticket deck (5 outcomes) | 52-card deck | 7 symbols × 11 patterns | Your symbol inventory (152 kinds) | Your card deck | 20 anvil faces + the Break curve |
| Changing what rolls | Ticket relics | Tarots, deck editing, card removal | Charms that shift symbol odds | Add 1 of 3 symbols each spin, removal tokens | Card rewards, removal | Add, remove, inscribe faces |
| Modifiers on pieces | Special swords (World Tree, Fishblade) | 8 enhancements, 4 seals, 5 editions | 8 symbol modifiers, 7 charm traits | Symbol transformations | Card upgrades | 7 inscriptions, 10 suffixes |
| One-use items | 7 merchant items | 22 tarots, 18 spectrals, 12 planets | Red Button charges, phone calls | 113 essences | Potions | 12 consumables |
| Start choice | Starter gift (1 of 3) | 15 decks | 20 memory cards | – | 4 characters | 7 starting forges |
| Escalating target | Daily tribute ×129 over 21 days | Antes ×167 over 8 | Debt ×2,667 over 8 deadlines | Rent ×40 over 13 | Floors and bosses | Fee ×34 over 8 shifts |
| Rule twists | Dragon anger | 28 boss blinds | Red phone calls, 666 | Landlord's fine print | Bosses, elites, events | Inspections, Ragnaros |
| Difficulty ladder | Extended days | 8 stakes | Hard mode | 20 floors | 20 ascensions | 8 anvil ranks |
| Meta unlocks | 19 achievements → relics | Unlock conditions | Charm unlock conditions | Floors | Characters, cards | Achievements, WoW reputation |

Across the ~1,000 effects, the same kinds of effect recur. Each kind, with an example from each game where one exists:

| Kind of effect | ForgeTax | Balatro | CloverPit | Luck be a Landlord | Slay the Spire |
| --- | --- | --- | --- | --- | --- |
| Shift the odds | Bent Nail: +4 Success tickets | Oops! All 6s: probabilities ×2 | Scratch and Hope: likeliest symbol more often | Removal tokens, adding symbols | Card removal |
| Flat bonus per event | Inspection Stamp: +100 G per Success | Joker: +4 Mult | Symbol value raises | A symbol's coins | Akabeko: first attack +8 |
| Multiplier | Iron Signet: value +15% | 35 xMult jokers | Symbols/Patterns Multiplier | "gives 2x more" items (Black Cat) | Pen Nib: every 10th attack ×2 |
| Grows over the run | Bronze Cog: each Success adds a Success ticket | Ride the Bus, Hiker | Pentacle, Tarot Deck | Amethyst: permanently +1 | Counter relics (Nunchaku) |
| Sequences and patterns | Third Hand: 2 in a row +1 | Poker-hand jokers | 11 patterns, Lucky Cat | Adjacency (49 symbols) | Kunai, Shuriken |
| Retrigger and copy | Split Twin Mirror | Blueprint, Red seal | Hamsa, Repetition modifier | – | Necronomicon |
| Protection | Unyielding Cornerstone | Mr. Bones | Ankh, Holy Bible | Coffee: one more spin if you can't pay | Lizard Tail |
| Gain from failure | Ash Sieve: 500 G on a break | Glass Joker | Consolation Prize, Steam Locomotive | Black Pepper: coins when a symbol is destroyed | Centennial Puzzle |
| Economy | Sealed Rebate: tribute −10% | 18 economy jokers, interest | Interest charms, Fidelity Card | Coin items | Membership Card |
| More actions | Supply Permit, Frenzy relics | Grabber: +1 hand | Cat Food: +2 spins | Instant Ramen | Energy relics |
| Trade-offs | Butterfingers: +3 Break, +5 Great | Stuntman, stickers | Evil Deal, Corpse pieces (+5% debt) | Devil's Deal: 6 Duds instead of rent | Boss relics |

## The simulation

`python3 tools/playtest/run_sim.py` plays the run above: deliveries by shift, a player who pushes each item until it meets its share of the fee and stops when one more swing loses value, the fee, grudges, and a bot that buys 4 random shop offers.

Income of one shift without upgrades stays at about 9g (median), because the player sells around green. That is why the fee can't rise without a build. Single upgrades add 10–80% to a shift's income; a combined build multiplies it:

| Build (shift 5 deliveries) | Median income |
| --- | --- |
| Plain anvil | 8.5g |
| +6 Hit faces | 9.2g |
| +3 Great faces | 9.6g |
| No Crack and no Miss faces | 11.1g |
| Value +60% | 13.6g |
| Value ×1.5 | 12.7g |
| Great hits give +4 | 11.1g |
| Break chance −40% | 13.9g |
| Frenzy every 4 strikes | 9.6g |
| All of: +6 Hit, +3 Great, Great +4, Break −40%, Frenzy every 4 | 69.0g |

With the fee curve above: a player who never buys anything wins **2%** of runs and usually lasts to shift 6; a bot that buys random upgrades wins **35%**. A player who builds on purpose should win more, which is about where Balatro's first difficulty sits. The numbers are a starting point for tuning, not a promise.

## What changes in the addon

| Part | Change |
| --- | --- |
| Rules | v0.4 odds stay; faces replace the fixed deck; Break no longer diluted by faces |
| Saved data | A run state (shift, crafts, fee, gold, grudges, faces, shelf, rack, consumables) next to the meta state (unlocks, records, commissions, hall of fame) |
| Window | Header: shift, crafts 1/3, fee, gold, grudges. The rack (5), the shelf (5), consumables (2), a face strip under the odds bar. Between shifts the right side shows the shop instead of orders. The layout editor covers it. |
| Loot | Looted items become commissions instead of Workbench items |
| Shop | Becomes the between-shift shop; lockboxes leave (or become a rare "crate" offer) |
| Factions and orders | Leave as daily chores; the factions return as starting forges and inspections; a commission can carry a small side order ("sell this at blue") |

A build order that keeps something playable at every step:

1. **The loop:** shifts, deliveries, 3 crafts, the fee, grudges, a shop with the existing 15 tools. Playable and testable on its own.
2. **Faces:** the face strip, add, remove, inscribe.
3. **Variety:** suffixes, consumables, inspections, Ragnaros, the new tools.
4. **Meta:** unlocks, starting forges, anvil ranks, commissions from loot, the hall of fame.

## Decisions for the designer

1. **Session game:** go run-based as described, with gold and tools inside the run? (Recommended. The alternative, a fee on top of today's forever economy, has no real stake.)
2. **The clock:** every 3 crafts (recommended), or every N strikes?
3. **Missing a fee:** 3 grudges (recommended, like ForgeTax), or the run ends at once (Balatro, CloverPit, Luck be a Landlord)?
4. **Break and faces:** keep Break outside the faces (recommended), or keep v0.4's ForgeTax rule where every added face lowers Break?
5. **Who collects:** Lokhtos and the Black Anvil, then Ragnaros? Or a dragon, as in ForgeTax?
6. **Real loot:** commissions as the premium 4th item (recommended), or real loot only?
7. **Factions and daily orders:** fold them into starting forges and inspections, or keep them as a side mode?

## Sources

- Catalogs and their sources: [ForgeTax](research/catalog-forgetax.md) ([ForgeTax.tools](https://www.forgetax.tools/relics)), [Balatro](research/catalog-balatro.md) ([Balatro Wiki](https://balatrowiki.org/w/Jokers)), [CloverPit](research/catalog-cloverpit.md) ([CloverPit Wiki](https://cloverpit.wiki.gg/wiki/Lucky_Charms), [ATM and debt](https://cloverpit.wiki.gg/wiki/ATM)), [Luck be a Landlord](research/catalog-landlord.md) ([Luck be a Landlord Wiki](https://luck-be-a-landlord.fandom.com/wiki/Symbols)), [Slay the Spire](research/catalog-slay-the-spire.md) ([Slay the Spire Wiki](https://slay-the-spire.fandom.com/wiki/Relics)).
- ForgeTax tribute, merchant and odds: [ForgeTax.tools guides](https://www.forgetax.tools/guides/tribute), [merchant](https://www.forgetax.tools/merchant).
- Dice faces: Dice Forge (Libellud, 2017) forges new faces onto dice ([rules summary](https://gamerules.com/rules/dice-forge/), [review](https://opinionatedgamers.com/2017/08/11/dale-yu-review-of-dice-forge/)); [Die in the Dungeon](https://www.avclub.com/die-in-the-dungeon-early-access-thoughts) and [Luck & Loot](https://store.steampowered.com/app/3208110/Luck_&_Loot/) build dice face by face. Dice Forge's face types (resources, combined faces, choice faces, ×3, mirror) are described from general knowledge.
