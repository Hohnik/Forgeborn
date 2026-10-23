-- Game logic tests, run inside the mock WoW client: loot, Workbench, orders, economy, records, saved data.
local T = ...
local Mock = dofile("tests/wowmock.lua")

local ITEMS = {
	BOOTS = { id = 1001, name = "Tattered Boots", quality = 0, ilvl = 20, equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 2 },
	SWORD = { id = 1002, name = "Rusty Sword", quality = 1, ilvl = 18, equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 },
	SHIRT = { id = 1003, name = "Chain Shirt of the Bear", quality = 2, ilvl = 22, equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3 },
	HELM = { id = 1004, name = "Blue Plate Helm", quality = 3, ilvl = 21, equipLoc = "INVTYPE_HEAD", classID = 4, subclassID = 4 },
	RING = { id = 1005, name = "Silver Ring", quality = 2, ilvl = 20, equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 },
	CLOTH = { id = 1006, name = "Linen Cloth", quality = 1, ilvl = 5, equipLoc = "", classID = 7, subclassID = 5 },
	POLE = { id = 1007, name = "Fishing Pole", quality = 1, ilvl = 10, equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 20 },
	STAFF = { id = 1008, name = "Epic Staff", quality = 4, ilvl = 25, equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 10 },
	GLOVES = { id = 1009, name = "Green Gloves", quality = 2, ilvl = 20, equipLoc = "INVTYPE_HAND", classID = 4, subclassID = 1 },
	SHIRT_BODY = { id = 1010, name = "White Shirt", quality = 1, ilvl = 5, equipLoc = "INVTYPE_BODY", classID = 4, subclassID = 0 },
	CLOAK = { id = 1011, name = "Grey Cloak", quality = 0, ilvl = 15, equipLoc = "INVTYPE_CLOAK", classID = 4, subclassID = 1 },
}

local function newClient(options)
	local client = Mock.New(options)
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

-- A random source that returns the given numbers, then fails.
local function scripted(...)
	local values, i = { ... }, 0
	return function(n)
		i = i + 1
		local v = assert(values[i], "scripted random ran out")
		assert(v >= 1 and v <= n, "scripted value " .. v .. " outside 1.." .. n)
		return v
	end
end

-- A random source for the anvil that lands on the given outcomes in turn ("HIT", "BREAK", ...), whatever the odds
-- of the anvil item are when it swings.
local function outcomes(ns, ...)
	local list, i = { ... }, 0
	return function(n)
		i = i + 1
		local outcome = ns.Data[assert(list[i], "scripted outcomes ran out")]
		local piece, Rules = ns.db.anvil, ns.Rules
		local tickets = Rules.Tickets(Rules.Bag(Rules.PieceGrade(piece), ns.Economy.Mods()))
		local safe, roll = Rules.IsSafe(piece), 1
		for o = ns.Data.BREAK, outcome - 1 do
			if not safe or o >= ns.Data.HIT then
				roll = roll + tickets[o]
			end
		end
		assert(tickets[outcome] > 0 and roll <= n, "outcome " .. list[i] .. " can't be drawn now")
		return roll
	end
end

local function loot(client, item, isFromItem)
	client:OpenLoot({ item.id }, isFromItem)
	client:TakeLoot()
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
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

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------

