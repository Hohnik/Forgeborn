// Fig 1 · The anvil. A drop hammer, a token tray, an ember hearth and a quality post,
// all driven by the Forgeborn v0.3 rules in model.mjs.
//
//   node build.mjs           writes anvil.html, which follows the viewer's light or dark setting
//   node build.mjs --light   writes anvil-light.html (fixed theme, for checks; not committed)
//   node build.mjs --dark    writes anvil-dark.html  (fixed theme, for checks; not committed)
//
// Built with the Anatomy kit (MIT, vendored in ../vendor/anatomy).
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "../vendor/anatomy/iso-kit.mjs";
import * as M from "./model.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const theme = process.argv.includes("--light") ? "light" : process.argv.includes("--dark") ? "dark" : "auto";
const strip = (file) => readFileSync(file, "utf8").replace(/^export /gm, "");

const WIDTH = 640;
const HEIGHT = 440;

// ---------- World layout (world units, z up) ----------
const BASE = { x: -132, y: -82, w: 296, d: 148, r: 8 };
const BASE_H = 12;
const FOOT_H = 5;

// Drop hammer
const HX = -62;
const COL_Y = 34;
const COL_TOP = 128;
const HEAD_Z = 140;
const HOUSING_TOP = 186;
const CONTACT = 33; // die bottom when it lands on the blank
const REST = 70; // die bottom at rest
const ROD_TOP = 112; // rod top, in the ram's own frame: inside the housing from contact to rest

// Token tray
const TRAY = { x: -34, y: 20, w: 184, d: 22, r: 3 };
const TOKEN_Y = 31;
const TOKEN_R = 3.2;
const X0 = -30;
const PITCH = 8;
const GAP = 4;
const LIFT = 3;
const SHUTTER = { x: -34, y: 21, d: 20 };
const RAIL_Y = 45;

// Hearth and quality post
const HEARTH = { x: 0, y: -66, w: 64, d: 20, r: 3 };
const COALS = [0, 1, 2, 3, 4, 5, 6].map((i) => [8 + 8 * i, -56]);
const POST = { x: 100, y: -66, w: 10, d: 10, r: 1 };
const RIDER_Z0 = 10;
const RIDER_STEP = 3;
const LEVEL_MAX = 34;

const P = k.fitProjection(
  [...k.boxCorners(BASE, -BASE_H - FOOT_H, 0), [HX, 0, HOUSING_TOP + 4], [HX, -COL_Y - 11, HEAD_Z], [POST.x + 5, POST.y + 5, 122]],
  WIDTH,
  HEIGHT,
  { pad: 30, azimuth: 45 },
);

const at = (point) => k.iso(point, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);
const slab = (plan, z, h, steps = 3, bevel = 0) => k.slabOf(plan, z, h, P, steps, bevel);
const byDepth = (points) => [...points].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P));

// Where each token and divider sits for a given quality.
const slotX = (quality, slot) => X0 + PITCH / 2 + PITCH * slot + GAP * M.binOfSlot(quality, slot);
const dividerX = (quality, index) => {
  let count = 0;
  for (let bin = 0; bin <= index; bin += 1) count += M.TRAY[quality][bin];
  return X0 + PITCH * count + GAP * index + GAP / 2;
};
const shutterWidth = (quality) => dividerX(quality, 2) + 0.8 - SHUTTER.x;

// ---------- Static parts ----------
function base() {
  const out = [`<path class="iso-halo" d="${k.haloOf(BASE, -BASE_H - FOOT_H, BASE_H, P)}"/>`];
  for (const [x, y] of byDepth(k.corners(BASE, 24))) {
    out.push(S(k.cylinder(x, y, 8, -BASE_H - FOOT_H, 1.6, P, 28), { tone: "lo" }));
    out.push(S(k.cylinder(x, y, 6.2, -BASE_H - FOOT_H + 1.6, FOOT_H - 1.6, P, 28), { tone: "mid" }));
  }
  out.push(S(k.slabOf(BASE, -BASE_H, BASE_H, P, 8, 1.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(BASE, 5), 0, P), { tone: "lo" }));
  const screws = k.corners(BASE, 11);
  out.push(L(screws.map(([x, y]) => k.ring(x, y, 2.4, 0, P, 16)).join(""), { tone: "lo" }));
  out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.5 }));
  // Label plate with the one engraved word.
  const label = { x: -122, y: 44, w: 46, d: 14, r: 2 };
  out.push(S(slab(label, 0, 0.8, 4), { tone: "lo", crease: "none" }));
  out.push(L(k.planOutline(k.insetPlan(label, 1.6), 0.8, P, 4), { tone: "faint" }));
  out.push(k.faceTextSvg(k.topMatrix([label.x + label.w / 2, label.y + 6.6], 0.8, P, "x"), "FORGEBORN", { size: 3.6, tone: "mid", anchor: "middle" }));
  out.push(L(k.lineOnTop([label.x + 9, label.y + 10.4], [label.x + 37, label.y + 10.4], 0.8, P), { tone: "faint", free: true }));
  out.push(D([at([label.x + 3.4, label.y + 7, 0.8]), at([label.x + label.w - 3.4, label.y + 7, 0.8])], { size: 0.45 }));
  return out.join("");
}

