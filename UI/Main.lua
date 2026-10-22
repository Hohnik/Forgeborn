-- Forgeborn: the main window. The anvil with Forge and Sell on the left, the Workbench, Shelf, Supplies and
-- Display case below it, the crafting orders on the right and the Shop button in the footer.
local _, ns = ...

local L, Data, Rules, W = ns.L, ns.Data, ns.Rules, ns.Widgets
local Drag = W.Drag
local UI = {}
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 780, 590
local BAR_WIDTH, BAR_HEIGHT = 380, 22

local OUTCOME_COLORS = {
	[Data.BREAK] = { 0.78, 0.16, 0.13 },
	[Data.CRACK] = { 0.90, 0.50, 0.18 },
	[Data.MISS] = { 0.50, 0.50, 0.50 },
	[Data.HIT] = { 0.50, 0.82, 0.38 },
	[Data.GREAT] = { 0.16, 0.62, 0.20 },
}
local OUTCOME_KEYS = { "OUTCOME_BREAK", "OUTCOME_CRACK", "OUTCOME_MISS", "OUTCOME_HIT", "OUTCOME_GREAT" }

local frame
local anvil, odds = {}, {}
local benchSlots, shelfSlots, supplySlots, displaySlots = {}, {}, {}, {}
local pendingSlot, pendingText, trophyBonusText
local goldText
local statusText -- last action, shown until the next one

---------------------------------------------------------------------------
-- Opening and closing. ShowUIPanel/HideUIPanel place the window like a native panel; Blizzard blocks them
-- for addons in combat, so in combat the window is shown and hidden directly (it stays usable in combat).
---------------------------------------------------------------------------

function UI.Open()
	local f = UI.Build()
	if f:IsShown() then
		return
	end
	if InCombatLockdown() then
		f:Show()
	else
		ShowUIPanel(f)
	end
end

function UI.Close()
	if not frame or not frame:IsShown() then
		return
	end
	if InCombatLockdown() then
		frame:Hide()
	else
		HideUIPanel(frame)
	end
end

function UI.Toggle()
	if frame and frame:IsShown() then
		UI.Close()
	else
		UI.Open()
	end
end

function UI.IsShown()
	return frame ~= nil and frame:IsShown()
end

---------------------------------------------------------------------------
-- Status line and feedback
---------------------------------------------------------------------------

local function setStatus(text, r, g, b)
	statusText = text and { text = text, r = r or 1, g = g or 0.82, b = b or 0 } or nil
end

function UI.Strike()
	local result, err = ns.Forge.Strike()
	if not result then
		ns.Error(err)
		return
	end
	local piece = result.piece
	local slot = anvil.slot
	if result.broken then
		ns.PlaySound("UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_FAIL")
		W.Flash(slot)
		local title = ns.Colorize(string.format("%s +%d", piece.name, piece.level), result.qualityBefore)
		setStatus(string.format(L.STATUS_BREAK, title, ns.Money(result.lostValue)), 1, 0.25, 0.2)
		ns.Print(string.format(L.CHAT_BREAK, title, ns.Money(result.lostValue)))
	else
		ns.PlaySound("UI_REFORGING_REFORGE")
		local text
		if result.sulfuron then
			text = L.STATUS_SULFURON
		elseif result.outcome == Data.CRACK then
			text = result.gain < 0 and L.STATUS_CRACK or L.STATUS_CRACK_FLOOR
		elseif result.outcome == Data.MISS then
			text = L.STATUS_MISS
		elseif result.outcome == Data.HIT then
			text = string.format(result.darkIron and L.STATUS_HIT_DARK_IRON or L.STATUS_HIT, result.gain)
		else
			text = string.format(L.STATUS_GREAT, result.gain)
		end
		if result.safe then
			text = L.STATUS_SAFE_PREFIX .. text
		end
		local r, g, b = unpack(OUTCOME_COLORS[result.outcome])
		if result.qualityUp then
			local quality = result.qualityAfter
			text = text .. "  " .. string.format(L.STATUS_QUALITY_UP, ns.Colorize(ns.QualityName(quality), quality))
			W.Glow(slot, ns.QualityColor(quality))
			if quality == Data.MAX_QUALITY then
				ns.PlaySound("UI_LEGENDARY_LOOT_TOAST")
			else
				ns.PlaySound("UI_70_ARTIFACT_FORGE_TRAIT_RANKUP")
			end
			if quality >= 4 then
				ns.Print(string.format(L.CHAT_QUALITY_UP, ns.PieceTitle(piece)))
			end
		end
		if result.frenzyStarted then
			text = text .. "  " .. L.STATUS_FRENZY_STARTS
			if not result.qualityUp then
				W.Glow(slot, 1, 0.5, 0.1)
			end
			ns.PlaySound("UI_70_ARTIFACT_FORGE_TRAIT_GOLD_TRAIT")
		end
		setStatus(text, r + (1 - r) * 0.4, g + (1 - g) * 0.4, b + (1 - b) * 0.4)
	end
	ns.Changed()
