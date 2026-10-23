# Forgeborn layout in Figma

Two ways to get the addon's main window into Figma. Both use the positions in `UI/Layout.lua`.

## The plugin: edit in Figma, bring it back to the addon

The plugin draws the window as normal Figma layers and reads your changes back as `UI/Layout.lua`.

**Install once** (development plugins need the [Figma desktop app](https://www.figma.com/downloads/), which is free):

1. Get this repository (GitHub → Code → Download ZIP) and unzip it.
2. In the Figma desktop app, open any design file.
3. Menu → **Plugins → Development → Import plugin from manifest…** and pick `tools/figma-plugin/manifest.json`.

**Use it:**

1. Menu → **Plugins → Development → Forgeborn Layout**.
2. **Build window**: the window appears as a frame called "Forgeborn window" (English or German texts, 4 or 5 order cards).
3. Move and resize things. Each layer the addon uses is named after its `Layout.lua` entry (`forge`, `nextSwing`, `workbench` …); keep those names.
   - Text layers: only their position and width count; the height follows the font in game.
   - Item rows (`workbench`, `shelf`, `supplies`, `display`): change the gap in the auto layout panel.
   - Order cards: edit `card-1`, the main component; the other cards follow it.
   - Locked layers (labels, bar segments, the title) are decoration.
4. **Read layout**, then **Copy Lua**, and paste it over `UI/Layout.lua` in the addon folder. In game: `/reload`.

The plugin lists what changed and anything it couldn't find (renamed or deleted layers keep their old values).

## The SVG: just open it

[`forgeborn-window.svg`](forgeborn-window.svg) is the same window as an SVG. Drag it into Figma (desktop or browser), or press **Copy for Figma** in the [layout editor](../layout-editor/index.html) and paste into Figma. Every element is a group named after its `Layout.lua` entry, with a `<name>-box` rectangle as its layout box. The plugin can read a window imported this way too, as long as the group names and their `-box` rectangles stay; move whole groups rather than single pieces.

## For developers

`code.js` and `forgeborn-window.svg` are generated: `node tools/figma-plugin/build.js` puts the layout editor's core (the element list, Lua reading and writing, samples, colours), `UI/Layout.lua` and `main.js` together. `python3 tools/layout-editor/sync.py` runs it after a layout change, and `tests/test_layout.lua` fails when they are out of date.

`node tools/figma-plugin/test.js` runs the plugin against a small fake of the Figma API: build, edit and read back; German and 5 cards; a missing font; a window imported from the SVG. It has not run in a real Figma yet.
