// Forgeborn layout plugin for Figma.
//
// "Build window" draws the addon's main window from UI/Layout.lua as ordinary Figma layers: a frame per box, button,
// bar and slot, a text layer per label, auto layout rows for the item slots, and the order cards as one component
// ("card-1") with instances. Every layer the addon reads is named after its Layout.lua key ("forge", "nextSwing").
// "Read layout" measures those layers and writes UI/Layout.lua again. It also reads a window that was pasted or
// dropped in as SVG (the web editor's "Copy for Figma", or forgeborn-window.svg): there each element is a group
// named after its key, and its "<key>-box" rectangle is its layout box.
//
// build.js puts the layout editor's core (ENTRIES, toLua, fromLua, samples, WOW colours) and DEFAULT_LUA in front of
// this file to make code.js. Plain ES2017: no optional chaining, no object spread.

var WINDOW_NAME = "Forgeborn window";
var FONT_UI = { family: "Inter", style: "Regular" };
var font = FONT_UI;

function emptyValues() {
	var v = {};
	KEYS.forEach(function (k) {
		v[k] = [];
		for (var i = 0; i < SIZES[BY_KEY[k].kind]; i++) v[k].push(0);
	});
	return v;
}
var DEFAULTS = fromLua(DEFAULT_LUA, emptyValues()).values;

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

function rgb(hex) {
	var n = parseInt(hex.slice(1), 16);
	return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 };
}

function solid(hex, opacity) {
	var paint = { type: "SOLID", color: rgb(hex) };
	if (opacity !== undefined) paint.opacity = opacity;
	return paint;
}

function stroke(node, hex, weight) {
	node.strokes = [solid(hex)];
	node.strokeWeight = weight;
	node.strokeAlign = "INSIDE";
}

function inAutoLayout(parent) {
	return parent.layoutMode !== undefined && parent.layoutMode !== "NONE";
}

function place(node, parent, x, y) {
	parent.appendChild(node);
	if (!inAutoLayout(parent)) {
		node.x = x;
		node.y = y;
	}
}

function frame(name, parent, x, y, w, h, fills) {
	var f = figma.createFrame();
	f.name = name;
	f.fills = fills || [];
	f.clipsContent = false;
	f.resize(Math.max(1, w), Math.max(1, h));
	place(f, parent, x, y);
	return f;
}

function rectangle(name, parent, x, y, w, h, fills) {
	var r = figma.createRectangle();
	r.name = name;
	r.fills = fills;
	r.resize(Math.max(0.01, w), Math.max(0.01, h));
	place(r, parent, x, y);
	return r;
}

async function loadFonts() {
	await figma.loadFontAsync(FONT_UI);
	try {
		await figma.loadFontAsync({ family: WOW.font, style: "Regular" });
		font = { family: WOW.font, style: "Regular" };
	} catch (e) {
		font = FONT_UI;
	}
}

// Sets a text layer's characters and colours from runs ([{ text, color }]).
function setRuns(t, runs, baseColor) {
	var chars = runs.map(function (r) { return r.text; }).join("");
	t.characters = chars.length ? chars : " ";
	t.fills = [solid(baseColor)];
	var i = 0;
	runs.forEach(function (r) {
		if (r.color && r.text.length) t.setRangeFills(i, i + r.text.length, [solid(r.color)]);
		i += r.text.length;
	});
}

// A text layer. width 0 = as wide as its text.
function textLayer(name, parent, x, y, width, runs, fontKey, align) {
	var spec = WOW.fonts[fontKey];
	var t = figma.createText();
	t.fontName = font;
	t.fontSize = spec[0];
	t.lineHeight = { value: spec[1], unit: "PIXELS" };
	setRuns(t, runs, WOW[spec[2]]);
	t.textAlignHorizontal = align === "center" ? "CENTER" : align === "right" ? "RIGHT" : "LEFT";
	place(t, parent, x, y);
	if (width) {
		t.resize(Math.max(1, width), spec[1]);
		t.textAutoResize = "HEIGHT";
	} else {
		t.textAutoResize = "WIDTH_AND_HEIGHT";
	}
	t.name = name;
	return t;
}

// An item slot; the icon is always there (hidden when empty) so order card instances can show one.
function slotFrame(name, parent, x, y, size, item) {
	var f = frame(name, parent, x, y, size, size, [solid(WOW.slot)]);
	f.cornerRadius = 3;
	stroke(f, WOW.slotEdge, 1);
	var icon = rectangle("icon", f, 2, 2, size - 4, size - 4, [solid(item ? WOW.icons[item[0]] : WOW.slot)]);
	icon.cornerRadius = 2;
	stroke(icon, WOW.quality[item ? item[1] : 0], 1.5);
	icon.constraints = { horizontal: "STRETCH", vertical: "STRETCH" };
	icon.visible = !!item;
	return f;
}

