-- The window layout: UI/Layout.lua drives the window, and the layout editor (tools/layout-editor) starts from it.
local T = ...
local Mock = dofile("tests/wowmock.lua")

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- How many numbers each entry has (see the comment at the top of UI/Layout.lua).
local SIZES = {
	window = 2, anvil = 4, storage = 4, orders = 4, gold = 3, shopHint = 3, shop = 4,
	nextSwing = 3, embers = 3, pips = 4, odds = 4, anvilSlot = 3, itemName = 3, itemInfo = 3, itemValue = 3, status = 3,
	forge = 4, sell = 4,
	workbenchTitle = 3, workbench = 3, shelfTitle = 3, shelf = 3, suppliesTitle = 3, supplies = 3, newTool = 3,
	newToolText = 3, displayTitle = 3, trophyBonus = 3, display = 3,
	ordersTitle = 3, waiting = 3, cards = 5,
	cardHeader = 3, cardAsk = 3, cardRange = 3, cardReward = 3, cardSlot = 3, cardSend = 4, cardReject = 4, cardEmpty = 3,
}

T.test("the layout editor starts from UI/Layout.lua (run tools/layout-editor/sync.py after editing it)", function()
	local html = read("tools/layout-editor/index.html")
	local embedded = html:match("%-%- layout:start\n(.-)%-%- layout:end")
	T.ok(embedded, "the editor holds a copy of the layout")
	T.ok(embedded == read("UI/Layout.lua"), "the editor's copy differs from UI/Layout.lua")
end)

T.test("every layout entry has the right number of values", function()
	local ns = T.loadAddonFiles({ "UI/Layout.lua" })
	local count = 0
	for key, values in pairs(ns.Layout) do
		count = count + 1
		T.ok(SIZES[key], "unknown layout entry " .. key)
		T.eq(#values, SIZES[key], key)
		for i, v in ipairs(values) do
			T.ok(type(v) == "number" and v == math.floor(v), key .. "[" .. i .. "] is a whole number")
		end
	end
	for key in pairs(SIZES) do
		T.ok(ns.Layout[key], "missing layout entry " .. key)
	end
end)

T.test("the window is built where the layout says", function()
	local client = Mock.New()
	client:LoadAddon()
	local ns = client.ns
	-- Move a few things, as the editor would, before the window is built.
	ns.Layout.forge = { 20, 200, 150, 40 }
	ns.Layout.anvilSlot = { 100, 90, 74 }
	ns.Layout.workbench = { 10, 40, 50 }
	client:Login(nil)
	client.env.SlashCmdList.FORGEBORN("")
	local parts = ns.UI.parts
	T.eq(parts.frame:GetWidth(), ns.Layout.window[1]); T.eq(parts.frame:GetHeight(), ns.Layout.window[2])
	local forge = parts.anvil.forge
	T.eq(forge:GetWidth(), 150); T.eq(forge:GetHeight(), 40)
	local p = forge.__points.TOPLEFT
	T.eq(p[3], 20); T.eq(p[4], -200)
	local slot = parts.anvil.slot
	T.eq(slot:GetScale(), 2, "a 74 px anvil slot is a 37 px slot at scale 2")
	T.eq(slot.__points.TOPLEFT[3], 50, "offsets are in the slot's own scale"); T.eq(slot.__points.TOPLEFT[4], -45)
	T.eq(parts.bench[3].__points.TOPLEFT[3], 10 + 2 * 50, "the third Workbench slot, two steps along")
	T.eq(parts.bench[3].__points.TOPLEFT[4], -40)
end)
