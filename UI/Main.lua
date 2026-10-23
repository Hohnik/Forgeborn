-- Forgeborn: the main window. The anvil with Forge and Sell on the left, the Workbench, Shelf, Supplies and
-- Display case below it, the crafting orders on the right and the Shop button in the footer.
local _, ns = ...

local L, Data, Rules, W, Layout = ns.L, ns.Data, ns.Rules, ns.Widgets, ns.Layout
local Drag = W.Drag
local UI = {}
ns.UI = UI

-- Positions and sizes come from UI/Layout.lua (tools/layout-editor edits it).
UI.WIDTH, UI.HEIGHT = Layout.window[1], Layout.window[2]
local BAR_WIDTH, BAR_HEIGHT = Layout.odds[3], Layout.odds[4]

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

-- index: the Display case slot it was dropped on (a trophy there swaps with it).
function UI.Display(uid, index)
	local trophy, err = ns.Forge.Display(uid, index)
	if trophy then
		ns.PlaySound("UI_70_ARTIFACT_FORGE_RELIC_PLACE")
		setStatus(string.format(L.STATUS_DISPLAYED, ns.Colorize(string.format("%s +%d", trophy.name, trophy.level), trophy.quality)), 1, 1, 1)
	end
	return UI.Act(trophy, err)
end

-- Takes a trophy out of the Display case onto the anvil ("anvil") or a Workbench slot.
function UI.TakeTrophy(index, target)
	local piece, err = ns.Forge.TakeTrophy(index, target)
	if piece then
		ns.PlaySound("UI_70_ARTIFACT_FORGE_RELIC_PLACE")
		setStatus(string.format(L.STATUS_TROPHY_BACK, ns.PieceTitle(piece)), 1, 1, 1)
	end
	return UI.Act(piece, err)
end

-- The slot that shows a piece, for effects.
local function slotOf(uid)
	local _, where, slot = ns.Forge.Find(uid)
	if where == "anvil" then
		return anvil.slot
	elseif where == "bench" then
		return benchSlots[slot]
	end
end