function hearth() {
  const out = [`<path class="iso-halo" d="${k.haloOf(HEARTH, 0, 1, P)}" style="filter:blur(3px)"/>`];
  out.push(S(slab(HEARTH, 0, 12, 4, 0.8), { tone: "mid", inner: L(k.sideSeam(HEARTH, 4, P, 4), { tone: "faint" }) }));
  const pan = k.insetPlan(HEARTH, 3);
  out.push(L(k.planOutline(pan, 12, P, 4), { tone: "lo" }));
  for (let x = pan.x + 4; x < pan.x + pan.w - 2; x += 4) out.push(L(k.lineOnTop([x, pan.y], [x, pan.y + pan.d], 12, P), { tone: "faint" }));
  out.push(D(k.corners(HEARTH, 1.8).map(([x, y]) => at([x, y, 12])), { size: 0.45 }));
  // Blower on the +x end with a knurled crank.
  const blower = { x: HEARTH.x + HEARTH.w, y: HEARTH.y + 4, w: 10, d: 12, r: 1.5 };
  out.push(S(slab(blower, 0, 9, 3, 0.5), { tone: "mid" }));
  out.push(S(k.cylinder(blower.x + 5, blower.y + 6, 3.2, 9, 3, P, 24), { tone: "mid" }));
  out.push(L(k.knurl(blower.x + 5, blower.y + 6, 3.2, 9, 12, 20, P), { tone: "lo" }));
  out.push(L(k.lineOnTop([blower.x + 5, blower.y + 6], [blower.x + 7.6, blower.y + 6], 12, P), { tone: "hi" }));
  return out.join("");
}

function coal(i) {
  const [x, y] = COALS[i];
  const embers = k.dotGrid(x - 1.2, y - 1.2, 2, 2, 2.4, 14.6, P);
  return `<g data-part="coal" data-i="${i}">${S(k.cylinder(x, y, 3, 12, 2.6, P, 18), { tone: "faint" })}<g class="ember" style="display:none">${D(embers, { size: 0.55, tone: "hi", pulse: true })}</g></g>`;
}

function post() {
  const out = [];
  const foot = { x: POST.x - 7, y: POST.y - 7, w: 24, d: 24, r: 2 };
  out.push(S(slab(foot, 0, 3, 4, 0.6), { tone: "mid" }));
  out.push(D(k.corners(foot, 3).map(([x, y]) => at([x, y, 3])), { size: 0.45 }));
  out.push(S(slab(POST, 3, 115, 3, 0.5), { tone: "mid", inner: L(k.sideSeam(POST, 60, P, 3), { tone: "faint" }) }));
  out.push(S(slab(k.insetPlan(POST, -1.2), 118, 4, 3, 0.5), { tone: "mid" }));
  // Ruler strip on the +y face with one tick per level and majors at each quality step.
  const face = POST.y + POST.d;
  out.push(S(k.slabOf({ x: POST.x + 1, y: face, w: 8, d: 0.6, r: 0.2 }, RIDER_Z0 - 2, RIDER_STEP * LEVEL_MAX + 4, P, 2), { tone: "lo", crease: "none" }));
  const majors = [0, 4, 8, 13, 19, 26];
  const minor = [];
  const major = [];
  for (let level = 0; level <= LEVEL_MAX; level += 1) {
    const z = RIDER_Z0 + RIDER_STEP * level;
    const len = majors.includes(level) ? 5.4 : 2.6;
    (majors.includes(level) ? major : minor).push(k.segment([POST.x + 9, face + 0.6, z], [POST.x + 9 - len, face + 0.6, z], P));
  }
  out.push(L(minor.join(""), { tone: "lo" }), L(major.join(""), { tone: "mid" }));
  return out.join("");
}

