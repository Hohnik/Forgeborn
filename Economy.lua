-- Forgeborn: addon gold, reputation, the Shop, lockboxes, tools, one-use items and the Display case.
-- Functions return an error key (a Locales key) as the second value when something can't be done.
local _, ns = ...

local Data, Rules = ns.Data, ns.Rules
local Economy = {}
ns.Economy = Economy

local floor, max, min = math.floor, math.max, math.min

-- Randomness for lockboxes. math.random, no seeds and no pity protection. Tests may replace it.
function Economy.Random(n)
	return math.random(n)
end

-- Combined tool effects of the shelf.
function Economy.Mods()
	return Rules.ModsFromShelf(ns.db.shelf)
end

---------------------------------------------------------------------------
-- Gold
---------------------------------------------------------------------------

function Economy.AddGold(copper)
	ns.db.gold = ns.db.gold + floor(copper)
end

function Economy.CanAfford(copper)
	return ns.db.gold >= copper
end

function Economy.Spend(copper)
	if ns.db.gold < copper then
		return false
	end
	ns.db.gold = ns.db.gold - copper
	return true
end

---------------------------------------------------------------------------
-- Reputation
---------------------------------------------------------------------------

-- Rank 1 Neutral .. 5 Exalted for a reputation total.
function Economy.RankOf(value)
	local rank = 1
	for i = 2, #Data.REP_THRESHOLDS do
		if value >= Data.REP_THRESHOLDS[i] then
			rank = i
		end
	end
	return rank
end

function Economy.Rank(faction)
	return Economy.RankOf(ns.db.rep[faction] or 0)
end

-- rank, progress into the rank, size of the rank (for the reputation bar).
function Economy.RepProgress(faction)
	local value = ns.db.rep[faction] or 0
	local rank = Economy.RankOf(value)
	local start = Data.REP_THRESHOLDS[rank]
	local stop = Data.REP_THRESHOLDS[rank + 1] or (Data.REP_MAX + 1)
	return rank, value - start, stop - start
end

-- Returns the rank before and after.
function Economy.AddRep(faction, amount)
	local before = Economy.Rank(faction)
	ns.db.rep[faction] = min(max((ns.db.rep[faction] or 0) + floor(amount + 0.5), 0), Data.REP_MAX)
	return before, Economy.Rank(faction)
end

-- needs = { faction = "STEAMWHEEDLE", rank = 3 } or nil.
function Economy.Meets(needs)
	return not needs or Economy.Rank(needs.faction) >= needs.rank
end

---------------------------------------------------------------------------
-- Faction perks
---------------------------------------------------------------------------

function Economy.DailySlots()
	if Economy.Rank("CITY") >= Data.RANK_HONORED then
		return Data.DAILY_SLOTS + Data.DAILY_SLOTS_BONUS
	end
	return Data.DAILY_SLOTS
end

function Economy.DisplaySlots()
	local rank = Economy.Rank("ARGENT")
	local slots = Data.DISPLAY_BASE_SLOTS
	if rank >= Data.RANK_FRIENDLY then
		slots = slots + 1
	end
	if rank >= Data.RANK_HONORED then
		slots = slots + 1
	end
	if rank >= Data.RANK_EXALTED then
		slots = slots + 1
	end
	return slots
end

