// Runs the Figma plugin (code.js) against a small fake of the Figma plugin API:
//   - build the window, read it back: UI/Layout.lua comes out unchanged
//   - move and resize layers like a user would: the changes come back as Lua
//   - German, 5 cards, and a missing font still build
//   - a window imported from forgeborn-window.svg reads back as UI/Layout.lua
// Run: node tools/figma-plugin/test.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const here = __dirname;
const LAYOUT = fs.readFileSync(path.join(here, "..", "..", "UI", "Layout.lua"), "utf8");
const CODE = fs.readFileSync(path.join(here, "code.js"), "utf8");

// ---------------------------------------------------------------------------
// The fake Figma API: only what the plugin uses, with auto layout and absolute positions.
// ---------------------------------------------------------------------------

class Leaf {
	constructor(type) {
		Object.assign(this, { type, name: "", parent: null, _x: 0, _y: 0, width: 100, height: 100, visible: true, locked: false, fills: [], strokes: [] });
	}
	get x() { return this._x; }
	set x(v) { if (!autoLayout(this.parent)) this._x = v; }
	get y() { return this._y; }
	set y(v) { if (!autoLayout(this.parent)) this._y = v; }
	resize(w, h) {
		assert(w > 0 && h > 0, "resize to " + w + "x" + h);
		this.width = w;
		this.height = h;
		if (this.parent) this.parent.relayout();
	}
	get absoluteTransform() {
		let x = this._x, y = this._y;
		for (let p = this.parent; p && p.type !== "PAGE"; p = p.parent) {
			if (p.type !== "GROUP") {
				x += p._x;
				y += p._y;
			}
		}
		return [[1, 0, x], [0, 1, y]];
	}
	clone() {
		const copy = new this.constructor(this.type);
		for (const [k, v] of Object.entries(this)) if (k !== "parent" && k !== "children") copy[k] = JSON.parse(JSON.stringify(v));
		return copy;
	}
}

function autoLayout(node) {
	return node && node._layoutMode && node._layoutMode !== "NONE";
}

class Text extends Leaf {
	constructor() {
		super("TEXT");
		Object.assign(this, { fontName: null, characters: "", fontSize: 12, ranges: [], _autoResize: "NONE" });
	}
	setRangeFills(start, end, fills) {
		assert(start >= 0 && end <= this.characters.length && start < end, "range " + start + "-" + end);
		this.ranges.push([start, end, fills]);
	}
	get textAutoResize() { return this._autoResize; }
	set textAutoResize(v) {
		this._autoResize = v;
		if (v === "WIDTH_AND_HEIGHT") this.width = Math.max(1, this.characters.length * this.fontSize * 0.5);
	}
}

class Container extends Leaf {
	constructor(type) {
		super(type || "FRAME");
		Object.assign(this, { children: [], _layoutMode: "NONE", _itemSpacing: 0, _primary: "FIXED", _counter: "FIXED", clipsContent: true });
	}
	appendChild(child) {
		if (child.parent) child.parent.children.splice(child.parent.children.indexOf(child), 1);
		child.parent = this;
		this.children.push(child);
		this.relayout();
	}
	get layoutMode() { return this._layoutMode; }
	set layoutMode(v) { this._layoutMode = v; this.relayout(); }
	get itemSpacing() { return this._itemSpacing; }
	set itemSpacing(v) { this._itemSpacing = v; this.relayout(); }
	get primaryAxisSizingMode() { return this._primary; }
	set primaryAxisSizingMode(v) { this._primary = v; this.relayout(); }
	get counterAxisSizingMode() { return this._counter; }
	set counterAxisSizingMode(v) { this._counter = v; this.relayout(); }
	relayout() {
		if (autoLayout(this)) {
			const across = this._layoutMode === "HORIZONTAL";
			let pos = 0, cross = 0;
			const shown = this.children.filter(c => c.visible);
			for (const c of shown) {
				if (across) { c._x = pos; c._y = 0; pos += c.width + this._itemSpacing; cross = Math.max(cross, c.height); }
				else { c._x = 0; c._y = pos; pos += c.height + this._itemSpacing; cross = Math.max(cross, c.width); }
			}
			if (shown.length) pos -= this._itemSpacing;
			if (this._primary === "AUTO") across ? (this.width = pos) : (this.height = pos);
			if (this._counter === "AUTO") across ? (this.height = cross) : (this.width = cross);
		}
		if (this.parent && this.parent.relayout) this.parent.relayout();
	}
	findAll(test) {
		const out = [];
		const walk = n => { for (const c of n.children || []) { if (test(c)) out.push(c); walk(c); } };
		walk(this);
		return out;
	}
	findOne(test) {
		return this.findAll(test)[0] || null;
	}
	clone() {
		const copy = super.clone();
		copy.children = [];
		for (const c of this.children) {
			const cc = c.clone();
			cc.parent = copy;
			copy.children.push(cc);
		}
		return copy;
	}
	createInstance() {
		assert.strictEqual(this.type, "COMPONENT");
		const inst = this.clone();
		inst.type = "INSTANCE";
		inst.mainComponent = this;
		inst._x = 0;
		inst._y = 0;
		return inst;
	}
}