function setSlotItem(slot, item) {
	var icon = slot.findOne(function (n) { return n.name === "icon"; });
	if (!icon) return;
	icon.visible = !!item;
	if (item) {
		icon.fills = [solid(WOW.icons[item[0]])];
		stroke(icon, WOW.quality[item[1]], 1.5);
	}
}

function buildElement(e, v, parent, lang, card) {
	var f, i;
	if (e.kind === "box") {
		f = frame(e.key, parent, v[0], v[1], v[2], v[3], [solid(WOW.inset)]);
		f.cornerRadius = 2;
		stroke(f, WOW.insetEdge, 1);
		return f;
	}
	if (e.kind === "text") {
		var t = textLayer(e.key, parent, v[0], v[1], v[2], textRuns(sampleText(e, lang, card)), e.font, e.align);
		if (e.wrap === false) {
			try {
				t.textTruncation = "ENDING";
				t.maxLines = 1;
			} catch (err) { /* older Figma: the text just wraps */ }
		}
		return t;
	}
	if (e.kind === "button") {
		f = frame(e.key, parent, v[0], v[1], v[2], v[3], [solid(e.big ? WOW.buttonBig : WOW.button)]);
		f.cornerRadius = 4;
		stroke(f, WOW.edge, 1);
		var label = textLayer("label", f, 0, 0, 0, [{ text: e.text[lang], color: null }], "normal", "center");
		label.fontSize = e.big ? 15 : 12.5;
		label.x = (v[2] - label.width) / 2;
		label.y = (v[3] - label.height) / 2;
		label.constraints = { horizontal: "CENTER", vertical: "CENTER" };
		label.locked = true;
		return f;
	}
	if (e.kind === "bar") {
		f = frame(e.key, parent, v[0], v[1], v[2], v[3], [solid("#000000", 0.5)]);
		var x = 0;
		ODDS.forEach(function (o) {
			var w = v[2] * o[2] / 100;
			var seg = rectangle("segment", f, x, 0, w, v[3], [solid(o[3])]);
			seg.constraints = { horizontal: "SCALE", vertical: "STRETCH" };
			seg.locked = true;
			var pct = textLayer("percent", f, x, (v[3] - 13) / 2, w, [{ text: o[2] + "%", color: null }], "highlightSmall", "center");
			pct.constraints = { horizontal: "SCALE", vertical: "CENTER" };
			pct.locked = true;
			var lab = textLayer("outcome", f, x, v[3] + 3, w, [{ text: lang === "de" ? o[1] : o[0], color: null }], "disableSmall", "center");
			lab.constraints = { horizontal: "SCALE", vertical: "MAX" };
			lab.locked = true;
			x += w;
		});
		return f;
	}
	if (e.kind === "pips") {
		f = frame(e.key, parent, v[0], v[1], v[2], v[3], []);
		var size = v[3], step = (v[2] - size) / 6;
		for (i = 0; i < 7; i++) {
			var pip = figma.createEllipse();
			pip.name = "ember " + (i + 1);
			pip.resize(size, size);
			pip.fills = [solid(i < 3 ? WOW.pipOn : WOW.pipOff)];
			stroke(pip, "#000000", size / 6);
			place(pip, f, i * step, 0);
			pip.constraints = { horizontal: "SCALE", vertical: "SCALE" };
			pip.locked = true;
		}
		return f;
	}
	if (e.kind === "slot") {
		return slotFrame(e.key, parent, v[0], v[1], v[2], e.sample === "slot" ? (card && card.slot) : [e.icon, e.quality]);
	}
	if (e.kind === "row") {
		f = frame(e.key, parent, v[0], v[1], (e.count - 1) * v[2] + SLOT, SLOT, []);
		f.layoutMode = "HORIZONTAL";
		f.primaryAxisSizingMode = "AUTO";
		f.counterAxisSizingMode = "AUTO";
		f.itemSpacing = v[2] - SLOT;
		for (i = 0; i < e.count; i++) slotFrame(e.key + "-" + (i + 1), f, 0, 0, SLOT, e.items[i]);
		return f;
	}
	return null;
}