function rider() {
  const collar = k.insetPlan(POST, -2.2);
  const out = [];
  out.push(S(slab(collar, -3, 6, 3, 0.4), { tone: "hi" }));
  out.push(S(slab({ x: POST.x + 2.6, y: POST.y + POST.d + 2.2, w: 4.8, d: 3, r: 0.6 }, -1.2, 2.4, 2), { tone: "hi" }));
  out.push(S(k.cylinder(collar.x + collar.w + 1.6, POST.y + POST.d / 2, 1.6, -1.6, 3.2, P, 14), { tone: "mid" }));
  return out.join("");
}

function column(y) {
  const out = [];
  const flange = { x: HX - 11, y: y - 11, w: 22, d: 22, r: 2 };
  out.push(S(slab(flange, 0, 3, 4, 0.6), { tone: "mid" }));
  out.push(D(k.corners(flange, 3).map(([x, yy]) => at([x, yy, 3])), { size: 0.45 }));
  const plan = { x: HX - 7, y: y - 7, w: 14, d: 14, r: 1.5 };
  out.push(S(slab(plan, 3, COL_TOP - 3, 3, 0.6), { tone: "mid", inner: L(k.sideSeam(plan, 40, P, 3) + k.sideSeam(plan, 112, P, 3), { tone: "faint" }) }));
  return out.join("");
}

function anvil() {
  const out = [`<path class="iso-halo" d="${k.haloOf({ x: HX - 21, y: -24, w: 42, d: 48, r: 3 }, 0, 1, P)}" style="filter:blur(3px)"/>`];
  const flange = { x: HX - 21, y: -24, w: 42, d: 48, r: 3 };
  out.push(S(slab(flange, 0, 5, 4, 0.6), { tone: "mid" }));
  for (const [x, y] of byDepth(k.corners(flange, 4))) {
    out.push(S(k.cylinder(x, y, 2.2, 5, 2, P, 14), { tone: "mid" }));
    out.push(D([at([x, y, 7])], { size: 0.5 }));
  }
  const block = { x: HX - 15, y: -19, w: 30, d: 38, r: 2 };
  out.push(S(slab(block, 5, 21, 4, 1), { tone: "mid", inner: L(k.sideSeam(block, 14, P, 4), { tone: "faint" }) }));
  const die = { x: HX - 8, y: -18, w: 16, d: 36, r: 1 };
  out.push(S(slab(die, 26, 4, 3, 0.5), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(die, 2), 30, P, 3), { tone: "faint" }));
  return out.join("");
}

// The blank: a blade with a point toward -y and a tang toward +y.
function blank() {
  const ring = [
    [HX, -25],
    [HX + 4, -18],
    [HX + 4, 14],
    [HX + 1.6, 16],
    [HX + 1.6, 25],
    [HX - 1.6, 25],
    [HX - 1.6, 16],
    [HX - 4, 14],
    [HX - 4, -18],
  ];
  const paths = k.extrude(ring, 30, 3, P, { convex: false, bevel: 0.4 });
  return S(paths, { tone: "hi", crease: "lo", inner: L(k.lineOnTop([HX, -25], [HX, 14], 33, P) + k.lineOnTop([HX - 4, 14], [HX + 4, 14], 33, P), { tone: "faint" }) });
}

function ram() {
  const out = [];
  out.push(S(k.cylinder(HX, 0, 3, 36, ROD_TOP - 36, P, 20), { tone: "mid", crease: "none" }));
  const die = { x: HX - 8, y: -18, w: 16, d: 36, r: 1 };
  out.push(S(slab(die, 0, 6, 3, 0.5), { tone: "mid" }));
  const body = { x: HX - 11, y: -27, w: 22, d: 54, r: 2 };
  out.push(S(slab(body, 6, 26, 4, 0.8), { tone: "mid", inner: L(k.sideSeam(body, 19, P, 4), { tone: "faint" }) }));
  out.push(D(k.corners(body, 3.2).map(([x, y]) => at([x, y, 32])), { size: 0.5 }));
  out.push(S(k.cylinder(HX, 0, 6, 32, 4, P, 28, 0.4), { tone: "mid" }));
  return out.join("");
}

