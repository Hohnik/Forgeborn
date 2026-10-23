-- Forgeborn: saved data (per character), defaults and repair of damaged data.
local _, ns = ...

local Data = ns.Data
local DB = {}
ns.DB = DB

DB.VERSION = 1

function DB.Defaults()
	return {
		version = DB.VERSION,
		gold = 0, -- addon gold, in copper
		nextUID = 1,
		shelf = {}, -- [1..4] = { id = toolID, rank = 1..4 }
		pendingTool = nil, -- a tool waiting for a shelf slot: { id, rank }
		consumables = { COARSE_STONE = 0, DENSE_STONE = 0 },
		display = {}, -- trophies, in order
		workbench = {}, -- [1..4] = piece
		anvil = nil, -- piece
		orders = { daily = {}, weekly = nil, queue = {}, dailyStamp = 0, weeklyStamp = 0, nextID = 1 },
		rep = { THORIUM = 0, STEAMWHEEDLE = 0, CITY = 0, ARGENT = 0 },
		records = { best = {}, bestSale = 0, bestSaleName = nil, bestSaleQuality = nil, streak = 0, bestStreak = 0, grayToOrange = 0 },
		stats = { swings = 0, breaks = 0, sold = 0, earned = 0, orders = 0, lockboxes = 0 },
		settings = { sound = true, announce = true },
	}
end

local function isNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function wholeNumber(v, minimum)
	if not isNumber(v) then
		return nil
	end
	v = math.floor(v)
	if minimum and v < minimum then
		return nil
	end
	return v
end

-- A forged copy must have these fields to be playable.
function DB.CleanPiece(p)
	if type(p) ~= "table" then
		return nil
	end
	p.uid = wholeNumber(p.uid, 1)
	p.itemID = wholeNumber(p.itemID, 1)
	p.startQuality = wholeNumber(p.startQuality, 0)
	p.level = wholeNumber(p.level, 0)
	p.itemLevel = wholeNumber(p.itemLevel, 1)
	if not (p.uid and p.itemID and p.startQuality and p.level and p.itemLevel) then
		return nil
	end
	if p.startQuality > Data.MAX_QUALITY then
		p.startQuality = Data.MAX_QUALITY
	end
	if p.kind ~= "weapon" and p.kind ~= "armor" then
		return nil
	end
	if type(p.name) ~= "string" then
		p.name = "?"
	end
	if type(p.equipLoc) ~= "string" then
		p.equipLoc = ""
	end
	if p.link ~= nil and type(p.link) ~= "string" then
		p.link = nil
	end
	if p.icon ~= nil and type(p.icon) ~= "number" and type(p.icon) ~= "string" then
		p.icon = nil
	end
	p.armorType = wholeNumber(p.armorType, 0)
	p.embers = wholeNumber(p.embers, 0) or 0
	p.frenzy = wholeNumber(p.frenzy, 0) or 0
	p.safe = wholeNumber(p.safe, 0) or 0
	p.swings = wholeNumber(p.swings, 0) or 0
	p.afterMiss = p.afterMiss == true
	p.sulfuronUsed = p.sulfuronUsed == true
	return p
end

local function cleanTool(tool)
	if type(tool) ~= "table" or type(tool.id) ~= "string" then
		return nil
	end
	local def = Data.TOOLS[tool.id]
	local rank = wholeNumber(tool.rank, 1)
	if not def or not rank then
		return nil
	end
	rank = math.min(math.max(rank, def.base), Data.RANK_LEGENDARY)
	return { id = tool.id, rank = rank }
end

local function cleanTrophy(t)
	if type(t) ~= "table" then
		return nil
	end
	t.itemID = wholeNumber(t.itemID, 1)
	t.quality = wholeNumber(t.quality, 0)
	t.level = wholeNumber(t.level, 0)
	if not (t.itemID and t.quality and t.level) then
		return nil
	end
	t.quality = math.min(t.quality, Data.MAX_QUALITY)
	t.startQuality = wholeNumber(t.startQuality, 0) or t.quality
	t.itemLevel = wholeNumber(t.itemLevel, 1) or 1
	t.value = wholeNumber(t.value, 0) or 0
	if type(t.name) ~= "string" then
		t.name = "?"
	end
	if type(t.piece) ~= "table" then
		t.piece = nil -- trophies from 1.0 have none; Forge.PieceFromTrophy rebuilds it from the item
	end
	return t
end

-- What an order can ask for: an armour slot, a weapon group, or "ARMOR", "WEAPON", "ANY".
function DB.IsOrderGroup(group)
	return type(group) == "string"
		and (Data.ARMOR_SLOTS[group] ~= nil or Data.WEAPON_GROUPS[group] ~= nil or group == "ARMOR" or group == "WEAPON" or group == "ANY")
end

local function cleanOrder(o)
	if type(o) ~= "table" then
		return nil
	end
	o.id = wholeNumber(o.id, 1)
	o.minQuality = wholeNumber(o.minQuality, 0)
	o.ilvlMin = wholeNumber(o.ilvlMin, 1)
	if o.ilvlMax ~= nil then
		o.ilvlMax = wholeNumber(o.ilvlMax, 1)
	end
	if not (o.id and o.minQuality and o.ilvlMin) or not Data.FACTIONS[o.faction] or not DB.IsOrderGroup(o.group) then
		return nil
	end
	o.minQuality = math.min(o.minQuality, Data.MAX_QUALITY)
	o.weekly = o.weekly == true
	o.count = wholeNumber(o.count, 1) or 1
	o.sent = wholeNumber(o.sent, 0) or 0
	o.gold = wholeNumber(o.gold, 0) or 0
	o.rep = isNumber(o.rep) and o.rep or 0
	if o.armorType ~= nil then
		o.armorType = wholeNumber(o.armorType, 1)
	end
	return o
