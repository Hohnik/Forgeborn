-- Forgeborn: crafting orders. One daily and one weekly order arrive at WoW's daily and weekly reset,
-- each from a random one of the four factions. Orders never expire; a rejected order costs reputation.
local _, ns = ...

local Data = ns.Data
local Orders = {}
ns.Orders = Orders

local floor, max = math.floor, math.max

function Orders.Random(n)
	return math.random(n)
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------

-- Start of the current daily or weekly period, rounded to the minute so small clock jitter doesn't count as a reset.
function Orders.PeriodStart(now, untilReset, length)
	if type(untilReset) ~= "number" or untilReset < 0 or untilReset > length then
		untilReset = length - (now % length)
	end
	local start = now + untilReset - length
	return floor((start + 30) / 60) * 60
end

function Orders.SecondsUntilDaily()
	local seconds = C_DateAndTime.GetSecondsUntilDailyReset()
	if type(seconds) ~= "number" or seconds < 0 then
		seconds = Data.SECONDS_PER_DAY - (GetServerTime() % Data.SECONDS_PER_DAY)
	end
	return seconds
end

function Orders.SecondsUntilWeekly()
	local seconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
	if type(seconds) ~= "number" or seconds < 0 then
		seconds = Data.SECONDS_PER_WEEK - (GetServerTime() % Data.SECONDS_PER_WEEK)
	end
	return seconds
end

---------------------------------------------------------------------------
-- Generating orders
---------------------------------------------------------------------------

