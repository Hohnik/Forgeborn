-- Branch retail-test: the addon as the retail client runs it (retail's own widget list, retail item levels,
-- no Forever-only template), plus the /forge test commands.
local T = ...
local Mock = dofile("tests/wowmock.lua")

local ITEMS = {
	GREAVES = { id = 2001, name = "Voidtouched Greaves", quality = 3, ilvl = 642, equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 4 },
	BLADE = { id = 2002, name = "Notched Blade", quality = 2, ilvl = 640, equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 },
	ROBE = { id = 2003, name = "Threadbare Robe", quality = 0, ilvl = 600, equipLoc = "INVTYPE_ROBE", classID = 4, subclassID = 1 },
	TRINKET = { id = 2004, name = "Shiny Trinket", quality = 3, ilvl = 645, equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0 },
}

local function newClient()
	local client = Mock.New({ project = "retail", widgets = "tests/fixtures/retail_widgets.lua", level = 80, avgItemLevel = 645 })
	for _, def in pairs(ITEMS) do
		local copy = {}
		for k, v in pairs(def) do
			copy[k] = v
		end
		client:DefineItem(copy)
	end
	client:LoadAddon()
	return client
end

local function chatHas(client, text)
	for _, line in ipairs(client.chat) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function benchCount(db)
	local n = 0
	for slot = 1, 4 do
		if db.workbench[slot] then
			n = n + 1
		end
	end
	return n
end

T.test("[retail] the TOC targets retail and loads the test commands", function()
	local toc = assert(io.open("Forgeborn.toc")):read("*a")
	T.ok(toc:find("## Interface: 120105", 1, true), "retail 12.1.5 interface number")
	T.ok(toc:find("## AllowLoadGameType: standard", 1, true), "loads in retail only")
	T.ok(toc:find("TestTools.lua", 1, true))
	local client = newClient()
	client:Login(nil)
	T.ok(client.ns.Compat.isRetail)
	T.ok(chatHas(client, "Retail test build"), "says it is the test build")
end)

T.test("[retail] the whole game plays with retail's own widgets", function()
	local client = newClient()
	client:Login(nil)
	local ns, env = client.ns, client.env
	env.SlashCmdList.FORGEBORN("")
	local parts = ns.UI.parts
	T.ok(env.ForgebornFrame:IsShown())
	-- Loot, forge, sell.
	client:OpenLoot({ ITEMS.GREAVES.id, ITEMS.TRINKET.id })
	client:TakeLoot()
	T.eq(benchCount(ns.db), 1, "the trinket doesn't count")
	parts.bench[1]:Click("LeftButton")
	T.eq(ns.db.anvil.itemLevel, 642)
	for _ = 1, 5 do
		if ns.db.anvil then
			parts.anvil.forge:Click()
		end
	end
	if ns.db.anvil then
		parts.anvil.sell:Click()
		T.ok(ns.db.gold > 0)
	end
	-- Orders ask around the average equipped item level.
	local order = ns.db.orders.daily[1]
	T.eq(order.ilvlMin, 635)
	T.eq(order.ilvlMax, 655)
	-- Hand in a fitting item.
	ns.db.orders.daily = {}
	order = ns.Orders.Generate(false, "THORIUM")
	order.group, order.armorType, order.minQuality = "ONEHAND", nil, 2
	table.insert(ns.db.orders.daily, order)
	client:OpenLoot({ ITEMS.BLADE.id })
	client:TakeLoot()
	ns.Changed()
	local slot
	for i = 1, 4 do
		if ns.db.workbench[i] and ns.db.workbench[i].itemID == ITEMS.BLADE.id then
			slot = i
		end
	end
	client:Drag(parts.bench[slot], ns.UI.cards[1].slot)
	ns.UI.cards[1].send:Click()
	T.eq(ns.db.rep.THORIUM, 500)
	-- The Shop with a plain status bar for reputation.
	ns.db.gold = 10000000
	parts.shop:Click()
	local shop = ns.Shop.parts
	ns.Economy.Random = function(n) return n end
	shop.rows[1].buy:Click()
	client:AcceptPopup()
	T.ok(shop.reveal.text:IsShown())
	for tab = 2, 5 do
		env["ForgebornShopFrameTab" .. tab]:Click()
		T.eq(shop.header.bar:GetObjectType(), "StatusBar")
	end
	-- Combat.
	client.combat = true
	env.ForgebornFrame.CloseButton:Click()
	shop.frame.CloseButton:Click()
	T.ok(not env.ForgebornFrame:IsShown() and not shop.frame:IsShown())
end)

T.test("[retail] /forge test commands", function()
	local client = newClient()
	client:Login(nil)
	local ns, env = client.ns, client.env
	local forge = env.SlashCmdList.FORGEBORN
	-- drop: bag items that were never looted.
	client:GiveItem(ITEMS.GREAVES.id)
	client:GiveItem(ITEMS.TRINKET.id)
	client:GiveItem(ITEMS.BLADE.id)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(ns.db), 0, "not looted, so not on the Workbench")
	forge("test drop 5")
	T.eq(benchCount(ns.db), 2, "greaves and blade, not the trinket")
	forge("test drop " .. client.items[ITEMS.TRINKET.id].link)
	T.ok(client:LastChat():find("not a weapon or armour", 1, true))
	forge("test drop " .. client.items[ITEMS.ROBE.id].link)
	T.eq(benchCount(ns.db), 3)
	-- gold, rep, orders.
	forge("test gold 50")
	T.eq(ns.db.gold, 500000)
	forge("test rep city 9000")
	T.eq(ns.db.rep.CITY, 9000)
	T.eq(ns.Economy.DailySlots(), 4)
	forge("test rep nobody 5")
	T.ok(client:LastChat():find("Usage", 1, true))
	local before = ns.db.orders.nextID
	forge("test orders")
	T.eq(ns.db.orders.nextID, before + 1, "a new daily (the weekly slot is taken)")
	-- anvil helpers.
	forge("test level 3")
	T.ok(client:LastChat():find("anvil first", 1, true))
	ns.Forge.PutOnAnvil(1)
	forge("test level 13")
	T.eq(ns.db.anvil.level, 13)
	forge("test embers")
	T.eq(ns.db.anvil.embers, 6)
	ns.Forge.Random = function(n) return n end
	ns.Forge.Strike()
	T.eq(ns.db.anvil.frenzy, 3, "the next swing fired Frenzy")
	-- tools and stones.
	forge("test tool fiery_core 4")
	T.eq(ns.db.shelf[1].id, "FIERY_CORE")
	T.eq(ns.db.shelf[1].rank, 4)
	forge("test tool nope")
	T.ok(client:LastChat():find("Usage", 1, true))
	forge("test stones 2")
	T.eq(ns.db.consumables.COARSE_STONE, 2)
	T.eq(ns.db.consumables.DENSE_STONE, 2)
	-- state, help, and normal commands still work.
	local lines = #client.chat
	forge("test state")
	T.ok(#client.chat >= lines + 6)
	forge("test")
	T.ok(client:LastChat():find("/forge test state", 1, true))
	forge("TEST GOLD 1")
	T.eq(ns.db.gold, 510000)
	forge("")
	T.ok(env.ForgebornFrame:IsShown(), "/forge still opens the window")
	forge("records")
	T.ok(chatHas(client, ns.L.RECORDS))
end)
