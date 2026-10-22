-- Forgeborn: the crafting order cards. Drag a forged copy onto a card's slot, then click Send.
-- The window gives no hints about which item fits; Send checks it.
local _, ns = ...

local L, Data, W = ns.L, ns.Data, ns.Widgets
local Drag = W.Drag
local UI = ns.UI

local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 334, 86, 4
local MAX_DAILY_CARDS = Data.DAILY_SLOTS + Data.DAILY_SLOTS_BONUS
local cards = {}
local waitingText

-- Staged hand-ins: order id -> piece uid. Only in the window; nothing moves until Send.
UI.staged = {}

local function tooltipHide()
	GameTooltip:Hide()
end

local function stagedPiece(order)
	local uid = order and UI.staged[order.id]
	return uid and ns.Forge.Find(uid) or nil
end

local function stage(order, uid)
	for id, staged in pairs(UI.staged) do
		if staged == uid then
			UI.staged[id] = nil
		end
	end
	UI.staged[order.id] = uid
end

local function send(card)
	local order = card.order
	local piece = stagedPiece(order)
	if not order then
		return
	end
	if not piece then
		ns.Error("ERR_NOTHING_STAGED")
		return
	end
	local result, err = ns.Orders.Send(order.id, piece.uid)
	if not result then
		ns.Error(err)
		return
	end
	UI.staged[order.id] = nil
	local faction = ns.FactionName(result.faction)
	if result.done then
		ns.PlaySound("UI_GARRISON_COMMAND_TABLE_CHEST_UNLOCK_GOLD_SUCCESS")
		ns.Print(string.format(L.CHAT_ORDER_DONE, ns.OrderAskText(order), ns.Money(result.gold), BreakUpLargeNumbers(result.rep), faction))
		if result.rankAfter > result.rankBefore then
			ns.PlaySound("UI_70_ARTIFACT_FORGE_TRAIT_FINALRANK")
			ns.Print(string.format(L.CHAT_RANK_UP, ns.StandingName(result.rankAfter), faction))
		end
	else
		ns.PlaySound("IG_QUEST_LIST_COMPLETE")
		ns.Print(string.format(L.CHAT_WEEKLY_PROGRESS, ns.PieceTitle(piece), result.sent, result.count))
	end
	ns.Changed()
end

local function reject(card)
	local order = card.order
	if not order then
		return
	end
	local text = string.format(L.CONFIRM_REJECT, ns.OrderAskText(order), ns.Orders.RejectCost(order), ns.FactionName(order.faction))
	if order.weekly and order.sent > 0 then
		text = text .. "\n\n" .. L.CONFIRM_REJECT_WEEKLY
	end
	W.Confirm(text, function()
		local current = ns.Orders.Get(order.id)
		if not current then
			return
		end
		local result, err = ns.Orders.Reject(order.id)
		if result then
			UI.staged[order.id] = nil
			ns.PlaySound("IG_QUEST_LOG_ABANDON_QUEST")
			ns.Print(string.format(L.CHAT_REJECTED, ns.OrderAskText(order), result.rep, ns.FactionName(order.faction)))
		end
		UI.Act(result, err)
	end)
end

local function buildCard(parent, index)
	local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	card:SetSize(CARD_WIDTH, CARD_HEIGHT)
	card:SetPoint("TOPLEFT", 10, -32 - (index - 1) * (CARD_HEIGHT + CARD_GAP))

	card.header = W.Label(card, "GameFontNormalSmall")
	card.header:SetPoint("TOPLEFT", 10, -8)
	card.ask = W.Label(card, "GameFontHighlight")
	card.ask:SetPoint("TOPLEFT", 10, -24)
	card.ask:SetWidth(260)
	card.ask:SetJustifyH("LEFT")
	card.ask:SetWordWrap(false)
	card.range = W.Label(card, "GameFontHighlightSmall")
	card.range:SetPoint("TOPLEFT", 10, -42)
	-- Left of the Send button, which starts 172 px in.
	card.reward = W.Label(card, "GameFontHighlightSmall")
	card.reward:SetPoint("TOPLEFT", 10, -58)
	card.reward:SetWidth(156)
	card.reward:SetJustifyH("LEFT")
	card.reward:SetWordWrap(true)

	card.empty = W.Label(card, "GameFontDisable")
	card.empty:SetPoint("CENTER")
	card.empty:SetWidth(CARD_WIDTH - 24)
	card.empty:SetWordWrap(true)

	local slot = W.CreateSlot(card)
	slot:SetPoint("TOPRIGHT", -10, -8)
	card.slot = slot
	slot:SetScript("OnEnter", function(self)
		local piece = stagedPiece(card.order)
		if piece then
			W.PieceTooltip(self, piece, "order")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.ORDER_SLOT)
			GameTooltip:AddLine(L.ORDER_SLOT_TIP, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	slot:SetScript("OnLeave", tooltipHide)
	slot:SetScript("OnClick", function(_, button)
		if button == "RightButton" and card.order then
			UI.staged[card.order.id] = nil
			ns.Changed()
		end
	end)
	Drag.Register({
		frame = slot,
		accept = function(p)
			return p.kind == "piece" and card.order ~= nil
		end,
		drop = function(p)
			stage(card.order, p.uid)
			ns.Changed()
		end,
	})

	card.send = W.Button(card, L.SEND, 74, 22)
	card.send:SetPoint("BOTTOMRIGHT", -88, 8)
	card.send:SetScript("OnClick", function()
		send(card)
	end)
	card.reject = W.Button(card, L.REJECT, 74, 22)
	card.reject:SetPoint("BOTTOMRIGHT", -10, 8)
	card.reject:SetScript("OnClick", function()
		reject(card)
	end)
	return card
end

function UI.BuildOrders(parent)
	local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 418, -60)
	inset:SetSize(354, 488)
	W.Label(inset, "GameFontNormal", L.ORDERS):SetPoint("TOPLEFT", 12, -10)
	waitingText = W.Label(inset, "GameFontHighlightSmall")
	waitingText:SetPoint("TOPRIGHT", -12, -12)
	for i = 1, MAX_DAILY_CARDS + 1 do
		cards[i] = buildCard(inset, i)
	end
	UI.cards = cards
	UI.waitingText = waitingText
