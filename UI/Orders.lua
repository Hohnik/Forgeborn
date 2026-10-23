-- Forgeborn: the crafting order cards. Drag a forged copy onto a card's slot, then click Send.
-- The window gives no hints about which item fits; Send checks it.
local _, ns = ...

local L, Data, W, Layout = ns.L, ns.Data, ns.Widgets, ns.Layout
local Drag = W.Drag
local UI = ns.UI

-- The cards: { x, y, width, height, gap } in the orders box (UI/Layout.lua).
local CARDS_X, CARDS_Y, CARD_WIDTH, CARD_HEIGHT, CARD_GAP = unpack(Layout.cards)

local function placeCard(card, index)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", CARDS_X, -CARDS_Y - (index - 1) * (CARD_HEIGHT + CARD_GAP))
end
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
	placeCard(card, index)

	card.header = W.Label(card, "GameFontNormalSmall")
	W.PlaceText(card.header, Layout.cardHeader)
	card.ask = W.Label(card, "GameFontHighlight")
	W.PlaceText(card.ask, Layout.cardAsk)
	card.ask:SetWordWrap(false)
	card.range = W.Label(card, "GameFontHighlightSmall")
	W.PlaceText(card.range, Layout.cardRange)
	card.reward = W.Label(card, "GameFontHighlightSmall")
	W.PlaceText(card.reward, Layout.cardReward)
	card.reward:SetWordWrap(true)

	card.empty = W.Label(card, "GameFontDisable")
	W.PlaceText(card.empty, Layout.cardEmpty, "CENTER")
	card.empty:SetWordWrap(true)

	local slot = W.CreateSlot(card)
	W.PlaceSlot(slot, Layout.cardSlot)
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
	slot:SetScript("OnClick", function(self, button)
		if button == "RightButton" and card.order and not Drag.ClickAfterDrag(self) then
			UI.staged[card.order.id] = nil
			ns.Changed()
		end
	end)
	-- Drag the staged item out: onto another card, the anvil, the Workbench or the Display case, or anywhere
	-- else to take it off the card.
	slot:SetScript("OnDragStart", function(self)
		local piece = stagedPiece(card.order)
		if piece then
			Drag.Start({ kind = "piece", uid = piece.uid, from = "order", order = card.order.id, icon = piece.icon }, self)
		end
	end)
	slot:SetScript("OnDragStop", function()
		local payload = Drag.payload
		if payload and payload.order then
			UI.staged[payload.order] = nil
		end
		Drag.Stop()
		ns.Changed()
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

	card.send = W.Button(card, L.SEND, Layout.cardSend[3], Layout.cardSend[4])
	W.Place(card.send, Layout.cardSend)
	card.send:SetScript("OnClick", function()
		send(card)
	end)
	card.reject = W.Button(card, L.REJECT, Layout.cardReject[3], Layout.cardReject[4])
	W.Place(card.reject, Layout.cardReject)
	card.reject:SetScript("OnClick", function()
		reject(card)
	end)
	return card
end

function UI.BuildOrders(parent)
	local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	W.Place(inset, Layout.orders)
	W.PlaceText(W.Label(inset, "GameFontNormal", L.ORDERS), Layout.ordersTitle)
	waitingText = W.Label(inset, "GameFontHighlightSmall")
	W.PlaceText(waitingText, Layout.waiting, "RIGHT")
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
		placeCard(card, index)
		card:Show()
		fillCard(card, orders.daily[i], L.DAILY)
		if not orders.daily[i] then
			card.empty:SetText(string.format(L.NO_DAILY, untilDaily))
		end
		index = index + 1
	end
	local weeklyCard = cards[index]
	placeCard(weeklyCard, index)
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
