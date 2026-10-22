// Forgeborn rules v0.3: the same numbers as docs/design.md and tools/playtest/forge.py.
// Pure functions, no DOM. build.mjs inlines this file into the page, so the figure,
// its readout and its idle tour all run on these rules.

export const QUALITY_NAMES = ["gray", "white", "green", "blue", "purple", "orange"];
export const VALUE_FACTOR = [1, 1.5, 2.2, 3.2, 4.6, 6.5];
export const LEVELS_TO_NEXT = [4, 4, 5, 6, 7];
// Tokens out of 20 per quality, in tray order: Break, Crack (-1), Miss (0), Hit (+1), Great hit (+2).
export const TRAY = [
  [0, 1, 2, 14, 3],
  [1, 1, 2, 13, 3],
  [2, 1, 4, 11, 2],
  [3, 2, 5, 8, 2],
  [4, 3, 6, 6, 1],
  [5, 3, 7, 4, 1],
];
export const BIN_NAMES = ["Break", "-1", "0", "+1", "+2"];
export const GAIN = [0, -1, 0, 1, 2];
export const TOKENS = 20;
export const EMBERS_FOR_FRENZY = 7;
export const FRENZY_SWINGS = 3;

export function qualityAt(level) {
  let quality = 0;
  let need = 0;
  while (quality < 5 && level >= need + LEVELS_TO_NEXT[quality]) {
    need += LEVELS_TO_NEXT[quality];
    quality += 1;
  }
  return quality;
}

export function floorOf(level) {
  let quality = 0;
  let need = 0;
  while (quality < 5 && level >= need + LEVELS_TO_NEXT[quality]) {
    need += LEVELS_TO_NEXT[quality];
    quality += 1;
  }
  return need;
}

// Value in silver: item level x quality factor x (1 + 0.1 x level).
export const valueOf = (itemLevel, level) => itemLevel * VALUE_FACTOR[qualityAt(level)] * (1 + 0.1 * level);

export function binOfSlot(quality, slot) {
  let left = slot;
  const bins = TRAY[quality];
  for (let bin = 0; bin < 5; bin += 1) {
    if (left < bins[bin]) return bin;
    left -= bins[bin];
  }
  return 4;
}

export function money(silver) {
  const copper = Math.round(silver * 100);
  const gold = Math.floor(copper / 10000);
  const rest = copper - gold * 10000;
  const silverPart = Math.floor(rest / 100);
  if (gold) return `${gold}g ${String(silverPart).padStart(2, "0")}s`;
  if (silverPart) return `${silverPart}s`;
  return `${rest}c`;
}

// A small seeded generator (mulberry32) so the idle tour is the same every time.
export function random32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const newBlank = (itemLevel = 20) => ({ itemLevel, level: 0, embers: 0, frenzy: 0, broken: false });

export const breakChance = (state) => (state.frenzy > 0 ? 0 : TRAY[qualityAt(state.level)][0] / TOKENS);

// One swing. Draws one of the 20 tokens with replacement; during Frenzy, Break, -1 and 0 are redrawn.
export function strike(state, random) {
  const quality = qualityAt(state.level);
  const safe = state.frenzy > 0;
  let slot = Math.floor(random() * TOKENS);
  while (safe && binOfSlot(quality, slot) < 3) slot = Math.floor(random() * TOKENS);
  const bin = binOfSlot(quality, slot);
  const next = { ...state };
  if (bin === 0) next.broken = true;
  else next.level = Math.max(floorOf(state.level), state.level + GAIN[bin]);
  if (safe) next.frenzy -= 1;
  else next.embers += 1;
  let frenzyStarts = false;
  if (!next.broken && next.embers >= EMBERS_FOR_FRENZY && next.frenzy === 0) {
    next.embers = 0;
    next.frenzy = FRENZY_SWINGS;
    frenzyStarts = true;
  }
  return { slot, bin, quality, next, frenzyStarts, qualityUp: !next.broken && qualityAt(next.level) > quality };
}