function head() {
  const out = [];
  const beam = { x: HX - 11, y: -COL_Y - 11, w: 22, d: COL_Y * 2 + 22, r: 2 };
  out.push(S(slab(beam, COL_TOP, HEAD_Z - COL_TOP, 4, 1), { tone: "mid", inner: L(k.sideSeam(beam, COL_TOP + 7, P, 4), { tone: "faint" }) }));
  for (const y of [-COL_Y, COL_Y]) out.push(D(k.corners({ x: HX - 7, y: y - 7, w: 14, d: 14 }, 2.4).map(([x, yy]) => at([x, yy, HEAD_Z])), { size: 0.5 }));
  out.push(S(k.cylinder(HX, 0, 13, HEAD_Z, 3, P, 40, 0.5), { tone: "mid" }));
  const bolts = [0, 1, 2, 3, 4, 5].map((i) => [HX + Math.cos((i * Math.PI) / 3 + 0.5) * 11.4, Math.sin((i * Math.PI) / 3 + 0.5) * 11.4]);
  out.push(D(bolts.map(([x, y]) => at([x, y, HEAD_Z + 3])), { size: 0.45 }));
  out.push(S(k.cylinder(HX, 0, 9, HEAD_Z + 3, HOUSING_TOP - HEAD_Z - 3, P, 40), { tone: "mid", inner: L(k.sideArc(HX, 0, 9, 156, P, 24) + k.sideArc(HX, 0, 9, 176, P, 24), { tone: "faint" }) }));
  out.push(S(k.slabOf({ x: HX + 8, y: -2.5, w: 4.5, d: 5, r: 1 }, 166, 5, P, 2), { tone: "mid" }));
  out.push(S(k.cylinder(HX + 12.5, 0, 2.2, 167, 3, P, 14), { tone: "mid" }));
  out.push(S(k.cylinder(HX, 0, 10.5, HOUSING_TOP, 4, P, 40, 0.5), { tone: "mid" }));
  out.push(L(k.ring(HX, 0, 3.4, HOUSING_TOP + 4, P, 20), { tone: "lo" }));
  return out.join("");
}

function trayBack() {
  const out = [`<path class="iso-halo" d="${k.haloOf(TRAY, 0, 1, P)}" style="filter:blur(3px)"/>`];
  out.push(S(slab(TRAY, 0, 2, 4, 0.4), { tone: "lo" }));
  out.push(S(slab({ x: TRAY.x, y: TRAY.y, w: TRAY.w, d: 3, r: 1 }, 2, 5, 2, 0.3), { tone: "mid" }));
  out.push(S(slab({ x: TRAY.x, y: TRAY.y + 3, w: 3, d: 16, r: 0.6 }, 2, 5, 2, 0.3), { tone: "mid" }));
  out.push(D([at([TRAY.x + 6, TRAY.y + 1.5, 7]), at([TRAY.x + TRAY.w - 6, TRAY.y + 1.5, 7])], { size: 0.45 }));
  // Shutter box at the left end; the shutter rolls out of it at z 5.2, over the dividers.
  const box = { x: TRAY.x - 9, y: TRAY.y - 1, w: 9, d: 24, r: 2 };
  out.push(S(slab(box, 0, 12, 4, 0.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(box, 1.6), 12, P, 4), { tone: "faint" }));
  out.push(D([at([box.x + 4.5, box.y + 4, 12]), at([box.x + 4.5, box.y + box.d - 4, 12])], { size: 0.45 }));
  return out.join("");
}

function token() {
  return S(k.cylinder(0, TOKEN_Y, TOKEN_R, 2, 3, P, 20, 0.3), { tone: "hi", crease: "lo" }) + L(k.ring(0, TOKEN_Y, 1.5, 5, P, 14), { tone: "faint" });
}

function divider() {
  return S(slab({ x: -0.8, y: TRAY.y + 3, w: 1.6, d: 16, r: 0.3 }, 2, 3, 2), { tone: "mid" });
}

function trayFront() {
  const out = [];
  out.push(S(slab({ x: TRAY.x + TRAY.w - 3, y: TRAY.y + 3, w: 3, d: 16, r: 0.6 }, 2, 5, 2, 0.3), { tone: "mid" }));
  out.push(S(slab({ x: TRAY.x, y: TRAY.y + TRAY.d - 3, w: TRAY.w, d: 3, r: 1 }, 2, 1.4, 2, 0.3), { tone: "mid" }));
  out.push(D([at([TRAY.x + 6, TRAY.y + TRAY.d - 1.5, 3.4]), at([TRAY.x + TRAY.w - 6, TRAY.y + TRAY.d - 1.5, 3.4])], { size: 0.45 }));
  return out.join("");
}