function fakeFigma(options) {
	const messages = [];
	const page = new Container("PAGE");
	page.selection = [];
	const figma = {
		createFrame: () => new Container("FRAME"),
		createComponent: () => new Container("COMPONENT"),
		createRectangle: () => new Leaf("RECTANGLE"),
		createEllipse: () => new Leaf("ELLIPSE"),
		createText: () => new Text(),
		loadFontAsync: async f => {
			if (options && options.noMarcellus && f.family === "Marcellus") throw new Error("font not available");
		},
		currentPage: page,
		viewport: { center: { x: 400, y: 300 }, scrollAndZoomIntoView() {} },
		showUI() {},
		ui: { postMessage: m => messages.push(JSON.parse(JSON.stringify(m))), onmessage: null }, // Figma serializes messages too
		notify() {},
		closePlugin() {},
	};
	vm.runInNewContext(CODE, { figma, __html__: "<div></div>", console });
	return { figma, page, messages, last: type => messages.filter(m => m.type === type).pop() };
}

function luaValues(text) {
	const out = {};
	for (const m of text.matchAll(/\t(\w+) = \{ ([^}]*) \}/g)) out[m[1]] = m[2].split(", ").map(Number);
	return out;
}

let passed = 0;
async function test(name, fn) {
	await fn();
	passed++;
	console.log("ok  " + name);
}

