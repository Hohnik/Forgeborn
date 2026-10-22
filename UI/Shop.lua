-- Forgeborn: the Shop. A General tab with lockboxes and one-use items, and one tab per faction with its
-- reputation bar and the wares its ranks unlock.
local _, ns = ...

local L, Data, W = ns.L, ns.Data, ns.Widgets
local Shop = {}
ns.Shop = Shop

local TABS = { "GENERAL", "THORIUM", "STEAMWHEEDLE", "CITY", "ARGENT" }
local ROWS, ROW_HEIGHT = 6, 48
local PERK_ICONS = {
	LOCKBOX_DISCOUNT = "Interface\\Icons\\INV_Misc_Coin_02",
	ORDER_SLOT = "Interface\\Icons\\INV_Misc_Note_01",
	SUPPLY_DISCOUNT_1 = "Interface\\Icons\\INV_Misc_Coin_03",
	SUPPLY_DISCOUNT_2 = "Interface\\Icons\\INV_Misc_Coin_04",
	DISPLAY_SLOT_1 = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	DISPLAY_SLOT_2 = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	TROPHY_BONUS_1 = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
	TROPHY_BONUS_2 = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
}

local frame
local header = {}
local rows = {}
local reveal = {}
local goldText
local selected = 1
local lastResult

local function tooltipHide()
	GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------

local function revealText(result)
	if result.kind == "tool" then
		local receive = result.receive
		local quality = Data.RANK_QUALITY[receive.rank]
		local name = ns.Colorize(ns.ToolName(result.tool), quality)
		if receive.kind == "new" then
			return string.format(L.REVEAL_TOOL_NEW, name, ns.RankName(receive.rank))
		elseif receive.kind == "upgrade" then
			return string.format(L.REVEAL_TOOL_UPGRADE, name, ns.RankName(receive.rank))
		elseif receive.kind == "salvage" then
			return string.format(L.REVEAL_TOOL_SALVAGE, name, ns.Money(receive.gold))
		end
		return string.format(L.REVEAL_TOOL_PENDING, name)
	elseif result.kind == "item" then
		return string.format(L.REVEAL_ITEM, ns.Colorize(ns.ConsumableName(result.item), 1))
	end
	return string.format(L.REVEAL_PURSE, ns.Money(result.gold or 0))
end

local function revealIcon(result)
	if result.kind == "tool" then
		return Data.TOOLS[result.tool].icon, Data.RANK_QUALITY[result.receive.rank]
	elseif result.kind == "item" then
		return Data.CONSUMABLES[result.item].icon, 1
	end
	return "Interface\\Icons\\INV_Misc_Bag_10", 1
end

local function afterPurchase(result, err)
	if not result then
		ns.Error(err)
		return
	end
	if result.kind == "tool" then
		local rank = result.receive.rank
		if rank >= Data.RANK_LEGENDARY then
			ns.PlaySound("UI_LEGENDARY_LOOT_TOAST")
		elseif rank >= Data.RANK_EPIC then
			ns.PlaySound("UI_EPICLOOT_TOAST")
		else
			ns.PlaySound("UI_BONUS_LOOT_ROLL_END")
		end
	elseif result.box then
		ns.PlaySound("UI_BONUS_LOOT_ROLL_END")
	else
		ns.PlaySound("LOOT_WINDOW_COIN_SOUND")
	end
	-- Lockboxes and tools are revealed at the bottom of the Shop; plain purchases are not.
	local revealed = result.box or result.kind == "tool"
	if revealed then
		lastResult = result
		ns.Print(revealText(result))
	end
	ns.Changed()
	if result.kind == "tool" and result.receive.kind == "pending" then
		ns.UI.HighlightPendingTool()
	end
	if revealed and reveal.slot and reveal.slot:IsVisible() then
		W.Glow(reveal.slot, ns.QualityColor(select(2, revealIcon(result))))
	end
end

local function buyLockbox(id)
	local ok, err = ns.Economy.CanBuyLockbox(id)
	if not ok then
		ns.Error(err)
		return
	end
	W.Confirm(string.format(L.CONFIRM_LOCKBOX, ns.LockboxName(id), ns.Money(ns.Economy.LockboxPrice(id))), function()
		afterPurchase(ns.Economy.BuyLockbox(id))
	end)
end

local function buyTool(faction, index)
	local ok, err = ns.Economy.CanBuyTool(faction, index)
	if not ok then
		ns.Error(err)
		return
	end
	local ware = Data.FACTIONS[faction].wares[index]
	W.Confirm(string.format(L.CONFIRM_TOOL, ns.ToolName(ware.id), ns.Money(ware.price)), function()
		afterPurchase(ns.Economy.BuyTool(faction, index))
	end)
