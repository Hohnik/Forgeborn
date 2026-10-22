// Records anvil.html as a looping GIF for the README.
//
//   node record.mjs                  writes docs/images/anvil-light.gif and anvil-dark.gif
//   node record.mjs --theme dark     only one theme
//
// Needs Playwright (with Chromium) and ffmpeg. A global Playwright works with NODE_PATH="$(npm root -g)".
// CHROME_PATH overrides the browser.
//
// The page runs on requestAnimationFrame and performance.now, so the recorder replaces both with a
// virtual clock and steps it 10 ms at a time. Every frame is exact, however slow the screenshots are.
// The run is seeded: 10 strikes take a gray blank to blue +14 (with a crack, all four quality steps
// and a Frenzy), then it sells and waits until the anvil looks the same as the first frame.
import { createRequire } from "node:module";
import { execSync, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require("playwright"); } catch { playwright = require(join(execSync("npm root -g").toString().trim(), "playwright")); }

const arg = (name, fallback) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : fallback; };
const themes = arg("--theme") ? [arg("--theme")] : ["light", "dark"];
const FPS = Number(arg("--fps", 25));
const SCALE = Number(arg("--scale", 1.25));
const SEED = Number(arg("--seed", 1347));
const STEP = 10; // ms per simulation step; the page caps one step at 1/30 s
const STEPS_PER_FRAME = Math.round(1000 / FPS / STEP);

// Virtual ms -> what happens. 10 strikes 1.4 s apart, a pause on blue, the sale, then the "sold" note runs out.
const START = 600;
const STRIKES = 10;
const SELL_AT = START + (STRIKES - 1) * 1400 + 1800;
const END = SELL_AT + 2500;
const events = new Map();
for (let i = 0; i < STRIKES; i += 1) events.set(START + i * 1400, "strike");
events.set(SELL_AT, "sell");

const CLOCK = `(() => {
  let now = 0;
  let queue = [];
  performance.now = () => now;
  window.requestAnimationFrame = (callback) => { queue.push(callback); return queue.length; };
  window.cancelAnimationFrame = () => {};
  window.__clock = {
    step(ms) {
      now += ms;
      const due = queue; queue = [];
      for (const callback of due) callback(now);
    },
    settle() { for (const a of document.getAnimations()) { a.pause(); a.currentTime = now; } },
  };
})();`;

async function record(theme) {
  const browser = await playwright.chromium.launch({ executablePath: process.env.CHROME_PATH || undefined });
  const page = await browser.newPage({ viewport: { width: 760, height: 640 }, deviceScaleFactor: SCALE, colorScheme: theme, reducedMotion: "no-preference" });
  await page.addInitScript(CLOCK);
  await page.goto(pathToFileURL(join(HERE, "anvil.html")).href);
  await page.waitForTimeout(500); // let the IntersectionObserver mark the stage visible
  await page.evaluate((seed) => {
    window.__anvil.still(true);
    let a = seed >>> 0; // mulberry32, as random32 in model.mjs
    window.__rng = () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    document.querySelector('[data-corner="hint"]').style.visibility = "hidden"; // a GIF cannot be clicked
  }, SEED);

  const frames = mkdtempSync(join(tmpdir(), "anvil-frames-"));
  const plate = page.locator(".iso-plate");
  let now = 0;
  let frame = 0;
  while (now <= END) {
    for (let i = 0; i < STEPS_PER_FRAME; i += 1) {
      const event = events.get(now);
      if (event === "strike") await page.evaluate(() => window.__anvil.strike(window.__rng));
      if (event === "sell") await page.evaluate(() => window.__anvil.sell());
      now += STEP;
      await page.evaluate((ms) => window.__clock.step(ms), STEP);
    }
    await page.evaluate(() => window.__clock.settle());
    await plate.screenshot({ path: join(frames, `f${String(frame).padStart(4, "0")}.png`) });
    frame += 1;
  }
  const state = await page.evaluate(() => JSON.stringify(window.__anvil.state()));
  await browser.close();

  const out = join(HERE, "..", "..", "images", `anvil-${theme}.gif`);
  const input = ["-v", "error", "-y", "-framerate", String(FPS), "-i", join(frames, "f%04d.png")];
  const palette = join(frames, "palette.png");
  const run = (args) => { const r = spawnSync("ffmpeg", args, { stdio: "inherit" }); if (r.status) throw new Error("ffmpeg failed"); };
  run([...input, "-vf", "palettegen=max_colors=64:stats_mode=full", palette]);
  run([...input, "-i", palette, "-lavfi", "paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle", "-loop", "0", out]);
  rmSync(frames, { recursive: true });
  console.log(`wrote ${out} · ${frame} frames at ${FPS} fps · ${(statSync(out).size / 1e6).toFixed(2)} MB · end state ${state}`);
}

for (const theme of themes) await record(theme);