(async () => {
	await test("init sends the default layout", async () => {
		const f = fakeFigma();
		assert.strictEqual(f.last("init").lua, LAYOUT);
	});

	await test("build, then read: UI/Layout.lua comes back unchanged", async () => {
		const f = fakeFigma();
		await f.figma.ui.onmessage({ type: "build", lua: LAYOUT, lang: "en", cards: 4 });
		assert(!f.last("error"), f.last("error") && f.last("error").text);
		const root = f.page.children[0];
		assert.strictEqual(root.name, "Forgeborn window");
		assert.strictEqual(root.width, 780);
		const cards = root.findOne(n => n.name === "cards");
		assert.deepStrictEqual(cards.children.map(c => c.type), ["COMPONENT", "INSTANCE", "INSTANCE", "INSTANCE"]);
		assert.strictEqual(cards.children[2].findOne(n => n.name === "cardEmpty").visible, true, "card 3 is the empty one");
		assert.strictEqual(cards.children[2].findOne(n => n.name === "cardAsk").visible, false);
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		const r = f.last("read");
		assert.deepStrictEqual(r.missing, []);
		assert.deepStrictEqual(r.changed, []);
		assert.strictEqual(r.lua, LAYOUT);
	});

	await test("edits in Figma come back as Lua", async () => {
		const f = fakeFigma();
		await f.figma.ui.onmessage({ type: "build", lua: LAYOUT, lang: "en", cards: 4 });
		const root = f.page.children[0];
		const find = name => root.findOne(n => n.name === name);
		const forge = find("forge");
		forge.x += 10;
		forge.resize(200, 40);
		find("nextSwing").resize(220, 15);
		find("workbench").itemSpacing = 10; // gap 10 -> step 47
		find("anvil").x += 5; // the box moves; what's inside keeps its place in it
		const cards = find("cards");
		cards.itemSpacing = 6;
		cards.children[0].resize(334, 90); // card-1, the component
		cards.children[0].findOne(n => n.name === "cardSend").x -= 2;
		root.resize(800, 600);
		f.page.selection = [forge];
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		const r = f.last("read");
		const v = luaValues(r.lua), old = luaValues(LAYOUT);
		assert.deepStrictEqual(v.forge, [22, 226, 200, 40]);
		assert.deepStrictEqual(v.nextSwing, [12, 10, 220]);
		assert.deepStrictEqual(v.workbench, [14, 30, 47]);
		assert.deepStrictEqual(v.anvil, [13, 60, 404, 268]);
		assert.deepStrictEqual(v.cards, [10, 32, 334, 90, 6]);
		assert.deepStrictEqual(v.cardSend, [170, 56, 74, 22]);
		assert.deepStrictEqual(v.window, [800, 600]);
		assert.deepStrictEqual(r.changed.sort(), ["anvil", "cardSend", "cards", "forge", "nextSwing", "window", "workbench"]);
		for (const k of Object.keys(old)) if (!r.changed.includes(k)) assert.deepStrictEqual(v[k], old[k], k);
	});

	await test("German, 5 cards and no Marcellus font still build and read back", async () => {
		const f = fakeFigma({ noMarcellus: true });
		await f.figma.ui.onmessage({ type: "build", lua: LAYOUT, lang: "de", cards: 5 });
		assert(!f.last("error"), f.last("error") && f.last("error").text);
		const root = f.page.children[0];
		assert.strictEqual(root.findOne(n => n.name === "forge").findOne(n => n.name === "label").characters, "Schmieden");
		assert.strictEqual(root.findOne(n => n.name === "nextSwing").fontName.family, "Inter");
		assert.strictEqual(root.findOne(n => n.name === "cards").children.length, 5);
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		assert.strictEqual(f.last("read").lua, LAYOUT);
	});

	await test("a second build goes next to the first; reading uses the selected one", async () => {
		const f = fakeFigma();
		await f.figma.ui.onmessage({ type: "build", lua: LAYOUT, lang: "en", cards: 4 });
		await f.figma.ui.onmessage({ type: "build", lua: LAYOUT, lang: "en", cards: 4 });
		const [a, b] = f.page.children;
		assert(b.x >= a.x + a.width, "not on top of the first");
		b.findOne(n => n.name === "sell").x += 4;
		f.page.selection = [b.findOne(n => n.name === "sell")];
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		assert.deepStrictEqual(f.last("read").changed, ["sell"]);
	});

	await test("no window: a clear error", async () => {
		const f = fakeFigma();
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		assert(/No Forgeborn window/.test(f.last("error").text));
	});

	await test("a window imported from forgeborn-window.svg reads back as UI/Layout.lua", async () => {
		const f = fakeFigma();
		const svg = fs.readFileSync(path.join(here, "forgeborn-window.svg"), "utf8");
		// Figma turns the SVG into a frame; <g id> become groups and <rect id> rectangles named after their ids.
		const frame = new Container("FRAME");
		frame.name = "forgeborn-window";
		f.page.appendChild(frame);
		frame._x = 1500;
		frame._y = 200;
		const view = svg.match(/viewBox="(-?[\d.]+) (-?[\d.]+)/);
		const ox = -Number(view[1]), oy = -Number(view[2]);
		const stack = [frame];
		for (const m of svg.matchAll(/<(\/?)(\w+)([^>]*?)(\/?)>/g)) {
			const [, closing, tag, attrs, selfClosing] = m;
			const attr = name => { const a = attrs.match(new RegExp(" " + name + '="([^"]*)"')); return a ? a[1] : null; };
			if (tag === "g") {
				if (closing) stack.pop();
				else {
					const g = new Container("GROUP");
					g.name = attr("id") || "Group";
					stack[stack.length - 1].appendChild(g);
					stack.push(g);
				}
			} else if (tag === "rect" && !closing) {
				const r = new Leaf("RECTANGLE");
				r.name = attr("id") || "Rectangle";
				stack[stack.length - 1].appendChild(r);
				r._x = Number(attr("x")) + ox;
				r._y = Number(attr("y")) + oy;
				r.width = Number(attr("width"));
				r.height = Number(attr("height"));
			}
			void selfClosing;
		}
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		const r = f.last("read");
		assert.deepStrictEqual(r.missing, []);
		assert.deepStrictEqual(r.changed, []);
		assert.strictEqual(r.lua, LAYOUT);
		// Move the Shop button's group in "Figma": it comes back.
		for (const n of frame.findOne(n => n.name === "shop").children) n._x += 3;
		f.figma.ui.onmessage({ type: "read", lua: LAYOUT });
		assert.deepStrictEqual(f.last("read").changed, ["shop"]);
	});

	console.log(passed + " passed");
})().catch(err => {
	console.error("FAIL", err);
	process.exit(1);
});