end

local function buyConsumable(id)
	afterPurchase(ns.Economy.BuyConsumable(id))
end

---------------------------------------------------------------------------
-- Rows: what each tab lists
---------------------------------------------------------------------------

local function requirementText(needs)
	return string.format(L.REQUIRES, ns.FactionName(needs.faction), ns.StandingName(needs.rank))
end

local function lockboxRow(id, rankPrefix)
	local box = Data.LOCKBOXES[id]
	local unlocked = ns.Economy.Meets(box.needs)
	local canBuy, err = ns.Economy.CanBuyLockbox(id)
	return {
		icon = box.icon,
		quality = box.quality,
		name = ns.Colorize(ns.LockboxName(id), box.quality),
		desc = (rankPrefix or "") .. L["LOCKBOX_DESC_" .. id],
		price = ns.Economy.LockboxPrice(id),
		enabled = canBuy,
		reason = err,
		status = not unlocked and requirementText(box.needs) or nil,
		onBuy = function()
			buyLockbox(id)
		end,
		tooltip = function(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.LockboxName(id), ns.QualityColor(box.quality))
			GameTooltip:AddLine(L["LOCKBOX_DESC_" .. id], 1, 1, 1, true)
			GameTooltip:AddLine(L.LOCKBOX_TIP, 0.5, 0.5, 0.5, true)
			GameTooltip:Show()
		end,
	}
end

local function consumableRow(id, rankPrefix)
	local def = Data.CONSUMABLES[id]
	local unlocked = ns.Economy.Meets(def.needs)
	local canBuy, err = ns.Economy.CanBuyConsumable(id)
	return {
		icon = def.icon,
		quality = 1,
		count = ns.db.consumables[id] or 0,
		name = ns.Colorize(ns.ConsumableName(id), 1),
		desc = (rankPrefix or "") .. (def.safe == 1 and L.EFFECT_SAFE_ONE or string.format(L.EFFECT_SAFE_MANY, def.safe)),
		price = ns.Economy.ConsumablePrice(id),
		enabled = canBuy,
		reason = err,
		status = not unlocked and requirementText(def.needs) or nil,
		onBuy = function()
			buyConsumable(id)
		end,
		tooltip = function(owner)
			W.ConsumableTooltip(owner, id)
		end,
	}
end

local function generalRows()
	local list = {}
	for _, id in ipairs(Data.LOCKBOX_ORDER) do
		table.insert(list, lockboxRow(id))
	end
	for _, id in ipairs(Data.CONSUMABLE_ORDER) do
		table.insert(list, consumableRow(id))
	end
	return list
end

local function factionRows(faction)
	local list = {}
	local rank = ns.Economy.Rank(faction)
	for index, ware in ipairs(Data.FACTIONS[faction].wares) do
		local prefix = ns.StandingName(ware.rank) .. " · "
		local unlocked = rank >= ware.rank
		if ware.kind == "tool" then
			local def = Data.TOOLS[ware.id]
			local canBuy, err = ns.Economy.CanBuyTool(faction, index)
			local quality = Data.RANK_QUALITY[def.base]
			table.insert(list, {
				icon = def.icon,
				quality = quality,
				name = ns.Colorize(ns.ToolName(ware.id), quality),
				desc = prefix .. ns.ToolEffectText(ware.id, def.base),
				price = ware.price,
				enabled = canBuy,
				reason = err,
				status = not unlocked and requirementText({ faction = faction, rank = ware.rank }) or nil,
				onBuy = function()
					buyTool(faction, index)
				end,
				tooltip = function(owner)
					W.ToolTooltip(owner, { id = ware.id, rank = def.base })
				end,
			})
		elseif ware.kind == "lockbox" then
			table.insert(list, lockboxRow(ware.id, prefix))
		elseif ware.kind == "consumable" then
			table.insert(list, consumableRow(ware.id, prefix))
		else
			table.insert(list, {
				icon = PERK_ICONS[ware.id],
				name = L["PERK_" .. ware.id],
				desc = prefix .. L["PERK_DESC_" .. ware.id],
				perk = true,
				status = unlocked and L.UNLOCKED or requirementText({ faction = faction, rank = ware.rank }),
				unlocked = unlocked,
			})
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function buildRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(492, ROW_HEIGHT - 4)
	row:SetPoint("TOPLEFT", 6, -100 - (index - 1) * ROW_HEIGHT)
	local back = row:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0.06)

	row.slot = W.CreateSlot(row)
	row.slot:SetPoint("LEFT", 4, 0)
	row.slot:SetScript("OnEnter", function(self)
		if row.data and row.data.tooltip then
			row.data.tooltip(self)
		end
	end)
	row.slot:SetScript("OnLeave", tooltipHide)

	row.name = W.Label(row, "GameFontNormal")
	row.name:SetPoint("TOPLEFT", 48, -6)
	row.name:SetWidth(270)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.desc = W.Label(row, "GameFontHighlightSmall")
	row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.desc:SetWidth(280)
	row.desc:SetJustifyH("LEFT")
	row.desc:SetWordWrap(true)

	row.buy = W.Button(row, L.BUY, 70, 22)
	row.buy:SetPoint("RIGHT", -6, 0)
	row.buy:SetMotionScriptsWhileDisabled(true)
	row.buy:SetScript("OnClick", function()
		if row.data and row.data.onBuy then
			row.data.onBuy()
		end
	end)
	row.buy:SetScript("OnEnter", function(self)
		if row.data and not row.data.enabled and row.data.reason then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.ErrorText(row.data.reason), 1, 0.1, 0.1, 1, true)
			GameTooltip:Show()
		end
	end)
	row.buy:SetScript("OnLeave", tooltipHide)

	row.price = W.Label(row, "GameFontHighlightSmall")
	row.price:SetPoint("RIGHT", row.buy, "LEFT", -8, 0)
	row.status = W.Label(row, "GameFontRedSmall")
	row.status:SetPoint("RIGHT", -8, 0)
	row.status:SetWidth(130)
	row.status:SetJustifyH("RIGHT")
	row.status:SetWordWrap(true)
	return row