end

function UI.Sell()
	local value, piece = ns.Forge.Sell()
	if not value then
		ns.Error(piece)
		return
	end
	ns.PlaySound("LOOT_WINDOW_COIN_SOUND")
	local title = ns.Colorize(string.format("%s +%d", piece.name, piece.level), ns.Forge.Quality(piece))
	setStatus(string.format(L.STATUS_SOLD, title, ns.Money(value)), 1, 1, 1)
	ns.Changed()
end

-- Runs a game action; shows its error or refreshes the window.
function UI.Act(ok, err)
	if not ok then
		ns.Error(err)
	end
	ns.Changed()
	return ok
end

function UI.Display(uid)
	local trophy, err = ns.Forge.Display(uid)
	if trophy then
		ns.PlaySound("UI_70_ARTIFACT_FORGE_RELIC_PLACE")
		setStatus(string.format(L.STATUS_DISPLAYED, ns.Colorize(string.format("%s +%d", trophy.name, trophy.level), trophy.quality)), 1, 1, 1)
	end
	return UI.Act(trophy, err)
end

function UI.UseConsumable(id)
	local safe, err = ns.Economy.UseConsumable(id)
	if safe then
		ns.PlaySound("UI_70_ARTIFACT_FORGE_TRAIT_FIRST_TRAIT")
		W.Glow(anvil.slot, 1, 0.82, 0)
		setStatus(string.format(L.STATUS_STONE_USED, ns.ConsumableName(id), safe), 1, 0.82, 0)
	end
	return UI.Act(safe, err)
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------

local function tooltipHide()
	GameTooltip:Hide()
end

