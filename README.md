# Forgeborn

A push-your-luck forging minigame addon for **World of Warcraft: Forever**.

You put a copy of an item you really looted on the anvil and strike it up the
gray → white → green → blue → purple → orange ladder, one swing at a time.
Every swing can break it, so you sell before it does. Crafting orders from four
factions give you a reason to come back, and addon gold buys lockboxes in the
Shop that drop rare tools named after Classic blacksmithing items.

The window is built only from Blizzard's stock UI templates, so it looks like
part of the Forever interface. Your real items, gold and stats are never touched.

![Forge window mock-up](docs/images/window-mockup.png)

## Status

Design phase. The rules are at v0.3 after a chat playtest; no addon code exists yet.
WoW Forever launches on 4 Nov 2026 (interface version 16001 on beta).

## Docs

- [docs/design.md](docs/design.md): the full design and implementation writeup
  (rules, economy, crafting orders, interface, implementation plan, open questions)
- [docs/wow-forever-api-notes.md](docs/wow-forever-api-notes.md): the WoW Forever UI and
  API facts the addon relies on, read from Blizzard's UI source (build 1.60.1.70450)

## Figures

[docs/figures/anvil/anvil.html](docs/figures/anvil/anvil.html) is an interactive figure of
the rules: a drop hammer draws one of 20 tokens per strike, the tray shows the odds for the
current quality, the hearth fills toward Frenzy and the post shows the level. It runs on
[model.mjs](docs/figures/anvil/model.mjs), the same v0.3 numbers as the playtest engine.
Download the file and open it in a browser: click or Space strikes, S sells.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/anvil-dark.gif">
  <img alt="Fig 1, the anvil: ten strikes take a gray blade to blue +14, with a Frenzy, then it sells" src="docs/images/anvil-light.gif">
</picture>

The GIF is one seeded run: ten strikes take a gray blade to blue +14 (a crack, three quality
step and a 3-strike Frenzy), then it sells.

Rebuild the page with `node docs/figures/anvil/build.mjs` (Node 18+) and the GIFs with
`node docs/figures/anvil/record.mjs` (needs Playwright and ffmpeg). It is drawn with the
[Anatomy](https://github.com/wheresryan22/anatomy) isometric kit (MIT), vendored in
`docs/figures/vendor/anatomy`.

## Playtest tools

Small Python scripts used to test the rules before the Lua version exists.

```sh
cd tools/playtest
python3 forge.py new --name "Tattered Boots" --quality gray --ilvl 20 --kind armor --seed 2026
python3 forge.py swing 5
python3 forge.py sell
python3 ev_per_swing.py   # expected value of one more swing per quality
```

## Layout

```
docs/            design writeup, API notes, diagrams
docs/figures/    interactive figures and the code that builds them
tools/playtest/  Python playtest engine and balance scripts
```

The addon itself (`Forgeborn_Forever.toc` and the Lua files) will live at the
repository root once development starts.