function rail() {
  const out = [];
  const bar = { x: TRAY.x, y: RAIL_Y, w: TRAY.w, d: 6, r: 1.5 };
  out.push(S(slab(bar, 0, 3, 3, 0.4), { tone: "mid" }));
  out.push(L(k.lineOnTop([bar.x, RAIL_Y + 3], [bar.x + bar.w, RAIL_Y + 3], 3, P), { tone: "faint" }));
  for (const x of [TRAY.x - 4, TRAY.x + TRAY.w]) {
    out.push(S(slab({ x, y: RAIL_Y - 2, w: 4, d: 10, r: 1 }, 0, 6, 3, 0.4), { tone: "mid" }));
    out.push(D([at([x + 2, RAIL_Y + 0.5, 6]), at([x + 2, RAIL_Y + 5.5, 6])], { size: 0.45 }));
  }
  const ruler = { x: TRAY.x + 2, y: RAIL_Y + 9.5, w: TRAY.w - 4, d: 3.6, r: 0.6 };
  out.push(S(slab(ruler, 0, 0.5, 2), { tone: "lo", crease: "none" }));
  const ticks = k.topTicks(ruler.x + 2, ruler.x + ruler.w - 2, PITCH / 2, 4, ruler.y, 0.5, [1.2, 2.4], P);
  out.push(L(ticks.minor, { tone: "lo" }), L(ticks.major, { tone: "mid" }));
  return out.join("");
}

function pointer() {
  const out = [];
  out.push(S(slab({ x: -6, y: RAIL_Y - 2, w: 12, d: 10, r: 1.5 }, 3, 6, 3, 0.5), { tone: "mid" }));
  out.push(D([at([-3.6, RAIL_Y + 6, 9]), at([3.6, RAIL_Y + 6, 9])], { size: 0.45 }));
  out.push(S(slab({ x: -1.2, y: TOKEN_Y + 1.6, w: 2.4, d: RAIL_Y - TOKEN_Y - 0.6, r: 0.6 }, 8.2, 1, 2), { tone: "hi", crease: "lo" }));
  out.push(S(k.cylinder(0, RAIL_Y + 10.4, 2.4, 4, 4, P, 16), { tone: "mid" }));
  out.push(L(k.knurl(0, RAIL_Y + 10.4, 2.4, 4, 8, 14, P), { tone: "lo" }));
  return out.join("");
}

function shutterSvg(width) {
  if (width < 0.6) return "";
  const plan = { x: SHUTTER.x, y: SHUTTER.y, w: width, d: SHUTTER.d, r: 0.4 };
  const slats = [];
  for (let x = SHUTTER.x + 4; x < SHUTTER.x + width - 0.5; x += 4) slats.push(k.lineOnTop([x, SHUTTER.y], [x, SHUTTER.y + SHUTTER.d], 6.2, P));
  return S(k.slabOf(plan, 5.2, 1, P, 2), { tone: "mid" }) + L(slats.join(""), { tone: "faint" });
}

// ---------- Assemble ----------
const Q0 = 0;
const tokens = Array.from({ length: M.TOKENS }, (_, slot) => `<g data-part="token" data-slot="${slot}" transform="${k.translateAlong(P, [slotX(Q0, slot), 0, 0])}">${token()}</g>`);
const dividers = [0, 1, 2, 3].map((i) => `<g data-part="divider" data-i="${i}" transform="${k.translateAlong(P, [dividerX(Q0, i), 0, 0])}">${divider()}</g>`);
// Tokens and dividers in one row, painted left to right (far to near along x).
const row = [...tokens.map((svg, slot) => ({ x: slotX(Q0, slot), svg })), ...dividers.map((svg, i) => ({ x: dividerX(Q0, i), svg }))].sort((a, b) => a.x - b.x).map((item) => item.svg);

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label:
    "A drop hammer over an anvil block, with a blade blank on the anvil. In front of it a tray holds 20 tokens in five bins: Break, minus one, zero, plus one and plus two. A pointer on a rail picks the token each strike draws. Behind, a hearth holds seven coals that light up toward Frenzy, and a post on the right carries a rider that climbs one tick per level from gray to orange.",
  body: [
    base(),
    hearth(),
    COALS.map((_, i) => coal(i)).join(""),
    post(),
    `<g data-part="rider" transform="${k.translateAlong(P, [0, 0, RIDER_Z0])}">${rider()}</g>`,
    column(-COL_Y),
    anvil(),
    `<g data-part="blank">${blank()}</g>`,
    `<g data-part="ram" transform="${k.translateAlong(P, [0, 0, REST])}">${ram()}</g>`,
    column(COL_Y),
    head(),
    trayBack(),
    `<g data-part="row">${row.join("")}</g>`,
    `<g data-part="shutter"></g>`,
    trayFront(),
    rail(),
    `<g data-part="pointer" transform="${k.translateAlong(P, [slotX(Q0, 10), 0, 0])}">${pointer()}</g>`,
  ],
});