end

local function fillCard(card, order, kindText)
	card.order = order
	local hasOrder = order ~= nil
	card.header:SetShown(hasOrder)
	card.ask:SetShown(hasOrder)
	card.range:SetShown(hasOrder)
	card.reward:SetShown(hasOrder)
	card.slot:SetShown(hasOrder)
	card.send:SetShown(hasOrder)
	card.reject:SetShown(hasOrder)
	card.empty:SetShown(not hasOrder)
	if not hasOrder then
		return
	end
	card.header:SetText(ns.FactionName(order.faction) .. " · " .. kindText)
	card.ask:SetText(ns.Colorize(ns.OrderAskText(order), order.minQuality))
	local range = ns.ItemLevelRangeText(order)
	if order.weekly then
		range = range .. " · " .. string.format(L.SENT_OF, order.sent, order.count)
	end
	card.range:SetText(range)

	local piece = stagedPiece(order)
	if not piece then
		UI.staged[order.id] = nil
	end
	if piece then
		W.SetSlot(card.slot, piece.icon, ns.Forge.Quality(piece))
		local gold, rep = ns.Orders.Reward(order, piece)
		if order.weekly then
			gold, rep = order.gold + gold, order.rep + rep
		end
		card.reward:SetText(string.format(L.REWARD, ns.Money(gold), BreakUpLargeNumbers(math.floor(rep + 0.5))))
	else
		W.SetSlot(card.slot, nil)
		if order.weekly then
			if order.sent > 0 then
				card.reward:SetText(string.format(L.REWARD_SO_FAR, ns.Money(order.gold), BreakUpLargeNumbers(math.floor(order.rep + 0.5))))
			else
				card.reward:SetText(string.format(L.REWARD_PREVIEW_WEEKLY, Data.WEEKLY_GOLD_FACTOR, BreakUpLargeNumbers(Data.WEEKLY_REP)))
			end
		else
			card.reward:SetText(string.format(L.REWARD_PREVIEW_DAILY, Data.DAILY_GOLD_FACTOR, BreakUpLargeNumbers(Data.DAILY_REP)))
		end
	end
	card.send:SetEnabled(piece ~= nil)
end

function UI.UpdateOrders()
	local orders = ns.db.orders
	for id in pairs(UI.staged) do
		local order, listName = ns.Orders.Get(id)
		if not order or listName == "queue" then
			UI.staged[id] = nil
		end
	end
	local dailyCards = math.min(math.max(ns.Economy.DailySlots(), #orders.daily), MAX_DAILY_CARDS)
	local untilDaily = ns.DurationText(ns.Orders.SecondsUntilDaily())
	local index = 1
	for i = 1, dailyCards do
		local card = cards[index]
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", 10, -32 - (index - 1) * (CARD_HEIGHT + CARD_GAP))
		card:Show()
		fillCard(card, orders.daily[i], L.DAILY)
		if not orders.daily[i] then
			card.empty:SetText(string.format(L.NO_DAILY, untilDaily))
		end
		index = index + 1
	end
	local weeklyCard = cards[index]
	weeklyCard:ClearAllPoints()
	weeklyCard:SetPoint("TOPLEFT", 10, -32 - (index - 1) * (CARD_HEIGHT + CARD_GAP))
	weeklyCard:Show()
	fillCard(weeklyCard, orders.weekly, L.WEEKLY)
	if not orders.weekly then
		weeklyCard.empty:SetText(string.format(L.NO_WEEKLY, ns.DurationText(ns.Orders.SecondsUntilWeekly())))
	end
	for i = index + 1, #cards do
		cards[i]:Hide()
		cards[i].order = nil
	end
	if #orders.queue > 0 then
		waitingText:SetText(string.format(L.WAITING, #orders.queue))
	else
		waitingText:SetText("")
	end
end
