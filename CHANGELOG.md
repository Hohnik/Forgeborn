# Changelog

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
