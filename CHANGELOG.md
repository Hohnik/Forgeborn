# Changelog

## 1.1.0 (23 Oct 2026)

Rules v0.4, after ForgeTax's anvil:

- **The odds change with every level.** The Break chance follows a curve over the grade (the level counted from
  the start of gray): 0% for a fresh gray item, 6% at white, 12% green, 20% blue, 30% purple, 40% orange, up to
  70%. Crack, Miss, Hit and Great hit share the rest in a fixed deck (2, 4, 12, 2), and tools that add tokens also
  lower the Break chance. Every swing draws one of 1,000 tickets.
- **Every level multiplies the value by 1.2** (`Data.VALUE_PER_LEVEL`): a Hit ×1.2, a Great hit ×1.44, a Crack
  ÷1.2. The window shows the value after a Hit; the odds bar's tooltip shows the Break chance after a Hit.
- The Righteous Orb makes orange items worth +40% (+85% at legendary).

Window:

- Every item slot is a drag source and a drop target: trophies drag back out of the Display case (or swap with
  an item dropped on them) and reorder; staged items drag off order cards to another card, the anvil, the
  Workbench or the Display case; the anvil and the Workbench take any item, trophies and stones; sharpening
  stones work on any item (drag either onto the other); a shelf tool dropped on the waiting new tool swaps with it.
  Trophies also have "Put on the anvil" and "Put on the Workbench" in their right-click menu.
- The layout is data: `UI/Layout.lua` holds every position and size, and `tools/layout-editor/index.html` edits it
  visually.

## 1.0.1 (23 Oct 2026)

- Fix: the capital city faction no longer reads the character's race during boss encounters, where
  `UnitRace` returns a secret value. The city is worked out at login and saved.
- `Compat.lua`: the few differences between WoW Forever and retail WoW (the progress bar template and the
  item levels orders ask for), so the retail test build in branch `retail-test` runs the same code.

## 1.0.0 (22 Oct 2026)

First version of the addon, built from the design writeup (rules v0.3).

- The anvil: odds bar, Forge and Sell, embers and the automatic Frenzy, cracks that never
  cost a quality, breaks that destroy the copy.
- Loot detection: only weapons and armour from loot windows (mobs, chests) and won rolls
  reach the Workbench (4 slots, the weakest item goes when it's full).
- The Shop: Bronze, Iron and Thorium lockboxes (the only source of tools), sharpening
  stones and faction wares, with a reputation tab per faction.
- 15 tools named after Classic blacksmithing items, a shelf of 4, duplicates that raise a
  tool's rarity, and legendary duplicates salvaged for gold.
- Display case with trophy bonuses, forge records and statistics.
- Crafting orders: one daily and one weekly from four factions (Thorium Brotherhood,
  Steamwheedle Cartel, your capital city, Argent Dawn), WoW-style reputation and rewards.
- Native look from stock Blizzard templates; works in combat; `/forge`, the minimap addon
  menu and a Settings page; English and German.