local function buildAnvil(parent)
	local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 8, -60)
	inset:SetSize(404, 268)
	anvil.inset = inset

	local nextLabel = W.Label(inset, "GameFontNormal", L.NEXT_SWING)
	nextLabel:SetPoint("TOPLEFT", 12, -10)

	-- Embers: up to 7 small circles that fill toward the automatic Frenzy.
	local pips = CreateFrame("Frame", nil, inset)
	pips:SetSize(7 * 14, 12)
	pips:SetPoint("TOPRIGHT", -12, -11)
	anvil.pips = {}
	for i = 1, 7 do
		local back = pips:CreateTexture(nil, "BACKGROUND")
		back:SetColorTexture(0, 0, 0, 0.6)
		back:SetSize(12, 12)
		back:SetPoint("LEFT", (i - 1) * 14, 0)
		local fill = pips:CreateTexture(nil, "ARTWORK")
		fill:SetSize(8, 8)
		fill:SetPoint("CENTER", back)
		local mask = pips:CreateMaskTexture()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(back)
		back:AddMaskTexture(mask)
		local fillMask = pips:CreateMaskTexture()
		fillMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		fillMask:SetAllPoints(fill)
		fill:AddMaskTexture(fillMask)
		anvil.pips[i] = { back = back, fill = fill }
	end
	anvil.embers = W.Label(inset, "GameFontHighlightSmall")
	anvil.embers:SetPoint("RIGHT", pips, "LEFT", -6, 0)
	pips:EnableMouse(true)
	pips:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.EMBERS_TITLE)
		GameTooltip:AddLine(string.format(L.EMBERS_TIP, ns.Economy.Mods().frenzyEvery, ns.Economy.Mods().frenzySwings), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	pips:SetScript("OnLeave", tooltipHide)

	-- The odds bar: every outcome of the next swing as a coloured section with its percentage.
	local bar = CreateFrame("Frame", nil, inset)
	bar:SetPoint("TOPLEFT", 12, -32)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0, 0, 0, 0.5)
	odds.bar = bar
	odds.segments, odds.percents, odds.labels = {}, {}, {}
	for outcome = Data.BREAK, Data.GREAT do
		local segment = bar:CreateTexture(nil, "ARTWORK")
		segment:SetColorTexture(OUTCOME_COLORS[outcome][1], OUTCOME_COLORS[outcome][2], OUTCOME_COLORS[outcome][3], 0.9)
		segment:SetHeight(BAR_HEIGHT)
		odds.segments[outcome] = segment
		local percent = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		percent:SetPoint("CENTER", segment)
		odds.percents[outcome] = percent
		local label = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		label:SetText(L[OUTCOME_KEYS[outcome]])
		odds.labels[outcome] = label
	end
	odds.empty = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	odds.empty:SetPoint("CENTER")
	odds.empty:SetText(L.ODDS_EMPTY)
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.ODDS_TITLE)
		GameTooltip:AddLine(L.ODDS_TIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", tooltipHide)

	-- The anvil slot.
	local holder = CreateFrame("Frame", nil, inset)
	holder:SetSize(50, 50)
	holder:SetPoint("TOP", 0, -84)
	local slot = W.CreateSlot(holder, 1.35)
	slot:SetPoint("CENTER")
	W.AddEffects(slot)
	anvil.slot = slot
	slot:SetScript("OnEnter", function(self)
		local piece = ns.db.anvil
		if piece then
			W.PieceTooltip(self, piece, "anvil")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.ANVIL)
			GameTooltip:AddLine(L.ANVIL_EMPTY_HINT, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	slot:SetScript("OnLeave", tooltipHide)
	slot:SetScript("OnClick", function(self, button)
		local piece = ns.db.anvil
		if Drag.ClickAfterDrag(self) then
			return
		end
		if button == "RightButton" and piece then
			W.Menu(self, ns.PieceTitle(piece), {
				{ L.MENU_PARK, function() UI.Act(ns.Forge.Park()) end },
				{ L.MENU_DISPLAY, function() UI.Display(piece.uid) end },
			})
		end
	end)
	slot:SetScript("OnDragStart", function()
		local piece = ns.db.anvil
		if piece then
			Drag.Start({ kind = "piece", uid = piece.uid, from = "anvil", icon = piece.icon }, slot)
		end
	end)
	slot:SetScript("OnDragStop", function()
		Drag.Stop()
	end)
	Drag.Register({
		frame = slot,
		accept = function(p)
			return (p.kind == "piece" and p.from == "bench") or p.kind == "consumable"
		end,
		drop = function(p)
			if p.kind == "consumable" then
				UI.UseConsumable(p.id)
			else
				UI.Act(ns.Forge.PutOnAnvil(p.slot))
			end
		end,
	})

	anvil.name = W.Label(inset, "GameFontNormalLarge")
	anvil.name:SetPoint("TOP", 0, -142)
	anvil.name:SetWidth(380)
	anvil.info = W.Label(inset, "GameFontHighlightSmall")
	anvil.info:SetPoint("TOP", anvil.name, "BOTTOM", 0, -4)
	anvil.info:SetWidth(380)
	anvil.value = W.Label(inset, "GameFontHighlight")
	anvil.value:SetPoint("TOP", anvil.info, "BOTTOM", 0, -4)
	anvil.status = W.Label(inset, "GameFontNormalSmall")
	anvil.status:SetPoint("TOP", anvil.value, "BOTTOM", 0, -6)
	anvil.status:SetWidth(384)
	anvil.status:SetWordWrap(true)

	local forge = W.Button(inset, L.FORGE, 182, 32, "SharedButtonLargeTemplate")
	forge:SetPoint("BOTTOMLEFT", 12, 10)
	forge:SetScript("OnClick", UI.Strike)
	anvil.forge = forge
	local sell = W.Button(inset, L.SELL, 182, 32)
	sell:SetPoint("BOTTOMRIGHT", -12, 10)
	sell:SetScript("OnClick", UI.Sell)
	anvil.sell = sell
end

local function slotRow(parent, x, y, count, list)
	for i = 1, count do
		local slot = W.CreateSlot(parent)
		slot:SetPoint("TOPLEFT", x + (i - 1) * 44, y)
		slot.index = i
		slot:SetScript("OnLeave", tooltipHide)
		slot:SetScript("OnDragStop", function()
			Drag.Stop()
		end)
		list[i] = slot
	end
end

local function buildStorage(parent)
	local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 8, -332)
	inset:SetSize(404, 216)

	W.Label(inset, "GameFontNormal", L.WORKBENCH):SetPoint("TOPLEFT", 12, -10)
	W.Label(inset, "GameFontNormal", L.SHELF):SetPoint("TOPLEFT", 208, -10)
	W.Label(inset, "GameFontNormal", L.SUPPLIES):SetPoint("TOPLEFT", 12, -78)
	W.Label(inset, "GameFontNormal", L.DISPLAY_CASE):SetPoint("TOPLEFT", 12, -146)
	trophyBonusText = W.Label(inset, "GameFontHighlightSmall")
	trophyBonusText:SetPoint("TOPRIGHT", -12, -148)

	-- Workbench: click to put on the anvil, drag to the anvil, an order or the Display case.
	slotRow(inset, 14, -30, Data.WORKBENCH_SLOTS, benchSlots)
	for i, slot in ipairs(benchSlots) do
		slot:SetScript("OnEnter", function(self)
			local piece = ns.db.workbench[i]
			if piece then
				W.PieceTooltip(self, piece, "bench")
			else
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(L.WORKBENCH)
				GameTooltip:AddLine(L.WORKBENCH_TIP, 1, 1, 1, true)
				GameTooltip:Show()
			end
		end)
		slot:SetScript("OnClick", function(self, button)
			local piece = ns.db.workbench[i]
			if not piece or Drag.ClickAfterDrag(self) then
				return
			end
			if button == "RightButton" then
				W.Menu(self, ns.PieceTitle(piece), {
					{ L.MENU_TO_ANVIL, function() UI.Act(ns.Forge.PutOnAnvil(i)) end },
					{ L.MENU_DISPLAY, function() UI.Display(piece.uid) end },
					{ L.MENU_DISCARD, function()
						W.Confirm(string.format(L.CONFIRM_DISCARD, ns.PieceTitle(piece)), function()
							local current = ns.db.workbench[i]
							if current and current.uid == piece.uid then
								UI.Act(ns.Forge.DiscardBench(i))
							end
						end)
					end },
				})
			else
				UI.Act(ns.Forge.PutOnAnvil(i))
			end
		end)
		slot:SetScript("OnDragStart", function(self)
			local piece = ns.db.workbench[i]
			if piece then
				Drag.Start({ kind = "piece", uid = piece.uid, from = "bench", slot = i, icon = piece.icon }, self)
			end
		end)
		Drag.Register({
			frame = slot,
			accept = function(p)
				return p.kind == "piece" and (p.from == "anvil" or (p.from == "bench" and p.slot ~= i))
			end,
			drop = function(p)
				if p.from == "anvil" then
					UI.Act(ns.Forge.Park(i))
				else
					UI.Act(ns.Forge.SwapBench(p.slot, i))
				end
			end,
		})
	end

	-- Shelf: 4 tools, fixed. Drag to reorder; the pending tool is dragged onto a slot to replace it.
	slotRow(inset, 210, -30, Data.SHELF_SLOTS, shelfSlots)
	for i, slot in ipairs(shelfSlots) do
		slot:SetScript("OnEnter", function(self)
			local tool = ns.db.shelf[i]
			if tool then
				W.ToolTooltip(self, tool)
			else
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(L.SHELF)
				GameTooltip:AddLine(L.SHELF_TIP, 1, 1, 1, true)
				GameTooltip:Show()
			end
		end)
		slot:SetScript("OnClick", function(self, button)
			local tool = ns.db.shelf[i]
			if button == "RightButton" and tool and not Drag.ClickAfterDrag(self) then
				W.Menu(self, ns.ToolName(tool.id), {
					{ L.MENU_REMOVE_TOOL, function()
						W.Confirm(string.format(L.CONFIRM_REMOVE_TOOL, ns.ToolName(tool.id)), function()
							if ns.db.shelf[i] == tool then
								UI.Act(ns.Economy.RemoveTool(i))
							end
						end)
					end },
				})
			end
		end)
		slot:SetScript("OnDragStart", function(self)
			local tool = ns.db.shelf[i]
			if tool then
				Drag.Start({ kind = "tool", slot = i, icon = Data.TOOLS[tool.id].icon }, self)
			end
		end)
		Drag.Register({
			frame = slot,
			accept = function(p)
				return p.kind == "pending" or (p.kind == "tool" and p.slot ~= i)
			end,
			drop = function(p)
				if p.kind == "tool" then
					UI.Act(ns.Economy.MoveTool(p.slot, i))
				else
					UI.PlacePendingTool(i)
				end
			end,
		})
	end

	-- Supplies: one-use items. Click (or drag onto the anvil) to use on the anvil item.
	slotRow(inset, 14, -98, #Data.CONSUMABLE_ORDER, supplySlots)
	for i, slot in ipairs(supplySlots) do
		local id = Data.CONSUMABLE_ORDER[i]
		slot:SetScript("OnEnter", function(self)
			W.ConsumableTooltip(self, id)
		end)
		slot:SetScript("OnClick", function(self, button)
			if button == "LeftButton" and not Drag.ClickAfterDrag(self) then
				UI.UseConsumable(id)
			end
		end)
		slot:SetScript("OnDragStart", function(self)
			if (ns.db.consumables[id] or 0) > 0 then
				Drag.Start({ kind = "consumable", id = id, icon = Data.CONSUMABLES[id].icon }, self)
			end
		end)
	end

	-- A tool from a lockbox that has no free shelf slot waits here.
	pendingSlot = W.CreateSlot(inset)
	pendingSlot:SetPoint("TOPLEFT", 210, -98)
	W.AddEffects(pendingSlot)
	pendingSlot:SetScript("OnEnter", function(self)
		if ns.db.pendingTool then
			W.ToolTooltip(self, ns.db.pendingTool, true)
		end
	end)
	pendingSlot:SetScript("OnLeave", tooltipHide)
	pendingSlot:SetScript("OnClick", function(self, button)
		if button == "RightButton" and ns.db.pendingTool and not Drag.ClickAfterDrag(self) then
			UI.PendingToolMenu(self)
		end
	end)
	pendingSlot:SetScript("OnDragStart", function(self)
		local tool = ns.db.pendingTool
		if tool then
			Drag.Start({ kind = "pending", icon = Data.TOOLS[tool.id].icon }, self)
		end
	end)
	pendingSlot:SetScript("OnDragStop", function()
		Drag.Stop()
	end)
	pendingText = W.Label(inset, "GameFontHighlightSmall", L.PENDING_TOOL_HINT)
	pendingText:SetPoint("TOPLEFT", pendingSlot, "TOPRIGHT", 8, 0)
	pendingText:SetWidth(140)
	pendingText:SetJustifyH("LEFT")
	pendingText:SetWordWrap(true)

	-- Display case: drag an item here to keep it as a trophy.
	slotRow(inset, 14, -166, 6, displaySlots)
	for i, slot in ipairs(displaySlots) do
		slot:SetScript("OnEnter", function(self)
			local trophy = ns.db.display[i]
			if trophy then
				W.TrophyTooltip(self, trophy)
			else
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(L.DISPLAY_CASE)
				GameTooltip:AddLine(L.DISPLAY_TIP, 1, 1, 1, true)
				GameTooltip:Show()
			end
		end)
		slot:SetScript("OnClick", function(self, button)
			local trophy = ns.db.display[i]
			if button == "RightButton" and trophy then
				local title = ns.Colorize(string.format("%s +%d", trophy.name, trophy.level), trophy.quality)
				W.Menu(self, title, {
					{ L.MENU_REMOVE_TROPHY, function()
						W.Confirm(string.format(L.CONFIRM_REMOVE_TROPHY, title), function()
							if ns.db.display[i] == trophy then
								UI.Act(ns.Economy.RemoveTrophy(i))
							end
						end)
					end },
				})
			end
		end)
		Drag.Register({
			frame = slot,
			accept = function(p)
				return p.kind == "piece"
			end,
			drop = function(p)
				UI.Display(p.uid)
			end,
		})
	end
end

function UI.PlacePendingTool(slot)
	local pending = ns.db.pendingTool
	if not pending then
		return
	end
	local current = ns.db.shelf[slot]
	local function place()
		if ns.db.pendingTool == pending then
			local ok, err = ns.Economy.PlacePendingTool(slot)
			if ok then
				ns.PlaySound("UI_70_ARTIFACT_FORGE_RELIC_PLACE")
			end
			UI.Act(ok, err)
		end
	end
	if current then
		W.Confirm(string.format(L.CONFIRM_REPLACE_TOOL, ns.ToolName(current.id), ns.ToolName(pending.id)), place)
	else
		place()
	end
end

function UI.PendingToolMenu(owner)
	local pending = ns.db.pendingTool
	local entries = {}
	for slot = 1, Data.SHELF_SLOTS do
		local tool = ns.db.shelf[slot]
		local text = tool and string.format(L.MENU_REPLACE_TOOL, ns.ToolName(tool.id)) or L.MENU_PLACE_TOOL
		table.insert(entries, { text, function() UI.PlacePendingTool(slot) end })
	end
	table.insert(entries, { L.MENU_DISCARD_TOOL, function()
		W.Confirm(string.format(L.CONFIRM_DISCARD_TOOL, ns.ToolName(pending.id)), function()
			if ns.db.pendingTool == pending then
				UI.Act(ns.Economy.DiscardPendingTool())
			end
		end)
	end })
	W.Menu(owner, ns.ToolName(pending.id), entries)
end

local function showRecords(owner)
	local records, stats = ns.db.records, ns.db.stats
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.RECORDS)
	for quality = 0, Data.MAX_QUALITY do
		local best = records.best[quality]
		if best then
			GameTooltip:AddDoubleLine(ns.Colorize(ns.QualityName(quality), quality), "+" .. best, 1, 1, 1, 1, 1, 1)
		end
	end
	if records.bestSale > 0 then
		GameTooltip:AddDoubleLine(L.RECORD_BEST_SALE, ns.Money(records.bestSale), 1, 1, 1, 1, 1, 1)
		if records.bestSaleName then
			GameTooltip:AddLine("  " .. ns.Colorize(records.bestSaleName, records.bestSaleQuality or 1))
		end
	end
	GameTooltip:AddDoubleLine(L.RECORD_STREAK, tostring(records.bestStreak), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine(L.RECORD_GRAY_TO_ORANGE, tostring(records.grayToOrange), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine(L.STAT_SWINGS, tostring(stats.swings), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine(L.STAT_BREAKS, tostring(stats.breaks), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine(L.STAT_SOLD, tostring(stats.sold), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine(L.STAT_EARNED, ns.Money(stats.earned), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(L.STAT_ORDERS, tostring(stats.orders), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

function UI.Build()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "ForgebornFrame", UIParent, "PortraitFrameTemplate")
	frame:SetSize(UI.WIDTH, UI.HEIGHT)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:Hide()
	frame:SetTitle(L.TITLE)
	frame:SetPortraitToAsset("Interface\\Icons\\Trade_BlackSmithing")
	frame.onCloseCallback = function()
		UI.Close()
		return false
	end
	UIPanelWindows.ForgebornFrame = { area = "left", pushable = 1, whileDead = 1 }
	table.insert(UISpecialFrames, "ForgebornFrame")

	local portrait = frame.PortraitContainer
	portrait:EnableMouse(true)
	portrait:SetScript("OnEnter", showRecords)
	portrait:SetScript("OnLeave", tooltipHide)

	buildAnvil(frame)
	buildStorage(frame)
	UI.BuildOrders(frame)

	local goldLabel = W.Label(frame, "GameFontNormal", L.ADDON_GOLD)
	goldLabel:SetPoint("BOTTOMLEFT", 18, 16)
	goldText = W.Label(frame, "GameFontHighlight")
	goldText:SetPoint("LEFT", goldLabel, "RIGHT", 6, 0)
	local shop = W.Button(frame, L.SHOP, 110, 24)
	shop:SetPoint("BOTTOMRIGHT", -12, 10)
	shop:SetScript("OnClick", function()
		ns.Shop.Toggle()
	end)
	local shopHint = W.Label(frame, "GameFontDisableSmall", L.SHOP_HINT)
	shopHint:SetPoint("RIGHT", shop, "LEFT", -10, 0)

	-- The window's parts, for the tests.
	UI.parts = {
		frame = frame, anvil = anvil, odds = odds, shop = shop,
		bench = benchSlots, shelf = shelfSlots, supplies = supplySlots, display = displaySlots,
		pending = pendingSlot, pendingText = pendingText, gold = goldText, trophyBonus = trophyBonusText,
	}

	frame:SetScript("OnShow", function()
		ns.PlaySound("IG_CHARACTER_INFO_OPEN")
		ns.Orders.Check()
		UI.Refresh()
	end)
	frame:SetScript("OnHide", function()
		ns.PlaySound("IG_CHARACTER_INFO_CLOSE")
		Drag.Cancel()
		statusText = nil
	end)
	return frame
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------

local function updateOdds(piece)
	if not piece then
		for outcome = Data.BREAK, Data.GREAT do
			odds.segments[outcome]:Hide()
			odds.percents[outcome]:Hide()
			odds.labels[outcome]:Hide()
		end
		odds.empty:Show()
		return
	end
	odds.empty:Hide()
	local mods = ns.Economy.Mods()
	odds.labels[Data.GREAT]:SetText("+" .. mods.greatGain)
	local chances = Rules.NextOdds(piece, mods)
	local percents = Rules.Percentages(chances)
	local x = 0
	local lastRight
	for outcome = Data.BREAK, Data.GREAT do
		local segment, percent, label = odds.segments[outcome], odds.percents[outcome], odds.labels[outcome]
		local width = BAR_WIDTH * chances[outcome]
		if chances[outcome] > 0 then
			segment:ClearAllPoints()
			segment:SetPoint("LEFT", odds.bar, "LEFT", x, 0)
			segment:SetWidth(math.max(width, 1))
			segment:Show()
			percent:SetText(percents[outcome] .. "%")
			percent:SetShown(width >= 26)
			-- Labels sit under their section, pushed apart where sections are narrow.
			local textWidth = label:GetStringWidth()
			local left = math.max(x + width / 2 - textWidth / 2, 0)
			if lastRight then
				left = math.max(left, lastRight + 4)
			end
			left = math.max(math.min(left, BAR_WIDTH - textWidth), 0)
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", odds.bar, "BOTTOMLEFT", left, -3)
			label:Show()
			lastRight = left + textWidth
			x = x + width
		else
			segment:Hide()
			percent:Hide()
			label:Hide()
		end
	end
end

local function updateAnvil()
	local piece = ns.db.anvil
	local mods = ns.Economy.Mods()
	updateOdds(piece)

	local frenzy, safe, embers = 0, 0, 0
	if piece then
		local quality = ns.Forge.Quality(piece)
		W.SetSlot(anvil.slot, piece.icon, quality)
		anvil.name:SetText(ns.PieceTitle(piece))
		local info = string.format(L.QUALITY_ILVL, ns.QualityName(quality), piece.itemLevel)
		local toNext = Rules.LevelsToNext(piece.startQuality, piece.level)
		if toNext then
			info = info .. " · " .. string.format(L.LEVELS_TO, toNext, ns.QualityName(quality + 1))
		end
		anvil.info:SetText(info)
		anvil.value:SetText(string.format(L.VALUE, ns.Money(ns.Forge.Value(piece))))
		frenzy, safe, embers = piece.frenzy or 0, piece.safe or 0, piece.embers or 0
	else
		W.SetSlot(anvil.slot, nil)
		anvil.name:SetText(L.ANVIL_EMPTY)
		anvil.info:SetText(L.ANVIL_EMPTY_HINT)
		anvil.value:SetText("")
	end
	anvil.forge:SetEnabled(piece ~= nil)
	anvil.sell:SetEnabled(piece ~= nil)

	local count = math.min(mods.frenzyEvery, 7)
	for i, pip in ipairs(anvil.pips) do
		local shown = i <= count
		pip.back:SetShown(shown)
		pip.fill:SetShown(shown)
		if frenzy > 0 then
			pip.fill:SetColorTexture(1, 0.82, 0.1)
		elseif i <= embers then
			pip.fill:SetColorTexture(1, 0.4, 0.1)
		else
			pip.fill:SetColorTexture(0.25, 0.25, 0.25)
		end
	end
	if frenzy > 0 then
		anvil.embers:SetText(string.format(L.FRENZY_LEFT, frenzy))
		anvil.embers:SetTextColor(1, 0.82, 0.1)
	elseif safe > 0 then
		anvil.embers:SetText(string.format(L.SAFE_LEFT, safe))
		anvil.embers:SetTextColor(1, 0.82, 0.1)
	else
		anvil.embers:SetText(string.format(L.EMBERS, math.min(embers, mods.frenzyEvery), mods.frenzyEvery))
		anvil.embers:SetTextColor(1, 1, 1)
	end

	if statusText then
		anvil.status:SetText(statusText.text)
		anvil.status:SetTextColor(statusText.r, statusText.g, statusText.b)
	else
		anvil.status:SetText("")
	end
end

local function updateStorage()
	local db = ns.db
	for i, slot in ipairs(benchSlots) do
		local piece = db.workbench[i]
		if piece then
			W.SetSlot(slot, piece.icon, ns.Forge.Quality(piece))
		else
			W.SetSlot(slot, nil)
		end
	end
	for i, slot in ipairs(shelfSlots) do
		local tool = db.shelf[i]
		if tool then
			W.SetSlot(slot, Data.TOOLS[tool.id].icon, Data.RANK_QUALITY[tool.rank])
		else
			W.SetSlot(slot, nil)
		end
	end
	for i, slot in ipairs(supplySlots) do
		local id = Data.CONSUMABLE_ORDER[i]
		local owned = db.consumables[id] or 0
		W.SetSlot(slot, Data.CONSUMABLES[id].icon, 1, owned, owned == 0)
	end
	local pending = db.pendingTool
	pendingSlot:SetShown(pending ~= nil)
	pendingText:SetShown(pending ~= nil)
	if pending then
		W.SetSlot(pendingSlot, Data.TOOLS[pending.id].icon, Data.RANK_QUALITY[pending.rank])
	end
	local slots = ns.Economy.DisplaySlots()
	for i, slot in ipairs(displaySlots) do
		local trophy = db.display[i]
		slot:SetShown(i <= slots or trophy ~= nil)
		if trophy then
			W.SetSlot(slot, trophy.icon, trophy.quality, nil, i > slots)
		else
			W.SetSlot(slot, nil)
		end
	end
	local bonus = ns.Economy.TrophyBonus()
	if bonus > 0 then
		trophyBonusText:SetText(string.format(L.TROPHY_BONUS, string.format("%g", math.floor(bonus * 10000 + 0.5) / 100)))
	else
		trophyBonusText:SetText("")
	end
	goldText:SetText(ns.Money(db.gold))
end

function UI.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	updateAnvil()
	updateStorage()
	UI.UpdateOrders()
end

-- Shows a pending tool with a glow (called after a lockbox).
function UI.HighlightPendingTool()
	if pendingSlot and pendingSlot:IsVisible() then
		W.Glow(pendingSlot, 1, 0.82, 0)
	end
end

ns.OnChanged(function()
	UI.Refresh()
end)