T.test("login creates saved data, the first orders and the settings page", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.env.ForgebornCharDB
	T.ok(db and db == ns.db, "saved data exists")
	T.eq(db.version, 1)
	T.eq(db.gold, 0)
	T.eq(#db.orders.daily, 1, "first daily order")
	T.ok(db.orders.weekly, "first weekly order")
	T.ok(db.orders.dailyStamp > 0 and db.orders.weeklyStamp > 0)
	T.eq(#client.timers, 1, "a timer waits for the next reset")
	T.ok(client.settingsRegistered, "settings page registered")
	T.eq(client.env.SlashCmdList.FORGEBORN ~= nil, true)
	T.eq(client.env.SLASH_FORGEBORN1, "/forge")
end)

T.test("saved data survives a reload", function()
	local client = newClient()
	client:Login(nil)
	loot(client, ITEMS.BOOTS)
	client.ns.db.gold = 12345
	local saved = client.env.ForgebornCharDB
	local again = newClient()
	again:Login(saved)
	T.eq(again.ns.db.gold, 12345)
	T.eq(again.ns.db.workbench[1].name, "Tattered Boots")
	T.eq(#again.ns.db.orders.daily, 1, "no extra order on the same day")
end)

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------

T.test("a looted weapon or armour piece lands on the Workbench", function()
	local client = newClient()
	client:Login(nil)
	loot(client, ITEMS.BOOTS)
	local piece = client.ns.db.workbench[1]
	T.ok(piece, "boots on the Workbench")
	T.eq(piece.name, "Tattered Boots")
	T.eq(piece.startQuality, 0)
	T.eq(piece.itemLevel, 20)
	T.eq(piece.kind, "armor")
	T.eq(piece.equipLoc, "INVTYPE_FEET")
	T.eq(piece.armorType, 2)
	T.eq(piece.level, 0)
	T.ok(piece.uid >= 1)
	T.ok(client:LastChat():find("Workbench"), "announced in chat")
	loot(client, ITEMS.SWORD)
	T.eq(client.ns.db.workbench[2].kind, "weapon")
	T.eq(client.ns.db.workbench[2].armorType, nil)
end)

T.test("rings, cloth, fishing poles and shirts are not forged", function()
	local client = newClient()
	client:Login(nil)
	for _, item in ipairs({ ITEMS.RING, ITEMS.CLOTH, ITEMS.POLE, ITEMS.SHIRT_BODY }) do
		loot(client, item)
	end
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("items that weren't looted from a loot window don't count", function()
	local client = newClient()
	client:Login(nil)
	client:GiveItem(ITEMS.BOOTS.id) -- bought, mailed, crafted, quest reward
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("loot from a container item in the bags doesn't count", function()
	local client = newClient()
	client:Login(nil)
	loot(client, ITEMS.BOOTS, true)
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("items already in the bags at login are not added", function()
	local client = newClient()
	client:GiveItem(ITEMS.BOOTS.id)
	client:Login(nil)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("a repeated LOOT_READY doesn't count one drop twice", function()
	local client = newClient()
	client:Login(nil)
	client:OpenLoot({ ITEMS.BOOTS.id })
	client:Fire("LOOT_READY", false)
	client:TakeLoot()
	client:GiveItem(ITEMS.BOOTS.id) -- a second pair from somewhere else
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 1)
end)

T.test("a won loot roll counts", function()
	local client = newClient()
	client:Login(nil)
	client:Fire("LOOT_ITEM_ROLL_WON", client.items[ITEMS.STAFF.id].link, 1, 1, 87, false)
	client:GiveItem(ITEMS.STAFF.id)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(client.ns.db.workbench[1].name, "Epic Staff")
	T.eq(client.ns.db.workbench[1].startQuality, 4)
end)

T.test("an expected drop expires after a few minutes", function()
	local client = newClient()
	client:Login(nil)
	client:OpenLoot({ ITEMS.BOOTS.id })
	client.loot = {}
	client:Fire("LOOT_CLOSED")
	client:Advance(400)
	client:GiveItem(ITEMS.BOOTS.id)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("nothing counts while a merchant window is open, and a close event clears it", function()
	local client = newClient()
	client:Login(nil)
	client:OpenLoot({ ITEMS.BOOTS.id })
	client.loot = {}
	client:Fire("LOOT_CLOSED")
	client:Fire("MERCHANT_SHOW")
	client:GiveItem(ITEMS.BOOTS.id)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 0, "bought while the merchant is open")
	client:Fire("MERCHANT_CLOSED")
	loot(client, ITEMS.SWORD)
	T.eq(benchCount(client.ns.db), 1, "looting works again")
	-- A missed close event is cleared by the next loot window.
	client:Fire("MAIL_SHOW")
	loot(client, ITEMS.SHIRT)
	T.eq(benchCount(client.ns.db), 2)
end)

T.test("a quest reward cancels a matching expectation", function()
	local client = newClient()
	client:Login(nil)
	client:OpenLoot({ ITEMS.BOOTS.id })
	client.loot = {}
	client:Fire("LOOT_CLOSED")
	client:Fire("QUEST_LOOT_RECEIVED", 42, client.items[ITEMS.BOOTS.id].link, 1)
	client:GiveItem(ITEMS.BOOTS.id)
	client:Fire("BAG_UPDATE_DELAYED")
	T.eq(benchCount(client.ns.db), 0)
end)

T.test("item data that loads later still reaches the Workbench", function()
	local client = newClient()
	client:Login(nil)
	client.deferItemLoad = true
	loot(client, ITEMS.BOOTS)
	T.eq(benchCount(client.ns.db), 0, "waiting for item data")
	for _, fn in ipairs(client.pendingLoads) do
		fn()
	end
	T.eq(benchCount(client.ns.db), 1)
end)

T.test("a full Workbench drops the weakest item, which can be the new drop", function()
	local client = newClient()
	client:Login(nil)
	client.env.ForgebornCharDB.settings.announce = true
	for _, item in ipairs({ ITEMS.SWORD, ITEMS.SHIRT, ITEMS.HELM, ITEMS.GLOVES }) do
		loot(client, item)
	end
	T.eq(benchCount(client.ns.db), 4)
	loot(client, ITEMS.CLOAK) -- gray: weaker than everything
	T.eq(benchCount(client.ns.db), 4)
	for slot = 1, 4 do
		T.ok(client.ns.db.workbench[slot].name ~= "Grey Cloak", "the cloak was skipped")
	end
	T.ok(client:LastChat():find("not added"), "skip announced")
	loot(client, ITEMS.STAFF) -- purple: the white sword goes
	local names = {}
	for slot = 1, 4 do
		names[client.ns.db.workbench[slot].name] = true
	end
	T.ok(names["Epic Staff"] and not names["Rusty Sword"], "the sword made room")
	-- Ties on quality go by item level: the green shirt (22) stays, the green gloves (20) go.
	loot(client, ITEMS.HELM)
	names = {}
	for slot = 1, 4 do
		names[client.ns.db.workbench[slot].name] = (names[client.ns.db.workbench[slot].name] or 0) + 1
	end
	T.eq(names["Green Gloves"], nil)
	T.eq(names["Chain Shirt of the Bear"], 1)
end)

---------------------------------------------------------------------------
-- The anvil
---------------------------------------------------------------------------

local function setupAnvil(client, item)
	loot(client, item)
	local ns = client.ns
	for slot = 1, 4 do
		local piece = ns.db.workbench[slot]
		if piece and piece.itemID == item.id then
			ns.Forge.PutOnAnvil(slot)
			return piece
		end
	end
	error("item not on the Workbench")
end

T.test("putting a piece on the anvil swaps with the anvil and resets embers", function()
	local client = newClient()
	client:Login(nil)
	local ns = client.ns
	loot(client, ITEMS.BOOTS)
	loot(client, ITEMS.SWORD)
	local boots = ns.db.workbench[1]
	boots.embers = 5
	ns.Forge.PutOnAnvil(1)
	T.eq(ns.db.anvil, boots)
	T.eq(boots.embers, 0)
	T.eq(ns.db.workbench[1], nil)
	boots.embers = 4
	boots.frenzy = 2
	ns.Forge.PutOnAnvil(2) -- the sword; boots go back to slot 2
	T.eq(ns.db.anvil.name, "Rusty Sword")
	T.eq(ns.db.workbench[2], boots)
	T.eq(boots.frenzy, 2, "a parked piece keeps its Frenzy")
	ns.Forge.Park() -- first free slot: 1
	T.eq(ns.db.workbench[1].name, "Rusty Sword")
	T.eq(ns.db.anvil, nil)
	local _, err = ns.Forge.Park()
	T.eq(err, "ERR_NO_ITEM")
end)

T.test("strikes level the piece, a break destroys it and keeps the records", function()
	local client = newClient()
	client:Login(nil)
	local ns = client.ns
	local piece = setupAnvil(client, ITEMS.BOOTS)
	ns.Forge.Random = outcomes(ns, "HIT", "GREAT", "GREAT", "HIT")
	for _ = 1, 4 do
		local result = ns.Forge.Strike()
		T.ok(result and not result.broken)
	end
	T.eq(piece.level, 6)
	T.eq(ns.Forge.Quality(piece), 1, "white after 4 levels")
	T.eq(ns.db.records.best[1], 6)
	T.eq(ns.db.records.streak, 4)
	T.eq(ns.db.stats.swings, 4)
	-- White +6 (grade 6): 9% of the tickets break it, and the first ticket is a Break.
	T.near(ns.Rules.NextOdds(piece, ns.Economy.Mods())[ns.Data.BREAK], 0.09, 1e-12)
	ns.Forge.Random = scripted(1)
	local result = ns.Forge.Strike()
	T.ok(result.broken)
	T.eq(ns.db.anvil, nil)
	T.eq(ns.db.records.streak, 0)
	T.eq(ns.db.records.bestStreak, 4)
	T.eq(ns.db.stats.breaks, 1)
	T.eq(result.lostValue, math.floor(20 * 1.2 ^ 6 * 100 + 0.5))
	local _, err = ns.Forge.Strike()
	T.eq(err, "ERR_NO_ITEM")
end)

T.test("selling pays the value in copper and records the best sale", function()
	local client = newClient()
	client:Login(nil)
	local ns = client.ns
	local piece = setupAnvil(client, ITEMS.HELM)
	piece.level = 3
	local value = ns.Forge.Sell()
	T.eq(value, math.floor(21 * 3.2 * 1.2 ^ 3 * 100 + 0.5))
	T.eq(ns.db.gold, value)
	T.eq(ns.db.records.bestSale, value)
	T.eq(ns.db.records.bestSaleName, "Blue Plate Helm")
	T.eq(ns.db.stats.sold, 1)
	T.eq(ns.db.anvil, nil)
end)

T.test("a gray item taken to orange counts once", function()
	local client = newClient()
	client:Login(nil)
	local ns = client.ns
	local piece = setupAnvil(client, ITEMS.BOOTS)
	piece.level = 25 -- purple, one level before orange
	ns.Forge.Random = outcomes(ns, "CRACK") -- stays purple
	ns.Forge.Strike()
	T.eq(ns.db.records.grayToOrange, 0)
	ns.Forge.Random = outcomes(ns, "GREAT")
	ns.Forge.Strike()
	T.eq(ns.Forge.Quality(piece), 5)
	T.eq(ns.db.records.grayToOrange, 1)
	ns.Forge.Random = outcomes(ns, "GREAT")
	ns.Forge.Strike()
	T.eq(ns.db.records.grayToOrange, 1)
end)

T.test("the Display case keeps trophies and adds a bonus to sales", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	local piece = setupAnvil(client, ITEMS.HELM) -- blue: +0.5%
	local trophy = ns.Forge.Display(piece.uid)
	T.eq(trophy.quality, 3)
	T.eq(#db.display, 1)
	T.eq(db.anvil, nil)
	T.near(ns.Economy.TrophyBonus(), 0.005, 1e-12)
	loot(client, ITEMS.SHIRT)
	local shirt = db.workbench[1]
	local plain = math.floor(22 * 2.2 * 100 + 0.5)
	T.eq(ns.Forge.Value(shirt), math.floor(22 * 2.2 * 1.005 * 100 + 0.5))
	T.ok(ns.Forge.Value(shirt) > plain)
	-- Three slots to start; then full.
	for _, item in ipairs({ ITEMS.SWORD, ITEMS.GLOVES }) do
		loot(client, item)
	end
	ns.Forge.Display(db.workbench[1].uid)
	ns.Forge.Display(db.workbench[2].uid)
	T.eq(#db.display, 3)
	local _, err = ns.Forge.Display(db.workbench[3].uid)
	T.eq(err, "ERR_CASE_FULL")
	-- Argent Dawn ranks add slots and multiply the bonus.
	db.rep.ARGENT = 9000 -- Honored
	T.eq(ns.Economy.DisplaySlots(), 5)
	db.rep.ARGENT = 21000 -- Revered
	-- Trophies: the blue helm, the green shirt, the white sword.
	T.near(ns.Economy.TrophyBonus(), (0.005 + 0.0025 + 0) * 1.5, 1e-12)
	db.rep.ARGENT = 42000 -- Exalted
	T.eq(ns.Economy.DisplaySlots(), 6)
	ns.Economy.RemoveTrophy(1)
	T.eq(#db.display, 2)
end)

---------------------------------------------------------------------------
-- Crafting orders
---------------------------------------------------------------------------

T.test("a daily order arrives at each daily reset; the weekly at the weekly reset", function()
	local client = newClient()
	client:Login(nil)
	local db = client.ns.db
	local weeklyID = db.orders.weekly.id
	local untilDaily = client.env.C_DateAndTime.GetSecondsUntilDailyReset()
	client:Advance(untilDaily + 10)
	T.eq(#db.orders.daily, 2, "second daily")
	T.ok(client:LastChat():find("New crafting orders"), "announced")
	client:Advance(86400)
	T.eq(#db.orders.daily, 3, "third daily")
	client:Advance(86400)
	T.eq(#db.orders.daily, 3, "board full")
	T.eq(#db.orders.queue, 1, "fourth waits")
	client:Advance(86400)
	T.eq(#db.orders.queue, 1, "the waiting one was dropped and today's waits")
	T.eq(db.orders.weekly.id, weeklyID, "an unfinished weekly stays")
	-- Away for a week: only one new daily.
	local before = db.orders.nextID
	client:Advance(7 * 86400)
	T.eq(db.orders.nextID - before, 1, "one order for the whole week away (the weekly slot is still taken)")
end)

T.test("a free weekly slot gets a new weekly at the next weekly reset", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	local old = db.orders.weekly.id
	ns.Orders.Reject(old)
	T.eq(db.orders.weekly, nil)
	client:Advance(client.env.C_DateAndTime.GetSecondsUntilWeeklyReset() + 10)
	T.ok(db.orders.weekly and db.orders.weekly.id ~= old)
end)

T.test("the capital city at Honored opens a 4th daily slot and promotes the queue", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	for _ = 1, 3 do
		client:Advance(86400)
	end
	T.eq(#db.orders.daily, 3)
	T.eq(#db.orders.queue, 1)
	db.rep.CITY = 9000
	T.eq(ns.Economy.DailySlots(), 4)
	ns.Orders.Promote()
	T.eq(#db.orders.daily, 4)
	T.eq(#db.orders.queue, 0)
end)

local function makeOrder(ns, fields)
	local order = ns.Orders.Generate(fields.weekly or false, fields.faction or "ARGENT")
	for k, v in pairs(fields) do
		order[k] = v
	end
	if order.weekly then
		ns.db.orders.weekly = order
	else
		table.insert(ns.db.orders.daily, order)
	end
	return order
end

T.test("sending a fitting item pays twice its value and 500 reputation", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	db.orders.daily = {}
	loot(client, ITEMS.SHIRT) -- green mail chest, ilvl 22
	local shirt = db.workbench[1]
	local order = makeOrder(ns, { group = "CHEST", armorType = 3, minQuality = 2, ilvlMin = 15, ilvlMax = 25, faction = "CITY" })
	local value = ns.Forge.Value(shirt)
	local result = assert(ns.Orders.Send(order.id, shirt.uid))
	T.ok(result.done)
	T.eq(result.gold, 2 * value)
	T.eq(result.rep, 500)
	T.eq(db.gold, 2 * value)
	T.eq(db.rep.CITY, 500)
	T.eq(db.workbench[1], nil, "the copy is used up")
	T.eq(#db.orders.daily, 0)
	T.eq(db.stats.orders, 1)
end)

T.test("each quality step above the ask pays 50% more", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	db.orders.daily = {}
	loot(client, ITEMS.HELM) -- blue plate head
	local helm = db.workbench[1]
	helm.level = 6 -- purple: two steps above a green ask
	local order = makeOrder(ns, { group = "HEAD", minQuality = 2, ilvlMin = 15, ilvlMax = 25, faction = "THORIUM" })
	local value = ns.Forge.Value(helm)
	local result = assert(ns.Orders.Send(order.id, helm.uid))
	T.eq(result.gold, math.floor(2 * value * 2 + 0.5))
	T.eq(result.rep, 1000)
end)

T.test("Send checks slot, armour type, item level and quality", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	db.orders.daily = {}
	loot(client, ITEMS.SHIRT)
	local shirt = db.workbench[1]
	local wrongSlot = makeOrder(ns, { group = "FEET", minQuality = 1, ilvlMin = 1, ilvlMax = 60 })
	local wrongType = makeOrder(ns, { group = "CHEST", armorType = 1, minQuality = 1, ilvlMin = 1, ilvlMax = 60 })
	local wrongLevel = makeOrder(ns, { group = "CHEST", minQuality = 1, ilvlMin = 23, ilvlMax = 30 })
	local wrongQuality = makeOrder(ns, { group = "ARMOR", minQuality = 3, ilvlMin = 1 })
	local _, err = ns.Orders.Send(wrongSlot.id, shirt.uid)
	T.eq(err, "ERR_ORDER_SLOT")
	_, err = ns.Orders.Send(wrongType.id, shirt.uid)
	T.eq(err, "ERR_ORDER_SLOT")
	_, err = ns.Orders.Send(wrongLevel.id, shirt.uid)
	T.eq(err, "ERR_ORDER_ILVL")
	_, err = ns.Orders.Send(wrongQuality.id, shirt.uid)
	T.eq(err, "ERR_ORDER_QUALITY")
	T.ok(db.workbench[1], "nothing was used up")
	local any = makeOrder(ns, { group = "ANY", minQuality = 2, ilvlMin = 20 })
	T.ok(ns.Orders.Send(any.id, shirt.uid), "no item level cap at max level orders")
	_, err = ns.Orders.Send(any.id, shirt.uid)
	T.eq(err, "ERR_NO_ORDER")
end)

T.test("weapon groups and armour groups match the right slots", function()
	local client = newClient()
	client:Login(nil)
	local Orders = client.ns.Orders
	local sword = { kind = "weapon", equipLoc = "INVTYPE_WEAPON" }
	local staff = { kind = "weapon", equipLoc = "INVTYPE_2HWEAPON" }
	local bow = { kind = "weapon", equipLoc = "INVTYPE_RANGEDRIGHT" }
	local robe = { kind = "armor", equipLoc = "INVTYPE_ROBE" }
	local shield = { kind = "armor", equipLoc = "INVTYPE_SHIELD" }
	T.ok(Orders.GroupMatches("ONEHAND", sword)); T.ok(not Orders.GroupMatches("ONEHAND", staff))
	T.ok(Orders.GroupMatches("TWOHAND", staff)); T.ok(Orders.GroupMatches("RANGED", bow))
	T.ok(Orders.GroupMatches("CHEST", robe)); T.ok(Orders.GroupMatches("SHIELD", shield))
	T.ok(Orders.GroupMatches("WEAPON", bow)); T.ok(not Orders.GroupMatches("WEAPON", robe))
	T.ok(Orders.GroupMatches("ARMOR", shield)); T.ok(Orders.GroupMatches("ANY", sword))
	T.ok(not Orders.GroupMatches("NOPE", sword))
end)

T.test("a weekly order takes three items and pays when the last is in", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	local order = makeOrder(ns, { weekly = true, group = "ARMOR", minQuality = 1, ilvlMin = 1, faction = "ARGENT", count = 3 })
	local total = 0
	for i, item in ipairs({ ITEMS.SHIRT, ITEMS.HELM, ITEMS.GLOVES }) do
		loot(client, item)
		local piece = db.workbench[1]
		local steps = ns.Forge.Quality(piece) - 1
		total = total + math.floor(4 * ns.Forge.Value(piece) * (1 + 0.5 * steps) + 0.5)
		local result = assert(ns.Orders.Send(order.id, piece.uid))
		if i < 3 then
			T.ok(not result.done)
			T.eq(result.sent, i)
			T.eq(db.gold, 0, "nothing paid yet")
		else
			T.ok(result.done)
			T.eq(result.gold, total)
			-- 2000 / 3 per item, with +50% per step: green, blue, green over white.
			T.eq(result.rep, math.floor(2000 / 3 * (1.5 + 2 + 1.5) + 0.5))
		end
	end
	T.eq(db.orders.weekly, nil)
	T.eq(db.gold, total)
end)

T.test("rejecting costs a quarter of the reputation, never below Neutral", function()
	local client = newClient()
	client:Login(nil)
	local ns, db = client.ns, client.ns.db
	db.rep.STEAMWHEEDLE = 1000
	local daily = makeOrder(ns, { group = "ANY", minQuality = 1, ilvlMin = 1, faction = "STEAMWHEEDLE" })
	local result = assert(ns.Orders.Reject(daily.id))
	T.eq(result.rep, 125)
	T.eq(db.rep.STEAMWHEEDLE, 875)
	local weekly = makeOrder(ns, { weekly = true, group = "ANY", minQuality = 1, ilvlMin = 1, faction = "STEAMWHEEDLE", count = 3 })
	ns.Orders.Reject(weekly.id)
	T.eq(db.rep.STEAMWHEEDLE, 375)
	local again = makeOrder(ns, { weekly = true, group = "ANY", minQuality = 1, ilvlMin = 1, faction = "STEAMWHEEDLE", count = 3 })
	ns.Orders.Reject(again.id)
	T.eq(db.rep.STEAMWHEEDLE, 0)
end)

T.test("orders are generated near the player's level and for every faction", function()
	local client = newClient({ level = 44 })
	client:Login(nil)
	local ns = client.ns
	math.randomseed(11)
	local seen = {}
	for _ = 1, 400 do
		local weekly = math.random(2) == 1
		local order = ns.Orders.Generate(weekly)
		T.ok(client.ns.DB.IsOrderGroup(order.group), "valid group " .. order.group)
		T.eq(order.ilvlMin, 39)
		T.eq(order.ilvlMax, 49)
		T.ok(order.minQuality >= 1 and order.minQuality <= 4)
		T.eq(order.count, weekly and 3 or 1)
		if weekly then
			T.ok(order.minQuality <= 3, "weekly asks at most blue")
		end
		if order.faction == "CITY" then
			T.ok(order.armorType == 1 or order.armorType == 2 or order.armorType == 3)
		end
		if order.faction == "THORIUM" and order.armorType then
			T.eq(order.armorType, 4, "Thorium asks for plate")
		end
		if order.faction == "STEAMWHEEDLE" and not weekly then
			T.ok(order.minQuality >= 2, "Steamwheedle asks for high quality")
		end
		seen[order.faction] = true
		T.ok(#ns.OrderAskText(order) > 0)
	end
	T.eq(count(seen), 4)
	-- At max level there is no item level cap; below 40 Thorium asks for weapons only.
	client.level = 60
	T.eq(ns.Orders.Generate(false).ilvlMax, nil)
	client.level = 20
	for _ = 1, 50 do
		local order = ns.Orders.Generate(false, "THORIUM")
		T.ok(client.ns.Data.WEAPON_GROUPS[order.group] ~= nil, "weapon ask below level 40")
	end
end)

---------------------------------------------------------------------------
-- Economy
---------------------------------------------------------------------------

T.test("reputation ranks follow WoW: 3000, 6000, 12000, 21000 to Exalted", function()
	local client = newClient()
	client:Login(nil)
	local E, db = client.ns.Economy, client.ns.db
	local cases = { { 0, 1 }, { 2999, 1 }, { 3000, 2 }, { 8999, 2 }, { 9000, 3 }, { 20999, 3 }, { 21000, 4 }, { 41999, 4 }, { 42000, 5 } }
	for _, c in ipairs(cases) do
		T.eq(E.RankOf(c[1]), c[2], "rep " .. c[1])
	end
	db.rep.ARGENT = 4500
	local rank, into, size = E.RepProgress("ARGENT")
	T.eq(rank, 2); T.eq(into, 1500); T.eq(size, 6000)
	E.AddRep("ARGENT", 100000)
	T.eq(db.rep.ARGENT, 42999)
	rank, into, size = E.RepProgress("ARGENT")
	T.eq(rank, 5); T.eq(into, 999); T.eq(size, 1000)
end)

T.test("lockboxes: new tool, duplicate upgrade, legendary salvage, full shelf, purse and items", function()
	local client = newClient()
	client:Login(nil)
	local E, db = client.ns.Economy, client.ns.db
	db.gold = 10000000
	-- Bronze: roll 1-100 rare tool, then pick from 5 rare tools.
	E.Random = scripted(50, 3) -- FIERY_CORE is the 3rd rare tool
	local r = assert(E.BuyLockbox("BRONZE"))
	T.eq(r.kind, "tool"); T.eq(r.tool, "FIERY_CORE"); T.eq(r.receive.kind, "new"); T.eq(db.shelf[1].id, "FIERY_CORE")
	T.eq(db.gold, 10000000 - 50000)
	E.Random = scripted(50, 3)
	r = E.BuyLockbox("BRONZE")
	T.eq(r.receive.kind, "upgrade"); T.eq(db.shelf[1].rank, 3)
	E.Random = scripted(50, 3)
	E.BuyLockbox("BRONZE")
	T.eq(db.shelf[1].rank, 4)
	local gold = db.gold
	E.Random = scripted(50, 3)
	r = E.BuyLockbox("BRONZE")
	T.eq(r.receive.kind, "salvage"); T.eq(r.receive.gold, 50000); T.eq(db.gold, gold - 50000 + 50000)
	-- Common tools fill the shelf, the 5th goes pending.
	for i = 1, 3 do
		E.Random = scripted(101, i)
		E.BuyLockbox("BRONZE")
	end
	T.ok(db.shelf[2] and db.shelf[3] and db.shelf[4])
	E.Random = scripted(100, 1) -- rolls 1-100 are a rare tool; rare tool #1 is STRONG_FLUX
	r = E.BuyLockbox("BRONZE")
	T.eq(r.receive.kind, "pending"); T.eq(db.pendingTool.id, "STRONG_FLUX")
	local _, err = E.BuyLockbox("BRONZE")
	T.eq(err, "ERR_PENDING_TOOL")
	local ok, replaced = E.PlacePendingTool(2)
	T.ok(ok); T.eq(replaced.id, "HAMMER"); T.eq(db.shelf[2].id, "STRONG_FLUX"); T.eq(db.pendingTool, nil)
	-- One-use items and purses.
	E.Random = scripted(400)
	r = E.BuyLockbox("BRONZE")
	T.eq(r.kind, "item"); T.eq(r.item, "COARSE_STONE"); T.eq(db.consumables.COARSE_STONE, 1)
	gold = db.gold
	E.Random = scripted(900, 15001) -- purse: 10000 + 15000 = 25000
	r = E.BuyLockbox("BRONZE")
	T.eq(r.kind, "purse"); T.eq(r.gold, 25000); T.eq(db.gold, gold - 50000 + 25000)
end)

T.test("lockbox odds add up to 1000 and every pool has tools", function()
	local client = newClient()
	client:Login(nil)
	local Data, E = client.ns.Data, client.ns.Economy
	for id, box in pairs(Data.LOCKBOXES) do
		local sum = 0
		for _, entry in ipairs(box.table) do
			sum = sum + entry.chance
			if entry.kind == "tool" then
				T.ok(#E.ToolPool(entry.rank) > 0, id .. " rank " .. entry.rank)
			elseif entry.kind == "item" then
				T.ok(Data.CONSUMABLES[entry.id], id .. " item")
			end
		end
		T.eq(sum, 1000, id)
	end
	T.eq(#E.ToolPool(1), 3); T.eq(#E.ToolPool(2), 5); T.eq(#E.ToolPool(3), 4); T.eq(#E.ToolPool(4), 1)
end)

T.test("Steamwheedle unlocks the Iron and Thorium lockboxes, then a discount", function()
	local client = newClient()
	client:Login(nil)
	local E, db = client.ns.Economy, client.ns.db
	db.gold = 5000000
	local _, err = E.BuyLockbox("IRON")
	T.eq(err, "ERR_LOCKED")
	db.rep.STEAMWHEEDLE = 9000
	E.Random = scripted(1000, 50000) -- purse
	T.ok(E.BuyLockbox("IRON"))
	_, err = E.BuyLockbox("THORIUM")
	T.eq(err, "ERR_LOCKED")
	db.rep.STEAMWHEEDLE = 42000
	T.eq(E.LockboxPrice("BRONZE"), 40000)
	T.eq(E.LockboxPrice("THORIUM"), 800000)
	db.gold = 100
	_, err = E.BuyLockbox("BRONZE")
	T.eq(err, "ERR_NO_GOLD")
end)

T.test("one-use items make swings safe; the capital city sells them cheaper", function()
	local client = newClient()
	client:Login(nil)
	local ns, E, db = client.ns, client.ns.Economy, client.ns.db
	db.gold = 1000000
	local _, err = E.UseConsumable("COARSE_STONE")
	T.eq(err, "ERR_NO_ITEM")
	local piece = setupAnvil(client, ITEMS.HELM)
	_, err = E.UseConsumable("COARSE_STONE")
	T.eq(err, "ERR_NONE_LEFT")
	T.ok(E.BuyConsumable("COARSE_STONE"))
	T.eq(db.gold, 1000000 - 20000)
	T.eq(E.UseConsumable("COARSE_STONE"), 1)
	T.eq(piece.safe, 1)
	_, err = E.BuyConsumable("DENSE_STONE")
	T.eq(err, "ERR_LOCKED")
	db.rep.CITY = 3000
	T.ok(E.BuyConsumable("DENSE_STONE"))
	E.UseConsumable("DENSE_STONE")
	T.eq(piece.safe, 4)
	-- Safe swings never break, even on blue.
	ns.Forge.Random = scripted(1, 1, 1, 1)
	for _ = 1, 4 do
		local r = ns.Forge.Strike()
		T.ok(r.safe and not r.broken)
	end
	T.eq(piece.safe, 0)
	db.rep.CITY = 21000
	T.eq(E.ConsumablePrice("COARSE_STONE"), 15000)
	db.rep.CITY = 42000
	T.eq(E.ConsumablePrice("DENSE_STONE"), 25000)
end)

T.test("the Thorium Brotherhood sells its tools by rank", function()
	local client = newClient()
	client:Login(nil)
	local E, db = client.ns.Economy, client.ns.db
	db.gold = 100000000
	local _, err = E.BuyTool("THORIUM", 1)
	T.eq(err, "ERR_LOCKED")
	db.rep.THORIUM = 9000
	local r = assert(E.BuyTool("THORIUM", 1))
	T.eq(r.tool, "ENCHANTED_THORIUM"); T.eq(db.shelf[1].rank, 2)
	_, err = E.BuyTool("THORIUM", 3)
	T.eq(err, "ERR_LOCKED")
	db.rep.THORIUM = 42000
	r = assert(E.BuyTool("THORIUM", 3))
	T.eq(r.tool, "SULFURON"); T.eq(db.shelf[2].rank, 4)
	_, err = E.BuyTool("STEAMWHEEDLE", 1)
	T.eq(err, "ERR_UNKNOWN")
end)

T.test("tools on the shelf can be moved and removed; the pending tool discarded", function()
	local client = newClient()
	client:Login(nil)
	local E, db = client.ns.Economy, client.ns.db
	E.ReceiveTool("HAMMER", 1)
	E.ReceiveTool("FIERY_CORE", 2)
	T.ok(E.MoveTool(1, 4))
	T.eq(db.shelf[4].id, "HAMMER"); T.eq(db.shelf[1], nil)
	T.eq(E.RemoveTool(4).id, "HAMMER")
	local _, err = E.RemoveTool(4)
	T.eq(err, "ERR_BAD_SLOT")
	for _, id in ipairs({ "HAMMER", "WEAK_FLUX", "HEAVY_STONE", "LAVA_CORE" }) do
		E.ReceiveTool(id, 1)
	end
	T.eq(db.pendingTool.id, "LAVA_CORE")
	E.ReceiveTool("LAVA_CORE", 2)
	T.eq(db.pendingTool.rank, 2, "a duplicate of the pending tool upgrades it")
	T.ok(E.DiscardPendingTool())
	T.eq(db.pendingTool, nil)
	_, err = E.DiscardPendingTool()
	T.eq(err, "ERR_NO_PENDING_TOOL")
	_, err = E.PlacePendingTool(1)
	T.eq(err, "ERR_NO_PENDING_TOOL")
end)

---------------------------------------------------------------------------
-- Saved data repair
---------------------------------------------------------------------------

T.test("damaged saved data is repaired instead of breaking the addon", function()
	local client = newClient()
	local damaged = {
		gold = "lots",
		nextUID = 2,
		shelf = { { id = "HAMMER", rank = 9 }, { id = "NOPE", rank = 1 }, "junk", { id = "FIERY_CORE", rank = 1 } },
		pendingTool = { id = "ARCANITE" },
		consumables = { COARSE_STONE = -3, DENSE_STONE = 2.7 },
		display = { { itemID = 5, quality = 9, level = 3, name = 1 }, { quality = 2 } },
		workbench = {
			{ uid = 7, itemID = 1, startQuality = 2, level = 4, itemLevel = 20, kind = "armor", name = "Ok" },
			{ uid = 3, itemID = 2, startQuality = 1, level = 0, itemLevel = 10, kind = "hat" },
			nil,
			{ uid = 9, itemID = 3, startQuality = 1, level = -2, itemLevel = 10, kind = "weapon" },
		},
		anvil = { uid = 12, itemID = 4, startQuality = 8, level = 1, itemLevel = 30, kind = "weapon", embers = "x" },
		orders = { daily = { { id = 4, faction = "ARGENT", group = "HEAD", minQuality = 2, ilvlMin = 10 }, { id = 5, faction = "NOPE", group = "HEAD", minQuality = 1, ilvlMin = 1 }, { id = 6, faction = "CITY", group = "HAT", minQuality = 1, ilvlMin = 1 } }, weekly = "x", nextID = 1 },
		rep = { ARGENT = 99999, CITY = -50 },
		records = { best = { [0] = 3, [2] = "x" } },
		settings = { sound = false },
	}
	client:Login(damaged)
	local db = client.ns.db
	T.eq(db.gold, 0)
	T.eq(db.shelf[1].rank, 4, "rank capped at legendary")
	T.eq(db.shelf[2], nil)
	T.eq(db.shelf[3], nil)
	T.eq(db.shelf[4].rank, 2, "rank raised to the tool's base rarity")
	T.eq(db.pendingTool, nil, "a tool without a rank is dropped")
	T.eq(db.consumables.COARSE_STONE, 0)
	T.eq(db.consumables.DENSE_STONE, 2)
	T.eq(#db.display, 1)
	T.eq(db.display[1].quality, 5)
	T.eq(db.display[1].name, "?")
	T.eq(db.workbench[1].name, "Ok")
	T.eq(db.workbench[2], nil, "unknown kind dropped")
	T.eq(db.workbench[4], nil, "negative level dropped")
	T.eq(db.anvil.startQuality, 5)
	T.eq(db.anvil.embers, 0)
	T.eq(db.nextUID, 13, "uids stay unique")
	T.eq(#db.orders.daily, 2, "the repaired order plus today's new one")
	T.eq(db.orders.daily[1].id, 4)
	T.ok(db.orders.daily[2].id > 4, "order ids stay unique")
	T.eq(db.rep.ARGENT, 42999)
	T.eq(db.rep.CITY, 0)
	T.eq(db.rep.THORIUM, 0)
	T.eq(db.records.best[0], 3)
	T.eq(db.records.best[2], nil)
	T.eq(db.settings.sound, false)
	T.eq(db.settings.announce, true)
	-- The repaired data plays: strike the anvil piece.
	client.ns.Forge.Random = scripted(20)
	T.ok(client.ns.Forge.Strike())
end)

T.test("strings are complete in English and German, and every format matches", function()
	local client = newClient()
	local ns = client.ns
	local en, de = ns.LOCALES.enUS, ns.LOCALES.deDE
	for key in pairs(en) do
		T.ok(de[key] ~= nil, "German is missing " .. key)
	end
	for key in pairs(de) do
		T.ok(en[key] ~= nil, "English has no " .. key)
	end
	local function specs(s)
		local list = {}
		if type(s) ~= "string" then
			return ""
		end
		for spec in s:gmatch("%%[%-%d%.]*([%a%%])") do
			if spec ~= "%" then
				table.insert(list, spec)
			end
		end
		return table.concat(list)
	end
	for key, text in pairs(en) do
		T.eq(specs(de[key]), specs(text), "format specifiers of " .. key)
	end
	-- Every key built at runtime exists.
	local Data = ns.Data
	local needed = {}
	for id in pairs(Data.TOOLS) do table.insert(needed, "TOOL_" .. id) end
	for id in pairs(Data.CONSUMABLES) do table.insert(needed, "ITEM_" .. id) end
	for id in pairs(Data.LOCKBOXES) do
		table.insert(needed, "LOCKBOX_" .. id)
		table.insert(needed, "LOCKBOX_DESC_" .. id)
	end
	for _, def in pairs(Data.TOOLS) do table.insert(needed, "EFFECT_" .. def.effect) end
	for group in pairs(Data.ARMOR_SLOTS) do table.insert(needed, "SLOT_" .. group) end
	for group in pairs(Data.WEAPON_GROUPS) do table.insert(needed, "SLOT_" .. group) end
	for _, g in ipairs({ "ARMOR", "WEAPON", "ANY" }) do table.insert(needed, "ASK_PIECES_" .. g) end
	for i = 1, 4 do table.insert(needed, "ARMOR_TYPE_" .. i); table.insert(needed, "RANK_" .. i) end
	for i = 0, 5 do table.insert(needed, "QUALITY_" .. i) end
	for i = 1, 5 do table.insert(needed, "STANDING_" .. i) end
	for _, f in ipairs(Data.FACTION_ORDER) do
		table.insert(needed, "FACTION_DESC_" .. f)
		if f ~= "CITY" then
			table.insert(needed, "FACTION_" .. f)
			table.insert(needed, "FACTION_SHORT_" .. f)
		end
		for _, ware in ipairs(Data.FACTIONS[f].wares) do
			if ware.kind == "perk" then
				table.insert(needed, "PERK_" .. ware.id)
				table.insert(needed, "PERK_DESC_" .. ware.id)
			end
		end
	end
	for _, city in pairs(Data.CITY_BY_RACE) do table.insert(needed, "CITY_" .. city) end
	for _, key in ipairs(needed) do
		T.ok(en[key] ~= nil, "missing string " .. key)
	end
end)
