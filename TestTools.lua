-- Forgeborn retail test build: commands that speed up testing (/forge test ...).
-- Only the TOC of branch retail-test loads this file; the Forever addon never has these commands.
local _, ns = ...

local Data = ns.Data

local function say(text, ...)
	ns.Print("|cffff8000[test]|r " .. string.format(text, ...))
end

local FACTIONS = { thorium = "THORIUM", steamwheedle = "STEAMWHEEDLE", city = "CITY", argent = "ARGENT" }

local HELP = {
	"/forge test drop [n | item link]  - copy weapons or armour from your bags to the Workbench, as if looted (default 1)",
	"/forge test gold <gold>           - add addon gold (e.g. 50)",
	"/forge test rep <faction> <rep>   - add reputation: thorium, steamwheedle, city or argent (e.g. city 9000)",
	"/forge test orders                - a daily and a weekly reset now (new orders)",
	"/forge test level <n>             - set the anvil item to +n",
	"/forge test embers                - fill the embers to one swing before Frenzy",
	"/forge test tool <TOOL_ID> [rank] - get a tool (e.g. FIERY_CORE 3); see Data.lua for the IDs",
	"/forge test stones [n]            - add n of each sharpening stone (default 5)",
	"/forge test state                 - print gold, reputation, shelf and orders",
}

-- Weapons and armour in the bags, as links.
local function bagItems()
	local links = {}
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and ns.Loot.IsEligible(info.hyperlink) then
				table.insert(links, info.hyperlink)
			end
		end
	end
	return links
end

local function addDrop(link)
	ns.Loot.MakePiece(link, function(piece)
		local added, dropped = ns.Forge.AddDrop(piece)
		if added then
			say("%s is on the Workbench.", piece.link or piece.name)
			if dropped then
				say("%s left the Workbench to make room.", ns.PieceTitle(dropped))
			end
		else
			say("%s was not added: the Workbench is full of better items.", piece.link or piece.name)
		end
		ns.Changed()
	end)
end

local commands = {}

function commands.drop(rest)
	if rest:find("|Hitem:", 1, true) then
		if not ns.Loot.IsEligible(rest) then
			say("That is not a weapon or armour piece Forgeborn can forge.")
			return
		end
		addDrop(rest)
		return
	end
	local count = math.max(1, math.min(tonumber(rest) or 1, Data.WORKBENCH_SLOTS))
	local links = bagItems()
	if #links == 0 then
		say("No weapon or armour piece in your bags.")
		return
	end
	for i = 1, math.min(count, #links) do
		addDrop(links[i])
	end
end

function commands.gold(rest)
	local gold = tonumber(rest)
	if not gold then
		say("Usage: /forge test gold <gold>")
		return
	end
	ns.Economy.AddGold(math.floor(gold * 10000))
	say("Addon gold: %s", ns.Money(ns.db.gold))
	ns.Changed()
end

function commands.rep(rest)
	local name, amount = rest:match("^(%a+)%s+(%-?%d+)$")
	local faction = name and FACTIONS[string.lower(name)]
	if not faction then
		say("Usage: /forge test rep <thorium|steamwheedle|city|argent> <amount>")
		return
	end
	ns.Economy.AddRep(faction, tonumber(amount))
	ns.Orders.Promote()
	say("%s: %d (%s)", ns.FactionName(faction), ns.db.rep[faction], ns.StandingName(ns.Economy.Rank(faction)))
	ns.Changed()
end

function commands.orders()
	ns.db.orders.dailyStamp = 0
	ns.db.orders.weeklyStamp = 0
	ns.Orders.Check()
	say("New orders: %d daily, %d waiting, weekly %s.", #ns.db.orders.daily, #ns.db.orders.queue, ns.db.orders.weekly and "yes" or "no")
	ns.Changed()
end

local function anvilPiece()
	local piece = ns.db.anvil
	if not piece then
		say("Put an item on the anvil first.")
	end
	return piece
end

function commands.level(rest)
	local piece = anvilPiece()
	local level = tonumber(rest)
	if not piece then
		return
	end
	if not level or level < 0 then
		say("Usage: /forge test level <n>")
		return
	end
	piece.level = math.floor(level)
	say("%s", ns.PieceTitle(piece))
	ns.Changed()
end

function commands.embers()
	local piece = anvilPiece()
	if piece then
		piece.frenzy = 0
		piece.embers = ns.Economy.Mods().frenzyEvery - 1
		say("Embers %d: the next normal swing fires Frenzy.", piece.embers)
		ns.Changed()
	end
end

function commands.tool(rest)
	local id, rank = rest:match("^(%S+)%s*(%d*)$")
	id = id and string.upper(id)
	local def = id and Data.TOOLS[id]
	if not def then
		say("Usage: /forge test tool <TOOL_ID> [rank]. IDs: %s", table.concat(Data.TOOL_ORDER, ", "))
		return
	end
	rank = math.max(def.base, math.min(tonumber(rank) or def.base, Data.RANK_LEGENDARY))
	local result = ns.Economy.ReceiveTool(id, rank)
	say("%s (%s): %s", ns.ToolName(id), ns.RankName(result.rank), result.kind)
	ns.Changed()
end

function commands.stones(rest)
	local count = math.max(1, tonumber(rest) or 5)
	for _, id in ipairs(Data.CONSUMABLE_ORDER) do
		ns.db.consumables[id] = (ns.db.consumables[id] or 0) + count
	end
	say("+%d of each sharpening stone.", count)
	ns.Changed()
end

function commands.state()
	local db = ns.db
	say("Addon gold %s · Workbench %d/4 · anvil %s", ns.Money(db.gold), (function()
		local n = 0
		for slot = 1, Data.WORKBENCH_SLOTS do
			if db.workbench[slot] then
				n = n + 1
			end
		end
		return n
	end)(), db.anvil and ns.PieceTitle(db.anvil) or "empty")
	for _, faction in ipairs(Data.FACTION_ORDER) do
		say("%s: %d (%s)", ns.FactionName(faction), db.rep[faction], ns.StandingName(ns.Economy.Rank(faction)))
	end
	local tools = {}
	for slot = 1, Data.SHELF_SLOTS do
		local tool = db.shelf[slot]
		table.insert(tools, tool and (tool.id .. " " .. tool.rank) or "-")
	end
	say("Shelf: %s · pending: %s", table.concat(tools, ", "), db.pendingTool and db.pendingTool.id or "-")
	say("Orders: %d daily, %d waiting, weekly %s · order item levels %d-%s", #db.orders.daily, #db.orders.queue,
		db.orders.weekly and (db.orders.weekly.sent .. "/" .. db.orders.weekly.count) or "-",
		db.orders.daily[1] and db.orders.daily[1].ilvlMin or 0, db.orders.daily[1] and tostring(db.orders.daily[1].ilvlMax or "-") or "-")
end

function commands.help()
	for _, line in ipairs(HELP) do
		ns.Print(line)
	end
end

local original = SlashCmdList.FORGEBORN
SlashCmdList.FORGEBORN = function(input)
	local command, rest = (input or ""):match("^%s*[Tt][Ee][Ss][Tt]%s*(%S*)%s*(.-)%s*$")
	if not command then
		return original(input)
	end
	local handler = commands[string.lower(command)] or commands.help
	handler(rest or "")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	say("Retail test build of Forgeborn. Test commands: /forge test")
end)