-- Bonus to sale value from the Display case (0.01 = +1%). Only trophies inside the current slot count.
function Economy.TrophyBonus()
	local display = ns.db.display
	local bonus = 0
	for i = 1, min(#display, Economy.DisplaySlots()) do
		bonus = bonus + (Data.TROPHY_BONUS[display[i].quality] or 0)
	end
	return bonus * (Data.TROPHY_MULTIPLIER[Economy.Rank("ARGENT")] or 1)
end

function Economy.LockboxPrice(id)
	local price = Data.LOCKBOXES[id].price
	if Economy.Rank("STEAMWHEEDLE") >= Data.RANK_EXALTED then
		price = floor(price * (1 - Data.LOCKBOX_DISCOUNT) + 0.5)
	end
	return price
end

function Economy.ConsumablePrice(id)
	local price = Data.CONSUMABLES[id].price
	local discount = Data.SUPPLY_DISCOUNT[Economy.Rank("CITY")]
	if discount then
		price = floor(price * (1 - discount) + 0.5)
	end
	return price
end

---------------------------------------------------------------------------
-- Tools and the shelf
---------------------------------------------------------------------------

-- Lockbox tools of a base rank (faction-exclusive tools are not in lockboxes).
function Economy.ToolPool(rank)
	local pool = {}
	for _, id in ipairs(Data.TOOL_ORDER) do
		local def = Data.TOOLS[id]
		if def.base == rank and not def.exclusive then
			table.insert(pool, id)
		end
	end
	return pool
end

function Economy.FindTool(id)
	for slot = 1, Data.SHELF_SLOTS do
		local tool = ns.db.shelf[slot]
		if tool and tool.id == id then
			return slot, tool
		end
	end
	return nil
end

function Economy.FreeShelfSlot()
	for slot = 1, Data.SHELF_SLOTS do
		if not ns.db.shelf[slot] then
			return slot
		end
	end
	return nil
end

-- A tool arrives. A duplicate makes the owned tool one rarity step stronger; at legendary it is salvaged for gold.
-- With a full shelf it waits as the pending tool until the player places or discards it.
function Economy.ReceiveTool(id, rank)
	local db = ns.db
	local slot, owned = Economy.FindTool(id)
	if not owned and db.pendingTool and db.pendingTool.id == id then
		owned = db.pendingTool
	end
	if owned then
		if owned.rank < Data.RANK_LEGENDARY then
			owned.rank = owned.rank + 1
			return { kind = "upgrade", id = id, rank = owned.rank, slot = slot }
		end
		local gold = Data.RANK_SALVAGE[rank] or 0
		Economy.AddGold(gold)
		return { kind = "salvage", id = id, rank = owned.rank, gold = gold }
	end
	local free = Economy.FreeShelfSlot()
	if free then
		db.shelf[free] = { id = id, rank = rank }
		return { kind = "new", id = id, rank = rank, slot = free }
	end
	db.pendingTool = { id = id, rank = rank }
	return { kind = "pending", id = id, rank = rank }
end

-- Puts the pending tool into a shelf slot. Returns the tool it replaced, if any.
function Economy.PlacePendingTool(slot)
	local db = ns.db
	if not db.pendingTool then
		return nil, "ERR_NO_PENDING_TOOL"
	end
	if type(slot) ~= "number" or slot < 1 or slot > Data.SHELF_SLOTS then
		return nil, "ERR_BAD_SLOT"
	end
	local replaced = db.shelf[slot]
	db.shelf[slot] = db.pendingTool
	db.pendingTool = nil
	return true, replaced
end

function Economy.DiscardPendingTool()
	if not ns.db.pendingTool then
		return nil, "ERR_NO_PENDING_TOOL"
	end
	local tool = ns.db.pendingTool
	ns.db.pendingTool = nil
	return tool
end

function Economy.RemoveTool(slot)
	local tool = ns.db.shelf[slot]
	if not tool then
		return nil, "ERR_BAD_SLOT"
	end
	ns.db.shelf[slot] = nil
	return tool
end

function Economy.MoveTool(from, to)
	local shelf = ns.db.shelf
	if not shelf[from] or type(to) ~= "number" or to < 1 or to > Data.SHELF_SLOTS then
		return nil, "ERR_BAD_SLOT"
	end
	shelf[from], shelf[to] = shelf[to], shelf[from]
	return true
end

---------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------

-- Picks an entry of a lockbox table. Chances are out of 1000.
function Economy.RollLockbox(id, rand)
	local entries = Data.LOCKBOXES[id].table
	local roll, sum = rand(1000), 0
	for _, entry in ipairs(entries) do
		sum = sum + entry.chance
		if roll <= sum then
			return entry
		end
	end
	return entries[#entries]
end

function Economy.CanBuyLockbox(id)
	local box = Data.LOCKBOXES[id]
	if not box then
		return false, "ERR_UNKNOWN"
	end
	if not Economy.Meets(box.needs) then
		return false, "ERR_LOCKED"
	end
	if ns.db.pendingTool then
		return false, "ERR_PENDING_TOOL"
	end
	if not Economy.CanAfford(Economy.LockboxPrice(id)) then
		return false, "ERR_NO_GOLD"
	end
	return true
end

-- Buys and opens a lockbox. Returns what was inside.
function Economy.BuyLockbox(id)
	local ok, err = Economy.CanBuyLockbox(id)
	if not ok then
		return nil, err
	end
	local price = Economy.LockboxPrice(id)
	Economy.Spend(price)
	ns.db.stats.lockboxes = ns.db.stats.lockboxes + 1
	local entry = Economy.RollLockbox(id, Economy.Random)
	local result = { box = id, price = price, kind = entry.kind }
	if entry.kind == "tool" then
		local pool = Economy.ToolPool(entry.rank)
		result.tool = pool[Economy.Random(#pool)]
		result.rank = entry.rank
		result.receive = Economy.ReceiveTool(result.tool, entry.rank)
	elseif entry.kind == "item" then
		ns.db.consumables[entry.id] = (ns.db.consumables[entry.id] or 0) + 1
		result.item = entry.id
	elseif entry.kind == "purse" then
		local amount = entry.min + Economy.Random(entry.max - entry.min + 1) - 1
		result.gold = floor(amount / 100) * 100
		Economy.AddGold(result.gold)
	end
	return result
end

function Economy.CanBuyConsumable(id)
	local def = Data.CONSUMABLES[id]
	if not def then
		return false, "ERR_UNKNOWN"
	end
	if not Economy.Meets(def.needs) then
		return false, "ERR_LOCKED"
	end
	if not Economy.CanAfford(Economy.ConsumablePrice(id)) then
		return false, "ERR_NO_GOLD"
	end
	return true
end

function Economy.BuyConsumable(id)
	local ok, err = Economy.CanBuyConsumable(id)
	if not ok then
		return nil, err
	end
	local price = Economy.ConsumablePrice(id)
	Economy.Spend(price)
	ns.db.consumables[id] = (ns.db.consumables[id] or 0) + 1
	return { kind = "item", item = id, price = price }
end

function Economy.CanBuyTool(faction, index)
	local ware = Data.FACTIONS[faction] and Data.FACTIONS[faction].wares[index]
	if not ware or ware.kind ~= "tool" then
		return false, "ERR_UNKNOWN"
	end
	if Economy.Rank(faction) < ware.rank then
		return false, "ERR_LOCKED"
	end
	if ns.db.pendingTool then
		return false, "ERR_PENDING_TOOL"
	end
	if not Economy.CanAfford(ware.price) then
		return false, "ERR_NO_GOLD"
	end
	return true
end

-- Buys a faction tool (Thorium Brotherhood). Arrives at its base rank, like a lockbox tool.
function Economy.BuyTool(faction, index)
	local ok, err = Economy.CanBuyTool(faction, index)
	if not ok then
		return nil, err
	end
	local ware = Data.FACTIONS[faction].wares[index]
	Economy.Spend(ware.price)
	local rank = Data.TOOLS[ware.id].base
	return { kind = "tool", tool = ware.id, rank = rank, price = ware.price, receive = Economy.ReceiveTool(ware.id, rank) }
end

-- Uses a one-use item on the piece on the anvil: the next swings are safe.
function Economy.UseConsumable(id)
	local def = Data.CONSUMABLES[id]
	local piece = ns.db.anvil
	if not def then
		return nil, "ERR_UNKNOWN"
	end
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	if (ns.db.consumables[id] or 0) < 1 then
		return nil, "ERR_NONE_LEFT"
	end
	ns.db.consumables[id] = ns.db.consumables[id] - 1
	piece.safe = (piece.safe or 0) + def.safe
	return def.safe
end

function Economy.RemoveTrophy(index)
	local trophy = ns.db.display[index]
	if not trophy then
		return nil, "ERR_BAD_SLOT"
	end
	table.remove(ns.db.display, index)
	return trophy
end