end

local function cleanList(list, cleaner, limit)
	local out = {}
	if type(list) == "table" then
		for i = 1, limit or #list do
			local entry = cleaner(list[i])
			if entry then
				table.insert(out, entry)
			end
		end
	end
	return out
end

-- Fills missing keys and drops anything that can't be used, so a damaged file never breaks the addon.
function DB.Repair(db)
	local fresh = DB.Defaults()
	if type(db) ~= "table" then
		return fresh
	end
	db.version = DB.VERSION
	db.gold = wholeNumber(db.gold, 0) or 0
	db.nextUID = wholeNumber(db.nextUID, 1) or 1

	local shelf = {}
	if type(db.shelf) == "table" then
		for slot = 1, Data.SHELF_SLOTS do
			shelf[slot] = cleanTool(db.shelf[slot])
		end
	end
	db.shelf = shelf
	db.pendingTool = cleanTool(db.pendingTool)

	local consumables = {}
	for _, id in ipairs(Data.CONSUMABLE_ORDER) do
		consumables[id] = type(db.consumables) == "table" and wholeNumber(db.consumables[id], 0) or 0
	end
	db.consumables = consumables

	db.display = cleanList(db.display, cleanTrophy, 64)

	local bench = {}
	if type(db.workbench) == "table" then
		for slot = 1, Data.WORKBENCH_SLOTS do
			bench[slot] = DB.CleanPiece(db.workbench[slot])
		end
	end
	db.workbench = bench
	db.anvil = DB.CleanPiece(db.anvil)

	local orders = type(db.orders) == "table" and db.orders or {}
	db.orders = {
		daily = cleanList(orders.daily, cleanOrder, 8),
		weekly = cleanOrder(orders.weekly),
		queue = cleanList(orders.queue, cleanOrder, 8),
		dailyStamp = wholeNumber(orders.dailyStamp, 0) or 0,
		weeklyStamp = wholeNumber(orders.weeklyStamp, 0) or 0,
		nextID = wholeNumber(orders.nextID, 1) or 1,
	}
	if db.orders.weekly then
		db.orders.weekly.weekly = true
	end

	local rep = {}
	for _, faction in ipairs(Data.FACTION_ORDER) do
		local value = type(db.rep) == "table" and wholeNumber(db.rep[faction]) or 0
		rep[faction] = math.min(math.max(value or 0, 0), Data.REP_MAX)
	end
	db.rep = rep

	local records = type(db.records) == "table" and db.records or {}
	local best = {}
	if type(records.best) == "table" then
		for q = 0, Data.MAX_QUALITY do
			best[q] = wholeNumber(records.best[q], 0)
		end
	end
	db.records = {
		best = best,
		bestSale = wholeNumber(records.bestSale, 0) or 0,
		bestSaleName = type(records.bestSaleName) == "string" and records.bestSaleName or nil,
		bestSaleQuality = wholeNumber(records.bestSaleQuality, 0),
		streak = wholeNumber(records.streak, 0) or 0,
		bestStreak = wholeNumber(records.bestStreak, 0) or 0,
		grayToOrange = wholeNumber(records.grayToOrange, 0) or 0,
	}

	local stats = {}
	for key in pairs(fresh.stats) do
		stats[key] = type(db.stats) == "table" and wholeNumber(db.stats[key], 0) or 0
	end
	db.stats = stats

	-- The capital city, saved once it is known (see ns.CityKey).
	local cities = {}
	for _, city in pairs(Data.CITY_BY_RACE) do
		cities[city] = true
	end
	if not cities[db.city] then
		db.city = nil
	end

	local settings = type(db.settings) == "table" and db.settings or {}
	db.settings = {
		sound = settings.sound ~= false,
		announce = settings.announce ~= false,
	}

	-- uids must stay unique even after repairs.
	local highest = 0
	local function seen(p)
		if p and p.uid > highest then
			highest = p.uid
		end
	end
	seen(db.anvil)
	for slot = 1, Data.WORKBENCH_SLOTS do
		seen(db.workbench[slot])
	end
	if db.nextUID <= highest then
		db.nextUID = highest + 1
	end
	local highestOrder = 0
	for _, list in ipairs({ db.orders.daily, db.orders.queue }) do
		for _, o in ipairs(list) do
			highestOrder = math.max(highestOrder, o.id)
		end
	end
	if db.orders.weekly then
		highestOrder = math.max(highestOrder, db.orders.weekly.id)
	end
	if db.orders.nextID <= highestOrder then
		db.orders.nextID = highestOrder + 1
	end
	return db
end

function DB.NewUID()
	local db = ns.db
	local uid = db.nextUID
	db.nextUID = uid + 1
	return uid
end

-- Called on ADDON_LOADED, when the saved variable is available.
function DB.Load()
	ForgebornCharDB = DB.Repair(ForgebornCharDB)
	ns.db = ForgebornCharDB
	return ns.db
end