// ---------- Live ----------
const live = `
const P = ${JSON.stringify(P)};
const C = ${JSON.stringify({ X0, PITCH, GAP, LIFT, REST, CONTACT, RIDER_Z0, RIDER_STEP, SHUTTER, TOKEN_Y })};
const slotX = ${slotX.toString()};
const dividerX = ${dividerX.toString()};
const shutterWidth = ${shutterWidth.toString()};
${shutterSvg.toString()}
const slab = ${slab.toString()};
const M = { TRAY, TOKENS, binOfSlot, QUALITY_NAMES };
const X0 = C.X0, PITCH = C.PITCH, GAP = C.GAP, SHUTTER = C.SHUTTER;
const S = (paths, style) => solidSvg(paths, style);
const L = (d, style) => lineSvg(d, style);
const k = { slabOf, lineOnTop };
const stage = document.querySelector(".iso-stage");
const svg = stage.querySelector("svg");
const readout = document.querySelector("[data-readout]");
const still = matchMedia("(prefers-reduced-motion: reduce)");
const ramEl = svg.querySelector('[data-part="ram"]');
const blankEl = svg.querySelector('[data-part="blank"]');
const blankSolid = blankEl.querySelector(".iso-solid");
const riderEl = svg.querySelector('[data-part="rider"]');
const pointerEl = svg.querySelector('[data-part="pointer"]');
const shutterEl = svg.querySelector('[data-part="shutter"]');
const tokenEls = [...svg.querySelectorAll('[data-part="token"]')].sort((a, b) => a.dataset.slot - b.dataset.slot);
const tokenSolids = tokenEls.map((el) => el.querySelector(".iso-solid"));
const dividerEls = [...svg.querySelectorAll('[data-part="divider"]')].sort((a, b) => a.dataset.i - b.dataset.i);
const coalEls = [...svg.querySelectorAll('[data-part="coal"]')].sort((a, b) => a.dataset.i - b.dataset.i);
const rowEl = svg.querySelector('[data-part="row"]');

let state = newBlank();
let gold = 0;
let note = "";
let noteUntil = 0;
const tourRandom = random32(2026);
const view = {
  ram: C.REST,
  pointer: slotX(0, 10), pointerTo: slotX(0, 10),
  tokens: tokenEls.map((_, slot) => ({ x: slotX(0, slot), to: slotX(0, slot), lift: 0, liftTo: 0 })),
  dividers: dividerEls.map((_, i) => ({ x: dividerX(0, i), to: dividerX(0, i) })),
  rider: C.RIDER_Z0, riderTo: C.RIDER_Z0,
  shutter: 0, shutterTo: 0,
  blank: 1, blankTo: 1, blankDrop: 0,
  flash: 0,
};
let swing = null; // { age, result, applied, random }
let clock = 0, lastAction = 0, touring = !still.matches, idleUntil = 0;
let frame = 0, last = 0, visible = false;

const quality = () => qualityAt(state.level);
const ease = (value, target, dt, tau) => (still.matches ? target : value + (target - value) * (1 - Math.exp(-dt / tau)));
function layout() {
  const q = quality();
  view.tokens.forEach((t, slot) => { t.to = slotX(q, slot); });
  view.dividers.forEach((d, i) => { d.to = dividerX(q, i); });
  view.riderTo = C.RIDER_Z0 + C.RIDER_STEP * Math.min(state.level, 34);
  view.shutterTo = state.frenzy > 0 && !state.broken ? shutterWidth(q) : 0;
  coalEls.forEach((el, i) => {
    const on = i < state.embers || state.frenzy > 0;
    el.querySelector(".iso-edge").setAttribute("data-tone", on ? "hi" : "faint");
    el.querySelector(".ember").style.display = on && !still.matches ? "" : "none";
  });
}
function readoutText() {
  if (performance.now() < noteUntil) return note;
  if (state.broken) return "broken · press to forge a new blank";
  const q = quality();
  const chance = Math.round(breakChance(state) * 100);
  const frenzy = state.frenzy > 0 ? " · Frenzy " + state.frenzy : "";
  return QUALITY_NAMES[q] + " +" + state.level + " · " + money(valueOf(state.itemLevel, state.level)) + " · break " + chance + "%" + frenzy;
}
function describe() {
  stage.setAttribute("aria-label", "The anvil. Space or Enter strikes, S sells. " + readoutText());
}
function say(text, seconds) { note = text; noteUntil = performance.now() + seconds * 1000; }

function freshBlank() {
  state = newBlank();
  view.blank = 0; view.blankTo = 1; view.blankDrop = 6;
  layout();
  describe();
}
function strikeNow(random) {
  if (swing) return;
  if (state.broken) { freshBlank(); return; }
  const result = strike(state, random);
  swing = { age: 0, result, applied: false };
  view.pointerTo = view.tokens[result.slot].to;
  view.tokens[result.slot].liftTo = C.LIFT;
  tokenSolids[result.slot].setAttribute("data-lit", "");
}
function sellNow() {
  if (swing || state.broken) return;
  const value = valueOf(state.itemLevel, state.level);
  gold += value;
  say("sold " + QUALITY_NAMES[quality()] + " +" + state.level + " for " + money(value) + " · total " + money(gold), 2.4);
  freshBlank();
}
function apply() {
  const r = swing.result;
  state = r.next;
  if (state.broken) {
    view.blankTo = 0;
    say("break · lost " + QUALITY_NAMES[r.quality] + " +" + r.next.level + " · " + money(valueOf(state.itemLevel, r.next.level)), 2.2);
  } else {
    view.flash = 1;
    if (r.frenzyStarts) say("embers full · Frenzy: 3 safe strikes", 1.8);
  }
  layout();
  describe();
}
function tourStep() {
  if (state.broken) { freshBlank(); return; }
  if (quality() >= 3) { sellNow(); return; }
  strikeNow(tourRandom);
}
function draw() {
  ramEl.setAttribute("transform", translateAlong(P, [0, 0, view.ram]));
  pointerEl.setAttribute("transform", translateAlong(P, [view.pointer, 0, 0]));
  view.tokens.forEach((t, slot) => tokenEls[slot].setAttribute("transform", translateAlong(P, [t.x, 0, t.lift])));
  view.dividers.forEach((d, i) => dividerEls[i].setAttribute("transform", translateAlong(P, [d.x, 0, 0])));
  riderEl.setAttribute("transform", translateAlong(P, [0, 0, view.rider]));
  blankEl.setAttribute("transform", translateAlong(P, [0, 0, view.blankDrop]));
  blankEl.style.opacity = view.blank.toFixed(3);
  if (view.flash > 0.05) blankSolid.setAttribute("data-lit", ""); else blankSolid.removeAttribute("data-lit");
  const width = Math.round(view.shutter * 10) / 10;
  if (shutterEl.dataset.w !== String(width)) { shutterEl.dataset.w = String(width); shutterEl.innerHTML = shutterSvg(width); }
  const text = readoutText();
  if (readout.textContent !== text) readout.textContent = text;
}
function tick(now) {
  const dt = last ? Math.min((now - last) / 1000, 1 / 30) : 1 / 60;
  last = now;
  clock += dt;
  if (swing) {
    swing.age += dt;
    const a = swing.age;
    if (a < 0.32) view.ram = ease(view.ram, C.REST + 4, dt, 0.08);
    else if (!swing.applied) {
      const fall = Math.min(1, (a - 0.32) / 0.2);
      view.ram = (C.REST + 4) - (C.REST + 4 - C.CONTACT) * fall * fall;
      if (still.matches || fall >= 1) { view.ram = C.CONTACT; swing.applied = true; apply(); }
    } else view.ram = ease(view.ram, C.REST, dt, 0.2);
    if (a > 0.95 && view.tokens[swing.result.slot].liftTo) {
      view.tokens[swing.result.slot].liftTo = 0;
      tokenSolids[swing.result.slot].removeAttribute("data-lit");
    }
    if (a > 1.25 && swing.applied) { view.ram = C.REST; swing = null; }
  } else if (touring && clock > idleUntil && clock - lastAction > 1.5) {
    lastAction = clock;
    tourStep();
  }
  view.pointer = ease(view.pointer, view.pointerTo, dt, 0.12);
  for (const t of view.tokens) { t.x = ease(t.x, t.to, dt, 0.3); t.lift = ease(t.lift, t.liftTo, dt, 0.08); }
  for (const d of view.dividers) d.x = ease(d.x, d.to, dt, 0.3);
  view.rider = ease(view.rider, view.riderTo, dt, 0.25);
  view.shutter = ease(view.shutter, view.shutterTo, dt, 0.25);
  view.blank = ease(view.blank, view.blankTo, dt, 0.18);
  view.blankDrop = ease(view.blankDrop, 0, dt, 0.18);
  view.flash = still.matches ? 0 : view.flash * Math.exp(-dt / 0.12);
  draw();
  const moving = swing || touring || Math.abs(view.pointer - view.pointerTo) > 0.01 || Math.abs(view.rider - view.riderTo) > 0.01 || Math.abs(view.shutter - view.shutterTo) > 0.05 || Math.abs(view.blank - view.blankTo) > 0.002 || view.flash > 0.01 || performance.now() < noteUntil + 50 || view.tokens.some((t) => Math.abs(t.x - t.to) > 0.01 || Math.abs(t.lift - t.liftTo) > 0.01) || view.dividers.some((d) => Math.abs(d.x - d.to) > 0.01);
  frame = visible && moving ? requestAnimationFrame(tick) : 0;
}
const run = () => { if (!frame && visible) { last = 0; frame = requestAnimationFrame(tick); } };
const hold = () => { idleUntil = clock + 6; lastAction = clock; };
new IntersectionObserver((entries) => { visible = entries[entries.length - 1].isIntersecting; if (visible) run(); }, { rootMargin: "120px 0px" }).observe(stage);
stage.addEventListener("click", () => { hold(); strikeNow(Math.random); run(); });
stage.addEventListener("keydown", (event) => {
  if (event.key === " " || event.key === "Enter") { event.preventDefault(); hold(); strikeNow(Math.random); run(); }
  if (event.key === "s" || event.key === "S") { event.preventDefault(); hold(); sellNow(); run(); }
});
idleUntil = 1.4;
layout();
describe();
draw();
window.__anvil = { strike: (random) => { strikeNow(typeof random === "function" ? random : random === undefined ? Math.random : random32(random)); run(); }, sell: () => { sellNow(); run(); }, state: () => state, setLevel: (level, frenzy = 0, embers = 0) => { state = { ...state, level, frenzy, embers, broken: false }; layout(); describe(); run(); }, still: (on) => { touring = !on; run(); } };
`;