-- Uses a sharpening stone on a piece (by uid; the anvil piece if none is given).
function UI.UseConsumable(id, uid)
	local safe, err = ns.Economy.UseConsumable(id, uid)
	if safe then
		ns.PlaySound("UI_70_ARTIFACT_FORGE_TRAIT_FIRST_TRAIT")
		local slot = uid and slotOf(uid) or anvil.slot
		if slot then
			W.Glow(slot, 1, 0.82, 0)
		end
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
	W.Place(inset, Layout.anvil)
	anvil.inset = inset

	local nextLabel = W.Label(inset, "GameFontNormal", L.NEXT_SWING)
	W.PlaceText(nextLabel, Layout.nextSwing)

	-- Embers: up to 7 small circles that fill toward the automatic Frenzy, spread over the pips box.
	local pips = CreateFrame("Frame", nil, inset)
	W.Place(pips, Layout.pips)
	local pipSize = Layout.pips[4]
	local pipStep = (Layout.pips[3] - pipSize) / 6
	anvil.pips = {}
	for i = 1, 7 do
		local back = pips:CreateTexture(nil, "BACKGROUND")
		back:SetColorTexture(0, 0, 0, 0.6)
		back:SetSize(pipSize, pipSize)
		back:SetPoint("LEFT", (i - 1) * pipStep, 0)
		local fill = pips:CreateTexture(nil, "ARTWORK")
		fill:SetSize(pipSize * 2 / 3, pipSize * 2 / 3)
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
	W.PlaceText(anvil.embers, Layout.embers, "RIGHT")
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
	W.Place(bar, Layout.odds)
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
		local piece = ns.db.anvil
		if piece then
			-- The odds move with every level: show where a Hit would take them.
			local mods = ns.Economy.Mods()
			local after = Rules.Percentages(Rules.Odds(Rules.Bag(Rules.PieceGrade(piece) + 1, mods), false))
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(string.format(L.ODDS_AFTER_HIT, after[Data.BREAK]), 1, 0.5, 0.4)
			GameTooltip:AddLine(string.format(L.ODDS_VALUE_STEP, string.format("%g", Data.VALUE_PER_LEVEL)), 0.8, 0.8, 0.8, true)
		end
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", tooltipHide)

	-- The anvil slot.
	local slot = W.CreateSlot(inset)
	W.PlaceSlot(slot, Layout.anvilSlot)
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
	-- The anvil takes any item (from the Workbench, an order card or the Display case) and sharpening stones.
	Drag.Register({
		frame = slot,
		accept = function(p)
			return (p.kind == "piece" and p.from ~= "anvil") or p.kind == "trophy" or (p.kind == "consumable" and ns.db.anvil ~= nil)
		end,
		drop = function(p)
			if p.kind == "consumable" then
				UI.UseConsumable(p.id)
			elseif p.kind == "trophy" then
				UI.TakeTrophy(p.index, "anvil")
			else
				UI.Act(ns.Forge.Move(p.uid, "anvil"))
			end
		end,
	})

	anvil.name = W.Label(inset, "GameFontNormalLarge")
	W.PlaceText(anvil.name, Layout.itemName, "CENTER")
	anvil.name:SetWordWrap(false)
	anvil.info = W.Label(inset, "GameFontHighlightSmall")
	W.PlaceText(anvil.info, Layout.itemInfo, "CENTER")
	anvil.value = W.Label(inset, "GameFontHighlight")
	W.PlaceText(anvil.value, Layout.itemValue, "CENTER")
	anvil.status = W.Label(inset, "GameFontNormalSmall")
	W.PlaceText(anvil.status, Layout.status, "CENTER")
	anvil.status:SetWordWrap(true)

	local forge = W.Button(inset, L.FORGE, Layout.forge[3], Layout.forge[4], "SharedButtonLargeTemplate")
	W.Place(forge, Layout.forge)
	forge:SetScript("OnClick", UI.Strike)
	anvil.forge = forge
	local sell = W.Button(inset, L.SELL, Layout.sell[3], Layout.sell[4])
	W.Place(sell, Layout.sell)
	sell:SetScript("OnClick", UI.Sell)
	anvil.sell = sell
end