local function pickWeighted(weights, keys)
	local total = 0
	for _, key in ipairs(keys) do
		total = total + (weights[key] or 0)
	end
	local roll = Orders.Random(total)
	for _, key in ipairs(keys) do
		roll = roll - (weights[key] or 0)
		if roll <= 0 then
			return key
		end
	end
	return keys[#keys]
end

local function pickOne(list)
	return list[Orders.Random(#list)]
end

local function weaponGroup()
	return pickWeighted(Data.WEAPON_GROUP_WEIGHTS, Data.WEAPON_GROUP_ORDER)
end

-- What a faction asks for. Daily orders name a slot; weekly orders name a kind of gear.
function Orders.MakeAsk(faction, weekly, playerLevel)
	local plate = playerLevel >= Data.PLATE_LEVEL
	if faction == "THORIUM" then
		local wantPlate = plate and Orders.Random(2) == 1
		if weekly then
			if wantPlate then
				return { group = "ARMOR", armorType = Data.ARMOR_PLATE }
			end
			return { group = "WEAPON" }
		end
		if wantPlate then
			return { group = pickOne(Data.TYPED_ARMOR_SLOTS), armorType = Data.ARMOR_PLATE }
		end
		return { group = weaponGroup() }
	elseif faction == "STEAMWHEEDLE" then
		if weekly then
			return { group = "ANY" }
		end
		if Orders.Random(10) <= 6 then
			return { group = pickOne(Data.ALL_ARMOR_SLOTS) }
		end
		return { group = weaponGroup() }
	elseif faction == "CITY" then
		local armorType = pickOne({ Data.ARMOR_CLOTH, Data.ARMOR_LEATHER, Data.ARMOR_MAIL })
		if weekly then
			return { group = "ARMOR", armorType = armorType }
		end
		return { group = pickOne(Data.TYPED_ARMOR_SLOTS), armorType = armorType }
	end
	-- Argent Dawn: armour.
	if weekly then
		return { group = "ARMOR" }
	end
	return { group = pickOne(Data.ALL_ARMOR_SLOTS) }
end

function Orders.MaxPlayerLevel()
	local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
	if type(maxLevel) ~= "number" or maxLevel < 1 then
		maxLevel = 60
	end
	return maxLevel
end

function Orders.Generate(weekly, faction)
	local db = ns.db
	faction = faction or Data.FACTION_ORDER[Orders.Random(#Data.FACTION_ORDER)]
	local playerLevel = UnitLevel("player") or 1
	local ask = Orders.MakeAsk(faction, weekly, playerLevel)
	local weights = weekly and Data.ASK_WEIGHTS.weekly or Data.ASK_WEIGHTS[faction] or Data.ASK_WEIGHTS.default
	local order = {
		id = db.orders.nextID,
		faction = faction,
		weekly = weekly and true or false,
		group = ask.group,
		armorType = ask.armorType,
		minQuality = pickWeighted(weights, { 1, 2, 3, 4 }),
		ilvlMin = max(1, playerLevel - Data.ILVL_RANGE),
		ilvlMax = playerLevel < Orders.MaxPlayerLevel() and playerLevel + Data.ILVL_RANGE or nil,
		count = weekly and Data.WEEKLY_COUNT or 1,
		sent = 0,
		gold = 0,
		rep = 0,
	}
	db.orders.nextID = db.orders.nextID + 1
	return order
end

---------------------------------------------------------------------------
-- The board
---------------------------------------------------------------------------

-- Moves queued orders onto the board while there is room.
function Orders.Promote()
	local orders = ns.db.orders
	local moved = false
	while #orders.daily < ns.Economy.DailySlots() and #orders.queue > 0 do
		table.insert(orders.daily, table.remove(orders.queue, 1))
		moved = true
	end
	return moved
end

function Orders.AddDaily(order)
	local orders = ns.db.orders
	if #orders.daily < ns.Economy.DailySlots() then
		table.insert(orders.daily, order)
		return "board"
	end
	table.insert(orders.queue, order)
	return "queue"
end

-- Handles any daily or weekly reset that happened since the last check. Returns true when the board changed.
function Orders.Check(now)
	local orders = ns.db.orders
	now = now or GetServerTime()
	local changed = false

	local dailyStart = Orders.PeriodStart(now, C_DateAndTime.GetSecondsUntilDailyReset(), Data.SECONDS_PER_DAY)
	if dailyStart > orders.dailyStamp + 60 then
		-- A queued order still waiting at the next daily reset is dropped. Only today's order arrives,
		-- however many days have passed.
		if orders.dailyStamp > 0 and #orders.queue > 0 then
			orders.queue = {}
		end
		Orders.AddDaily(Orders.Generate(false))
		orders.dailyStamp = dailyStart
		changed = true
	end

	local weeklyStart = Orders.PeriodStart(now, C_DateAndTime.GetSecondsUntilWeeklyReset(), Data.SECONDS_PER_WEEK)
	if weeklyStart > orders.weeklyStamp + 60 then
		-- The weekly has its own slot. An unfinished weekly stays, so no new one arrives this week.
		if not orders.weekly then
			orders.weekly = Orders.Generate(true)
		end
		orders.weeklyStamp = weeklyStart
		changed = true
	end

	if Orders.Promote() then
		changed = true
	end
	return changed
end

-- Keeps a timer for the next daily or weekly reset while the player is online.
local timer
function Orders.Schedule(onChange)
	if timer then
		timer:Cancel()
	end
	local seconds = math.min(Orders.SecondsUntilDaily(), Orders.SecondsUntilWeekly()) + 5
	timer = C_Timer.NewTimer(seconds, function()
		timer = nil
		if Orders.Check() and onChange then
			onChange()
		end
		Orders.Schedule(onChange)
	end)
	return seconds
end

-- Finds an order by id: returns order, list name ("daily", "queue", "weekly"), index.
function Orders.Get(id)
	local orders = ns.db.orders
	if orders.weekly and orders.weekly.id == id then
		return orders.weekly, "weekly"
	end
	for _, listName in ipairs({ "daily", "queue" }) do
		for index, order in ipairs(orders[listName]) do
			if order.id == id then
				return order, listName, index
			end
		end
	end
	return nil
end

local function removeOrder(id)
	local orders = ns.db.orders
	local order, listName, index = Orders.Get(id)
	if listName == "weekly" then
		orders.weekly = nil
	elseif listName then
		table.remove(orders[listName], index)
	end
	return order
end

---------------------------------------------------------------------------
-- Hand-in
---------------------------------------------------------------------------

local function inList(list, value)
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

function Orders.GroupMatches(group, piece)
	if group == "ANY" then
		return true
	elseif group == "WEAPON" then
		return piece.kind == "weapon"
	elseif group == "ARMOR" then
		return piece.kind == "armor"
	elseif Data.ARMOR_SLOTS[group] then
		return piece.kind == "armor" and inList(Data.ARMOR_SLOTS[group], piece.equipLoc)
	elseif Data.WEAPON_GROUPS[group] then
		return piece.kind == "weapon" and inList(Data.WEAPON_GROUPS[group], piece.equipLoc)
	end
	return false
end

-- Whether a piece fulfils an order. The window gives no hints; this only checks on Send.
function Orders.Matches(order, piece)
	if not Orders.GroupMatches(order.group, piece) then
		return false, "ERR_ORDER_SLOT"
	end
	if order.armorType and piece.armorType ~= order.armorType then
		return false, "ERR_ORDER_SLOT"
	end
	if piece.itemLevel < order.ilvlMin or (order.ilvlMax and piece.itemLevel > order.ilvlMax) then
		return false, "ERR_ORDER_ILVL"
	end
	if ns.Forge.Quality(piece) < order.minQuality then
		return false, "ERR_ORDER_QUALITY"
	end
	return true
end

-- Gold and reputation a piece would earn on an order (for one item of a weekly).
function Orders.Reward(order, piece)
	local steps = max(0, ns.Forge.Quality(piece) - order.minQuality)
	local multiplier = 1 + Data.STEP_BONUS * steps
	local value = ns.Forge.Value(piece)
	if order.weekly then
		return floor(Data.WEEKLY_GOLD_FACTOR * value * multiplier + 0.5), Data.WEEKLY_REP / order.count * multiplier
	end
	return floor(Data.DAILY_GOLD_FACTOR * value * multiplier + 0.5), Data.DAILY_REP * multiplier
end

-- Hands in a forged copy (from the anvil or the Workbench). The copy is used up instead of sold.
function Orders.Send(id, uid)
	local db = ns.db
	local order, listName = Orders.Get(id)
	if not order or listName == "queue" then
		return nil, "ERR_NO_ORDER"
	end
	local piece = ns.Forge.Find(uid)
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	local ok, err = Orders.Matches(order, piece)
	if not ok then
		return nil, err
	end
	local gold, rep = Orders.Reward(order, piece)
	ns.Forge.Take(uid)
	local result = { order = order, piece = piece, faction = order.faction }
	if order.weekly then
		order.sent = order.sent + 1
		order.gold = order.gold + gold
		order.rep = order.rep + rep
		result.sent, result.count = order.sent, order.count
		if order.sent < order.count then
			return result
		end
		gold, rep = order.gold, order.rep
	end
	result.done = true
	result.gold = gold
	result.rep = floor(rep + 0.5)
	removeOrder(id)
	ns.Economy.AddGold(gold)
	result.rankBefore, result.rankAfter = ns.Economy.AddRep(order.faction, result.rep)
	db.stats.orders = db.stats.orders + 1
	Orders.Promote()
	return result
end

-- Reputation an order would cost to reject.
function Orders.RejectCost(order)
	local base = order.weekly and Data.WEEKLY_REP or Data.DAILY_REP
	return floor(base * Data.REJECT_SHARE + 0.5)
end

function Orders.Reject(id)
	local order, listName = Orders.Get(id)
	if not order or listName == "queue" then
		return nil, "ERR_NO_ORDER"
	end
	local cost = Orders.RejectCost(order)
	removeOrder(id)
	local rankBefore, rankAfter = ns.Economy.AddRep(order.faction, -cost)
	Orders.Promote()
	return { order = order, rep = cost, rankBefore = rankBefore, rankAfter = rankAfter }
end