const body = k.plateHtml({
  fig: "Fig 1",
  title: "The anvil",
  hint: "Click or Space to strike · S to sell",
  readout: "gray +0 · 20s · break 0%",
  keys: [
    { mark: "lit", label: "The token this strike drew" },
    { mark: "raised", label: "20 tokens in five bins, left to right: Break, −1, 0, +1, +2" },
    { mark: "flat", label: "Shutter: Frenzy covers Break, −1 and 0 for 3 strikes" },
  ],
  caption:
    "Each strike draws one of 20 tokens, with replacement. A blade of item level 20 starts gray with no Break token; every quality up moves tokens into the Break bin, from 1 in 20 at white to 5 at orange. Seven strikes light the hearth and Frenzy shutters the bad bins for three strikes. The rider climbs one tick per level; value is item level × quality factor × (1 + 0.1 × level) silver.",
  body: `<div class="iso-stage" tabindex="0" role="group" aria-label="The anvil. Space or Enter strikes, S sells.">${svg}</div>`,
});

const script = strip(join(HERE, "../vendor/anatomy/iso-kit.mjs")) + "\n" + strip(join(HERE, "model.mjs")) + "\n" + live;
// "auto": light by default, dark when the viewer prefers it, and a data-theme on <html> wins over both.
const DARK_VARS = k.ISO_CSS.match(/\.iso\{([^}]*)\}/)[1];
const LIGHT_VARS = k.ISO_CSS.match(/\.iso\[data-theme="light"\]\{([^}]*)\}/)[1];
const AUTO_CSS = `
.iso[data-theme="auto"]{${LIGHT_VARS}}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]) .iso[data-theme="auto"]{${DARK_VARS}}}
:root[data-theme="dark"] .iso[data-theme="auto"]{${DARK_VARS}}
html{color-scheme:light dark}:root[data-theme="light"]{color-scheme:light}:root[data-theme="dark"]{color-scheme:dark}
`;
const out = { auto: "anvil.html", light: "anvil-light.html", dark: "anvil-dark.html" }[theme];
let html = k.pageHtml({ title: "The anvil", theme, body, script, width: 680 });
if (theme === "auto") html = html.replace("</style>", `${AUTO_CSS}</style>`);
writeFileSync(join(HERE, out), html);
console.log("wrote", out);