end

local function createBar(parent)
	-- Forever's own progress bar (as in its Reputation window); a plain status bar if it can't be made.
	local ok, bar = pcall(CreateFrame, "Frame", nil, parent, "ColoredProgressBarTemplate")
	if ok and bar and bar.SetFillPercent then
		bar:SetSize(300, 29)
		return bar
	end
	bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(290, 16)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar.Fill = bar:GetStatusBarTexture()
	bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.Text:SetPoint("CENTER")
	function bar:SetFillPercent(percent)
		self:SetValue(math.min(1, math.max(0, percent)))
	end
	function bar:SetText(text)
		self.Text:SetText(text)
	end
	return bar
end

function Shop.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "ForgebornShopFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(520, 560)
	frame:SetPoint("CENTER")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
		self.userMoved = true
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:Hide()
	frame:SetTitle(L.SHOP_TITLE)
	frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_OrnateBox")
	-- The close button would call HideUIPanel, which Blizzard blocks for addons in combat.
	frame.onCloseCallback = function()
		frame:Hide()
		return false
	end
	table.insert(UISpecialFrames, "ForgebornShopFrame")
	frame.maxTabWidth = 100

	local content = frame.Inset
	header.title = W.Label(content, "GameFontNormalLarge")
	header.title:SetPoint("TOPLEFT", 12, -10)
	header.desc = W.Label(content, "GameFontHighlightSmall")
	header.desc:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -4)
	header.desc:SetWidth(480)
	header.desc:SetJustifyH("LEFT")
	header.desc:SetWordWrap(true)
	header.bar = createBar(content)
	header.bar:SetPoint("TOPLEFT", 8, -60)
	header.standing = W.Label(content, "GameFontNormal")
	header.standing:SetPoint("LEFT", header.bar, "RIGHT", 10, 0)

	for i = 1, ROWS do
		rows[i] = buildRow(content, i)
	end

	reveal.label = W.Label(content, "GameFontNormal", L.LAST_LOCKBOX)
	reveal.label:SetPoint("BOTTOMLEFT", 12, 52)
	reveal.slot = W.CreateSlot(content)
	reveal.slot:SetPoint("BOTTOMLEFT", 12, 10)
	W.AddEffects(reveal.slot)
	reveal.text = W.Label(content, "GameFontHighlight")
	reveal.text:SetPoint("LEFT", reveal.slot, "RIGHT", 10, 0)
	reveal.text:SetWidth(420)
	reveal.text:SetJustifyH("LEFT")
	reveal.text:SetWordWrap(true)

	local goldLabel = W.Label(frame, "GameFontNormal", L.ADDON_GOLD)
	goldLabel:SetPoint("BOTTOMLEFT", 14, 7)
	goldText = W.Label(frame, "GameFontHighlight")
	goldText:SetPoint("LEFT", goldLabel, "RIGHT", 6, 0)

	for i, key in ipairs(TABS) do
		local tab = CreateFrame("Button", "ForgebornShopFrameTab" .. i, frame, "PanelTabButtonTemplate")
		tab:SetID(i)
		tab:SetText(key == "GENERAL" and L.SHOP_GENERAL or ns.FactionShortName(key))
		if i == 1 then
			tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
		end
		tab:SetScript("OnClick", function(self)
			Shop.SelectTab(self:GetID())
			ns.PlaySound("IG_CHARACTER_INFO_TAB")
		end)
		PanelTemplates_TabResize(tab, 0, nil, nil, frame.maxTabWidth)
	end
	PanelTemplates_SetNumTabs(frame, #TABS)
	PanelTemplates_SetTab(frame, selected)
	Shop.parts = { frame = frame, header = header, rows = rows, reveal = reveal, gold = goldText }

	frame:SetScript("OnShow", function()
		ns.PlaySound("IG_MAINMENU_OPEN")
		Shop.Refresh()
	end)
	frame:SetScript("OnHide", function()
		ns.PlaySound("IG_MAINMENU_CLOSE")
	end)
	return frame
end

function Shop.SelectTab(index)
	selected = index
	if frame then
		PanelTemplates_SetTab(frame, index)
		Shop.Refresh()
	end
end

function Shop.Open(tab)
	local f = Shop.Build()
	if tab then
		Shop.SelectTab(tab)
	end
	if not f.userMoved then
		f:ClearAllPoints()
		if ForgebornFrame and ForgebornFrame:IsShown() then
			f:SetPoint("TOPLEFT", ForgebornFrame, "TOPRIGHT", 8, 0)
		else
			f:SetPoint("CENTER")
		end
	end
	f:Show()
end

function Shop.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		Shop.Open()
	end
end

function Shop.IsShown()
	return frame ~= nil and frame:IsShown()
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------

local function fillRow(row, data)
	row.data = data
	row:SetShown(data ~= nil)
	if not data then
		return
	end
	W.SetSlot(row.slot, data.icon, data.quality, data.count)
	row.name:SetText(data.name)
	row.desc:SetText(data.desc)
	if data.perk then
		row.buy:Hide()
		row.price:Hide()
		row.status:SetText(data.status)
		if data.unlocked then
			row.status:SetTextColor(0.1, 1, 0.1)
		else
			row.status:SetTextColor(1, 0.1, 0.1)
		end
		row.status:Show()
		SetItemButtonDesaturated(row.slot, not data.unlocked)
		return
	end
	if data.status then
		row.status:SetText(data.status)
		row.status:SetTextColor(1, 0.1, 0.1)
		row.status:Show()
		row.price:Hide()
		row.buy:Hide()
		SetItemButtonDesaturated(row.slot, true)
		return
	end
	row.status:Hide()
	row.price:SetText(ns.Money(data.price))
	row.price:Show()
	row.buy:Show()
	row.buy:SetEnabled(data.enabled and true or false)
end

function Shop.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local key = TABS[selected]
	local list
	if key == "GENERAL" then
		header.title:SetText(L.SHOP_GENERAL_TITLE)
		header.desc:SetText(L.SHOP_GENERAL_DESC)
		header.bar:Hide()
		header.standing:SetText("")
		list = generalRows()
	else
		header.title:SetText(ns.FactionName(key))
		header.desc:SetText(L["FACTION_DESC_" .. key])
		local rank, into, size = ns.Economy.RepProgress(key)
		header.bar:Show()
		header.bar:SetFillPercent(size > 0 and into / size or 1)
		header.bar:SetText(string.format("%s / %s", BreakUpLargeNumbers(into), BreakUpLargeNumbers(size)))
		local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[Data.REP_STANDING_ID[rank]]
		if color and header.bar.Fill then
			header.bar.Fill:SetVertexColor(color.r, color.g, color.b)
		end
		header.standing:SetText(ns.StandingName(rank))
		list = factionRows(key)
	end
	for i = 1, ROWS do
		fillRow(rows[i], list[i])
	end

	local showReveal = lastResult ~= nil
	reveal.label:SetShown(showReveal)
	reveal.slot:SetShown(showReveal)
	reveal.text:SetShown(showReveal)
	if showReveal then
		local icon, quality = revealIcon(lastResult)
		W.SetSlot(reveal.slot, icon, quality)
		reveal.text:SetText(revealText(lastResult))
	end
	goldText:SetText(ns.Money(ns.db.gold))
end

ns.OnChanged(function()
	Shop.Refresh()
end)
