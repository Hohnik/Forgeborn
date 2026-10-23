-- Forgeborn: events, slash commands and the minimap addon menu entry.
local addonName, ns = ...

local L = ns.L
local events = CreateFrame("Frame")
local handlers = {}

-- A new drop reached (or missed) the Workbench.
local function onDrop(piece, added, dropped)
	if ns.db.settings.announce then
		local name = piece.link or piece.name
		if added then
			ns.Print(string.format(L.CHAT_NEW_DROP, name))
			if dropped then
				ns.Print(string.format(L.CHAT_BENCH_DROPPED, ns.PieceTitle(dropped)))
			end
		else
			ns.Print(string.format(L.CHAT_DROP_SKIPPED, name))
		end
	end
	ns.Changed()
end

local function onOrdersChanged()
	ns.Print(L.CHAT_NEW_ORDERS)
	ns.Changed()
end

function handlers.ADDON_LOADED(name)
	if name ~= addonName then
		return
	end
	events:UnregisterEvent("ADDON_LOADED")
	ns.DB.Load()
	ns.Options.Register()
end

function handlers.PLAYER_LOGIN()
	ns.CityKey() -- works out the capital city while no restriction is active
	ns.RequestItemNames()
	ns.Orders.Check()
	ns.Orders.Schedule(onOrdersChanged)
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	ns.Loot.ClearBlocked()
	if isInitialLogin or isReloadingUi then
		ns.Loot.Snapshot()
	end
end

function handlers.BAG_UPDATE_DELAYED()
	ns.Loot.Scan(onDrop)
end

function handlers.LOOT_READY()
	ns.Loot.ClearBlocked()
	ns.Loot.OnLootReady()
end

function handlers.LOOT_OPENED(autoLoot, isFromItem)
	ns.Loot.OnLootOpened(autoLoot, isFromItem)
end

function handlers.LOOT_CLOSED()
	ns.Loot.OnLootClosed()
end

function handlers.LOOT_ITEM_ROLL_WON(itemLink)
	ns.Loot.OnRollWon(itemLink)
end

function handlers.QUEST_LOOT_RECEIVED(_, itemLink)
	ns.Loot.OnQuestLoot(itemLink)
end

function handlers.PLAYER_LEVEL_UP()
	ns.Changed()
end

-- Items that arrive while these windows are open were bought, mailed, traded or moved, not dropped.
local BLOCKING_WINDOWS = {
	MERCHANT_SHOW = { "MERCHANT", true }, MERCHANT_CLOSED = { "MERCHANT", false },
	MAIL_SHOW = { "MAIL", true }, MAIL_CLOSED = { "MAIL", false },
	TRADE_SHOW = { "TRADE", true }, TRADE_CLOSED = { "TRADE", false },
	AUCTION_HOUSE_SHOW = { "AUCTION", true }, AUCTION_HOUSE_CLOSED = { "AUCTION", false },
	BANKFRAME_OPENED = { "BANK", true }, BANKFRAME_CLOSED = { "BANK", false },
	GUILDBANKFRAME_OPENED = { "GUILDBANK", true }, GUILDBANKFRAME_CLOSED = { "GUILDBANK", false },
}
for event, entry in pairs(BLOCKING_WINDOWS) do
	handlers[event] = function()
		ns.Loot.SetBlocked(entry[1], entry[2])
	end
end

events:SetScript("OnEvent", function(_, event, ...)
	local handler = handlers[event]
	if handler then
		handler(...)
	end
end)
for event in pairs(handlers) do
	events:RegisterEvent(event)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function printRecords()
	local records, stats = ns.db.records, ns.db.stats
	ns.Print(L.RECORDS)
	for quality = 0, ns.Data.MAX_QUALITY do
		if records.best[quality] then
			ns.Print(string.format("  %s: +%d", ns.Colorize(ns.QualityName(quality), quality), records.best[quality]))
		end
	end
	if records.bestSale > 0 then
		ns.Print(string.format("  %s: %s %s", L.RECORD_BEST_SALE, ns.Money(records.bestSale), records.bestSaleName and ns.Colorize(records.bestSaleName, records.bestSaleQuality or 1) or ""))
	end
	ns.Print(string.format("  %s: %d", L.RECORD_STREAK, records.bestStreak))
	ns.Print(string.format("  %s: %d", L.RECORD_GRAY_TO_ORANGE, records.grayToOrange))
	ns.Print(string.format("  %s: %d · %s: %d · %s: %d · %s: %d", L.STAT_SWINGS, stats.swings, L.STAT_BREAKS, stats.breaks, L.STAT_SOLD, stats.sold, L.STAT_ORDERS, stats.orders))
end

local function resetData()
	ns.Widgets.Confirm(L.CONFIRM_RESET, function()
		ForgebornCharDB = nil
		ns.DB.Load()
		ns.UI.staged = {}
		ns.Orders.Check()
		ns.Print(L.CHAT_RESET)
		ns.Changed()
	end)
end

SLASH_FORGEBORN1 = "/forge"
SLASH_FORGEBORN2 = "/forgeborn"
SlashCmdList.FORGEBORN = function(input)
	local command = string.lower(strtrim(input or ""))
	if command == "" then
		ns.UI.Toggle()
	elseif command == "shop" then
		ns.Shop.Toggle()
	elseif command == "records" then
		printRecords()
	elseif command == "settings" or command == "options" then
		ns.Options.Open()
	elseif command == "reset" then
		resetData()
	else
		ns.Print(L.HELP)
	end
end

---------------------------------------------------------------------------
-- Minimap addon menu (the addon compartment). Named in the TOC.
---------------------------------------------------------------------------

function Forgeborn_OnCompartmentClick(_, buttonName)
	if buttonName == "RightButton" then
		ns.Shop.Toggle()
	else
		ns.UI.Toggle()
	end
end

function Forgeborn_OnCompartmentEnter(_, button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText(L.TITLE)
	GameTooltip:AddLine(L.COMPARTMENT_LEFT, 1, 1, 1)
	GameTooltip:AddLine(L.COMPARTMENT_RIGHT, 1, 1, 1)
	GameTooltip:Show()
end

function Forgeborn_OnCompartmentLeave()
	GameTooltip:Hide()
end