// The order cards: card-1 is a component (edit it; the others follow), cards 2.. are instances with sample texts.
function buildCards(values, orders, lang, cardCount) {
	var c = values.cards;
	var stack = frame("cards", orders, c[0], c[1], c[2], c[3], []);
	stack.layoutMode = "VERTICAL";
	stack.primaryAxisSizingMode = "AUTO";
	stack.counterAxisSizingMode = "AUTO";
	stack.itemSpacing = c[4];
	var list = cardSamples(cardCount);
	var comp = figma.createComponent();
	comp.name = "card-1";
	comp.description = "Order card. Edit this one; the other cards follow it.";
	comp.fills = [solid(WOW.inset)];
	comp.cornerRadius = 2;
	stroke(comp, WOW.insetEdge, 1);
	comp.clipsContent = false;
	comp.resize(c[2], c[3]);
	stack.appendChild(comp);
	var cardEntries = ENTRIES.filter(function (e) { return e.parent === "card"; });
	cardEntries.forEach(function (e) {
		var sample = e.key === "cardEmpty" ? null : list[0];
		var node = buildElement(e, values[e.key], comp, lang, sample);
		node.visible = (e.key === "cardEmpty") === !!list[0].empty;
	});
	for (var i = 1; i < list.length; i++) {
		var inst = comp.createInstance();
		inst.name = "card-" + (i + 1);
		stack.appendChild(inst);
		fillCard(inst, list[i], lang, cardEntries);
	}
}

function fillCard(inst, card, lang, cardEntries) {
	cardEntries.forEach(function (e) {
		var node = inst.findOne(function (n) { return n.name === e.key; });
		if (!node) return;
		var show = (e.key === "cardEmpty") === !!card.empty;
		node.visible = show;
		if (!show) return;
		if (e.kind === "text") setRuns(node, textRuns(sampleText(e, lang, card)), WOW[WOW.fonts[e.font][2]]);
		if (e.kind === "slot") setSlotItem(node, card.slot);
	});
}

async function build(msg) {
	await loadFonts();
	var parsed = fromLua(msg.lua || DEFAULT_LUA, DEFAULTS);
	var values = parsed.values;
	var lang = msg.lang === "de" ? "de" : "en";
	var cardCount = msg.cards === 5 ? 5 : 4;
	var W = values.window[0], H = values.window[1];

	// Next to any window built before, so nothing gets covered.
	var right = null, top = 0;
	figma.currentPage.children.forEach(function (n) {
		if (n.name === WINDOW_NAME && (right === null || n.x + n.width > right)) {
			right = n.x + n.width;
			top = n.y;
		}
	});
	var root = figma.createFrame();
	root.name = WINDOW_NAME;
	root.fills = [solid(WOW.frame)];
	stroke(root, WOW.edge, 3);
	root.cornerRadius = 6;
	root.clipsContent = false;
	root.resize(W, H);
	figma.currentPage.appendChild(root);
	root.x = right === null ? Math.round(figma.viewport.center.x - W / 2) : right + 120;
	root.y = right === null ? Math.round(figma.viewport.center.y - H / 2) : top;

	// Window decoration (locked: not part of the layout).
	var title = textLayer("title", root, 0, 4, W, [{ text: "Forgeborn", color: null }], "normal", "center");
	title.constraints = { horizontal: "STRETCH", vertical: "MIN" };
	title.locked = true;
	var portrait = figma.createEllipse();
	portrait.name = "portrait";
	portrait.resize(62, 62);
	portrait.fills = [solid("#3f4348")];
	stroke(portrait, WOW.edge, 3);
	place(portrait, root, -8, -8);
	portrait.locked = true;
	var close = rectangle("close", root, W - 24, 3, 20, 20, [solid("#7a1208")]);
	close.cornerRadius = 4;
	close.constraints = { horizontal: "MAX", vertical: "MIN" };
	close.locked = true;

	var parents = { window: root };
	ENTRIES.forEach(function (e) {
		if (!e.key || e.key === "window" || e.parent === "card") return;
		if (e.kind === "cards") {
			buildCards(values, parents.orders, lang, cardCount);
			return;
		}
		var node = buildElement(e, values[e.key], parents[e.parent], lang, null);
		if (e.kind === "box") parents[e.key] = node;
	});

	figma.currentPage.selection = [root];
	figma.viewport.scrollAndZoomIntoView([root]);
	figma.ui.postMessage({ type: "built", seen: parsed.seen.length, bad: parsed.bad, unknown: parsed.unknown });
}

// ---------------------------------------------------------------------------
// Reading the layout back
// ---------------------------------------------------------------------------

function canSearch(node) {
	return node && typeof node.findOne === "function";
}