-- A row of item slots at a layout row { x, y, step }.
local function slotRow(parent, row, count, list)
	for i = 1, count do
		local slot = W.CreateSlot(parent)
		slot:SetPoint("TOPLEFT", row[1] + (i - 1) * row[3], -row[2])
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
	W.Place(inset, Layout.storage)

	W.PlaceText(W.Label(inset, "GameFontNormal", L.WORKBENCH), Layout.workbenchTitle)
	W.PlaceText(W.Label(inset, "GameFontNormal", L.SHELF), Layout.shelfTitle)
	W.PlaceText(W.Label(inset, "GameFontNormal", L.SUPPLIES), Layout.suppliesTitle)
	W.PlaceText(W.Label(inset, "GameFontNormal", L.DISPLAY_CASE), Layout.displayTitle)
	trophyBonusText = W.Label(inset, "GameFontHighlightSmall")
	W.PlaceText(trophyBonusText, Layout.trophyBonus, "RIGHT")

	-- Workbench: click to put on the anvil, drag to the anvil, an order or the Display case.
	slotRow(inset, Layout.workbench, Data.WORKBENCH_SLOTS, benchSlots)
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
		-- Any item can be dropped here (an item already here swaps places with it); a stone sharpens this item.
		Drag.Register({
			frame = slot,
			accept = function(p)
				if p.kind == "piece" then
					return not (p.from == "bench" and p.slot == i)
				end
				return p.kind == "trophy" or (p.kind == "consumable" and ns.db.workbench[i] ~= nil)
			end,
			drop = function(p)
				if p.kind == "trophy" then
					UI.TakeTrophy(p.index, i)
				elseif p.kind == "consumable" then
					UI.UseConsumable(p.id, ns.db.workbench[i].uid)
				else
					UI.Act(ns.Forge.Move(p.uid, i))
				end
			end,
		})
	end

	-- Shelf: 4 tools, fixed. Drag to reorder; the pending tool is dragged onto a slot to replace it.
	slotRow(inset, Layout.shelf, Data.SHELF_SLOTS, shelfSlots)
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
	slotRow(inset, Layout.supplies, #Data.CONSUMABLE_ORDER, supplySlots)
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
		-- An item dropped on a stone is sharpened with it.
		Drag.Register({
			frame = slot,
			accept = function(p)
				return p.kind == "piece"
			end,
			drop = function(p)
				UI.UseConsumable(id, p.uid)
			end,
		})
	end

	-- A tool from a lockbox that has no free shelf slot waits here.
	pendingSlot = W.CreateSlot(inset)
	W.PlaceSlot(pendingSlot, Layout.newTool)
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
	-- A shelf tool dropped on the new tool swaps places with it.
	Drag.Register({
		frame = pendingSlot,
		accept = function(p)
			return p.kind == "tool" and ns.db.pendingTool ~= nil
		end,
		drop = function(p)
			UI.Act(ns.Economy.SwapPendingTool(p.slot))
		end,
	})
	pendingText = W.Label(inset, "GameFontHighlightSmall", L.PENDING_TOOL_HINT)
	W.PlaceText(pendingText, Layout.newToolText)
	pendingText:SetWordWrap(true)

	-- Display case: drag an item here to keep it as a trophy.
	slotRow(inset, Layout.display, 6, displaySlots)
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
			if button == "RightButton" and trophy and not Drag.ClickAfterDrag(self) then
				local title = ns.Colorize(string.format("%s +%d", trophy.name, trophy.level), trophy.quality)
				W.Menu(self, title, {
					{ L.MENU_TO_ANVIL, function()
						if ns.db.display[i] == trophy then
							UI.TakeTrophy(i, "anvil")
						end
					end },
					{ L.MENU_TO_BENCH, function()
						if ns.db.display[i] == trophy then
							local free = ns.Forge.FreeBenchSlot()
							if free then
								UI.TakeTrophy(i, free)
							else
								ns.Error("ERR_BENCH_FULL")
							end
						end
					end },
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
		-- Drag a trophy out to the anvil or the Workbench, or onto another trophy to reorder.
		slot:SetScript("OnDragStart", function(self)
			local trophy = ns.db.display[i]
			if trophy then
				Drag.Start({ kind = "trophy", index = i, icon = trophy.icon }, self)
			end
		end)
		Drag.Register({
			frame = slot,
			accept = function(p)
				return p.kind == "piece" or (p.kind == "trophy" and p.index ~= i)
			end,
			drop = function(p)
				if p.kind == "trophy" then
					UI.Act(ns.Economy.MoveTrophy(p.index, i))
				else
					UI.Display(p.uid, i)
				end
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

	-- The label keeps its own width so the amount follows right after it.
	local goldLabel = W.Label(frame, "GameFontNormal", L.ADDON_GOLD)
	goldLabel:SetPoint("TOPLEFT", Layout.gold[1], -Layout.gold[2])
	goldText = W.Label(frame, "GameFontHighlight")
	goldText:SetPoint("LEFT", goldLabel, "RIGHT", 6, 0)
	local shop = W.Button(frame, L.SHOP, Layout.shop[3], Layout.shop[4])
	W.Place(shop, Layout.shop)
	shop:SetScript("OnClick", function()
		ns.Shop.Toggle()
	end)
	local shopHint = W.Label(frame, "GameFontDisableSmall", L.SHOP_HINT)
	W.PlaceText(shopHint, Layout.shopHint, "RIGHT")

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
		anvil.value:SetText(string.format(L.VALUE_AFTER_HIT, ns.Money(ns.Forge.Value(piece)), ns.Money(ns.Forge.ValueAt(piece, piece.level + 1))))
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