function named(root, name) {
	if (!root) return null;
	if (root.name === name) return root;
	return canSearch(root) ? root.findOne(function (n) { return n.name === name; }) : null;
}

// The layout box of an element: its "<name>-box" rectangle (SVG import), or the layer itself.
function boxOf(node) {
	if (!node) return null;
	var box = canSearch(node) ? node.findOne(function (n) { return n.name === node.name + "-box"; }) : null;
	return box || node;
}

function absBox(node) {
	var t = node.absoluteTransform;
	return { x: t[0][2], y: t[1][2], w: node.width, h: node.height };
}

// The window: the one holding the selection, else the first on the page. Built ("Forgeborn window") or SVG ("window").
function findWindow() {
	var scopes = [];
	var sel = figma.currentPage.selection;
	if (sel.length) {
		var n = sel[0];
		while (n.parent && n.parent.type !== "PAGE") n = n.parent;
		scopes.push(n);
	}
	figma.currentPage.children.forEach(function (c) { scopes.push(c); });
	for (var i = 0; i < scopes.length; i++) {
		var w = named(scopes[i], WINDOW_NAME) || named(scopes[i], "window");
		if (w) return w;
	}
	return null;
}

function measure(e, node, parentBox, old) {
	var b = absBox(boxOf(node));
	var x = Math.round(b.x - parentBox.x), y = Math.round(b.y - parentBox.y);
	var w = Math.round(b.w), h = Math.round(b.h);
	if (e.kind === "text" || e.kind === "slot") return [x, y, w];
	if (e.kind === "row") {
		var s1 = named(node, e.key + "-1"), s2 = named(node, e.key + "-2");
		return [x, y, s1 && s2 ? Math.round(absBox(s2).x - absBox(s1).x) : old[2]];
	}
	if (e.kind === "cards") {
		var c1 = named(node, "card-1"), c2 = named(node, "card-2");
		if (!c1) return [x, y, old[2], old[3], old[4]];
		var b1 = absBox(boxOf(c1));
		var gap = c2 ? Math.round(absBox(boxOf(c2)).y - b1.y - b1.h) : old[4];
		return [x, y, Math.round(b1.w), Math.round(b1.h), gap];
	}
	return [x, y, w, h];
}

function read(msg) {
	var base = fromLua(msg.lua || DEFAULT_LUA, DEFAULTS).values;
	var win = findWindow();
	if (!win) {
		figma.ui.postMessage({ type: "error", text: "No Forgeborn window on this page. Build one first, or select the one you edited." });
		return;
	}
	var winBox = absBox(boxOf(win));
	var parentBox = { window: winBox };
	["anvil", "storage", "orders"].forEach(function (k) {
		var n = named(win, k);
		if (n) parentBox[k] = absBox(boxOf(n));
	});
	var cardsNode = named(win, "cards");
	var cards = [];
	for (var i = 1; cardsNode && named(cardsNode, "card-" + i); i++) cards.push(named(cardsNode, "card-" + i));

	var values = {}, missing = [];
	KEYS.forEach(function (k) {
		var e = BY_KEY[k];
		if (k === "window") {
			values[k] = [Math.round(winBox.w), Math.round(winBox.h)];
			return;
		}
		var node = null, pb = null;
		if (e.parent === "card") {
			// The first card that has it: card-1 (the component) when built here; any card in an SVG import.
			for (var c = 0; c < cards.length && !node; c++) {
				node = named(cards[c], k);
				if (node) pb = absBox(boxOf(cards[c]));
			}
		} else {
			node = named(win, k);
			pb = parentBox[e.parent];
		}
		if (!node || !pb) {
			missing.push(k);
			values[k] = base[k].slice();
			return;
		}
		values[k] = measure(e, node, pb, base[k]);
	});
	var changed = KEYS.filter(function (k) { return values[k].join() !== base[k].join(); });
	figma.ui.postMessage({ type: "read", lua: toLua(values), changed: changed, missing: missing });
}

// ---------------------------------------------------------------------------

function fail(err) {
	figma.ui.postMessage({ type: "error", text: String((err && err.message) || err) });
}

figma.showUI(__html__, { width: 380, height: 660, themeColors: true });
figma.ui.postMessage({ type: "init", lua: DEFAULT_LUA, hasWindow: !!findWindow() });
figma.ui.onmessage = function (msg) {
	if (msg.type === "build") return build(msg).catch(fail);
	if (msg.type === "read") {
		try {
			read(msg);
		} catch (err) {
			fail(err);
		}
	}
	if (msg.type === "close") figma.closePlugin();
};
