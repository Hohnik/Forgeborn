-- Forgeborn: building blocks for the window — item slots, drag and drop, tooltips, menus, popups, effects.
-- Everything is built from Blizzard's stock templates and art, so Forever's own look is used.
local _, ns = ...

local L, Data, Rules = ns.L, ns.Data, ns.Rules
local W = {}
ns.Widgets = W

---------------------------------------------------------------------------
-- Item slots (bag-style ItemButtons)
---------------------------------------------------------------------------

-- A bag-style slot. scale > 1 makes a bigger slot (the anvil).
function W.CreateSlot(parent, scale)
	local button = CreateFrame("ItemButton", nil, parent)
	button.emptyBackgroundAtlas = "bags-item-slot64" -- the empty slot art of the bags
	if scale and scale ~= 1 then
		button:SetScale(scale)
	end
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	W.SetSlot(button, nil)
	return button
end

-- Shows an icon with a quality border (quality nil = no border) and an optional count.
function W.SetSlot(button, icon, quality, count, desaturated)
	SetItemButtonTexture(button, icon)
	SetItemButtonQuality(button, quality)
	SetItemButtonCount(button, count or 0)
	SetItemButtonDesaturated(button, desaturated and true or false)
end

-- A small text label.
function W.Label(parent, font, text)
	local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
	if text then
		label:SetText(text)
	end
	return label
end

function W.Button(parent, text, width, height, template)
	local button = CreateFrame("Button", nil, parent, template or "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetText(text)
	return button
end

---------------------------------------------------------------------------
-- Drag and drop. Forged copies are not real items, so dragging runs on our own buttons:
-- the source button starts a drag, and on release the drop target under the mouse takes it.
---------------------------------------------------------------------------

local Drag = { targets = {}, payload = nil }
W.Drag = Drag

local cursor

local function ensureCursor()
	if cursor then
		return cursor
	end
	cursor = CreateFrame("Frame", nil, UIParent)
	cursor:SetFrameStrata("TOOLTIP")
	cursor:SetSize(32, 32)
	cursor:Hide()
	cursor.icon = cursor:CreateTexture(nil, "ARTWORK")
	cursor.icon:SetAllPoints()
	cursor:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale - 10)
	end)
	return cursor
end

-- target = { frame = button, accept = function(payload) -> bool, drop = function(payload) }
function Drag.Register(target)
	table.insert(Drag.targets, target)
end

-- payload = { kind = "piece" | "tool" | "pending" | "consumable", uid, from, slot, id, icon }
-- source = the button the drag started on.
function Drag.Start(payload, source)
	Drag.payload = payload
	Drag.source = source
	local c = ensureCursor()
	c.icon:SetTexture(payload.icon or 134400)
	c:Show()
	GameTooltip:Hide()
	ns.PlaySound("UI_CURSOR_PICKUP_OBJECT")
end

function Drag.Cancel()
	Drag.payload = nil
	if cursor then
		cursor:Hide()
	end
end

-- Called from the source button's OnDragStop: drops on the target under the mouse, if it accepts.
function Drag.Stop()
	local payload = Drag.payload
	Drag.lastStop = { source = Drag.source, time = GetTime() }
	Drag.source = nil
	Drag.Cancel()
	if not payload then
		return
	end
	for _, target in ipairs(Drag.targets) do
		local frame = target.frame
		if frame:IsVisible() and frame:IsMouseOver() and target.accept(payload) then
			target.drop(payload)
			ns.PlaySound("IG_ABILITY_ICON_DROP")
			return true
		end
	end
	return false
end

function Drag.IsDragging()
	return Drag.payload ~= nil
end

-- True for a click that only ends a drag from this button, so it doesn't also act as a click.
function Drag.ClickAfterDrag(button)
	local last = Drag.lastStop
	return last ~= nil and last.source == button and GetTime() - last.time < 0.3
end

---------------------------------------------------------------------------
-- Tooltips (our own: forged copies must not show the real item's stats)
---------------------------------------------------------------------------

local function hint(text)
	GameTooltip:AddLine(text, 0.5, 0.5, 0.5, true)
end

function W.PieceTooltip(owner, piece, where)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local quality = ns.Forge.Quality(piece)
	GameTooltip:SetText(string.format("%s +%d", piece.name, piece.level), ns.QualityColor(quality))
	GameTooltip:AddLine(string.format(L.TIP_QUALITY_ILVL, ns.QualityName(quality), piece.itemLevel), 1, 1, 1)
	if piece.startQuality ~= quality then
		GameTooltip:AddLine(string.format(L.TIP_STARTED_AS, ns.QualityName(piece.startQuality)), 0.8, 0.8, 0.8)
	end
	local toNext = Rules.LevelsToNext(piece.startQuality, piece.level)
	if toNext then
		GameTooltip:AddLine(string.format(L.TIP_TO_NEXT, toNext, ns.QualityName(quality + 1)), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(string.format(L.TIP_VALUE, ns.Money(ns.Forge.Value(piece))), 1, 1, 1)
	if (piece.frenzy or 0) > 0 then
		GameTooltip:AddLine(string.format(L.TIP_FRENZY, piece.frenzy), 1, 0.82, 0)
	end
	if (piece.safe or 0) > 0 then
		GameTooltip:AddLine(string.format(L.TIP_SAFE, piece.safe), 1, 0.82, 0)
	end
	if piece.swings and piece.swings > 0 then
		GameTooltip:AddLine(string.format(L.TIP_SWINGS, piece.swings), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(L.TIP_COPY, 0.5, 0.5, 0.5, true)
	if where == "bench" then
		hint(L.HINT_BENCH)
	elseif where == "anvil" then
		hint(L.HINT_ANVIL)
	elseif where == "order" then
		hint(L.HINT_ORDER_SLOT)
	end
	GameTooltip:Show()
end

function W.ToolTooltip(owner, tool, pending)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local quality = Data.RANK_QUALITY[tool.rank]
	GameTooltip:SetText(ns.ToolName(tool.id), ns.QualityColor(quality))
	GameTooltip:AddLine(string.format(L.TIP_TOOL_RANK, ns.RankName(tool.rank)), 1, 1, 1)
	GameTooltip:AddLine(ns.ToolEffectText(tool.id, tool.rank), 0.1, 1, 0.1, true)
	if tool.rank < Data.RANK_LEGENDARY and Rules.ToolValue(tool.id, tool.rank + 1) then
		GameTooltip:AddLine(string.format(L.TIP_NEXT_RANK, ns.RankName(tool.rank + 1), ns.ToolEffectText(tool.id, tool.rank + 1)), 0.8, 0.8, 0.8, true)
	end
	if pending then
		hint(L.HINT_PENDING_TOOL)
	else
		hint(L.HINT_TOOL)
	end
	GameTooltip:Show()
end

function W.TrophyTooltip(owner, trophy)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(string.format("%s +%d", trophy.name, trophy.level), ns.QualityColor(trophy.quality))
	GameTooltip:AddLine(string.format(L.TIP_QUALITY_ILVL, ns.QualityName(trophy.quality), trophy.itemLevel), 1, 1, 1)
	if trophy.startQuality ~= trophy.quality then
		GameTooltip:AddLine(string.format(L.TIP_STARTED_AS, ns.QualityName(trophy.startQuality)), 0.8, 0.8, 0.8)
	end
	local bonus = (Data.TROPHY_BONUS[trophy.quality] or 0) * (Data.TROPHY_MULTIPLIER[ns.Economy.Rank("ARGENT")] or 1)
	GameTooltip:AddLine(string.format(L.TIP_TROPHY_BONUS, string.format("%g", bonus * 100)), 0.1, 1, 0.1)
	GameTooltip:AddLine(string.format(L.TIP_TROPHY_VALUE, ns.Money(trophy.value)), 0.8, 0.8, 0.8)
	hint(L.HINT_TROPHY)
	GameTooltip:Show()
end

function W.ConsumableTooltip(owner, id)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local def = Data.CONSUMABLES[id]
	GameTooltip:SetText(ns.ConsumableName(id), ns.QualityColor(1))
	GameTooltip:AddLine(def.safe == 1 and L.EFFECT_SAFE_ONE or string.format(L.EFFECT_SAFE_MANY, def.safe), 0.1, 1, 0.1, true)
	GameTooltip:AddLine(string.format(L.TIP_OWNED, ns.db.consumables[id] or 0), 1, 1, 1)
	hint(L.HINT_CONSUMABLE)
	GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Context menus and confirmation popups
---------------------------------------------------------------------------

-- entries = { { text, func }, ... }
function W.Menu(owner, title, entries)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		if title then
			root:CreateTitle(title)
		end
		for _, entry in ipairs(entries) do
			root:CreateButton(entry[1], entry[2])
		end
	end)
end

StaticPopupDialogs.FORGEBORN_CONFIRM = {
	text = "%s",
	button1 = YES or L.YES,
	button2 = NO or L.NO,
	OnAccept = function(_, data)
		if data and data.callback then
			data.callback()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	showAlert = 1,
}

function W.Confirm(text, callback)
	StaticPopup_Show("FORGEBORN_CONFIRM", text, nil, { callback = callback })
end

---------------------------------------------------------------------------
-- Effects: a coloured glow (quality-up, Frenzy) and a red flash (break) over a slot.
---------------------------------------------------------------------------

local function makeAnimation(texture, peak, fadeIn, fadeOut)
	local group = texture:CreateAnimationGroup()
	local show = group:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(peak)
	show:SetDuration(fadeIn)
	show:SetOrder(1)
	local hide = group:CreateAnimation("Alpha")
	hide:SetFromAlpha(peak)
	hide:SetToAlpha(0)
	hide:SetDuration(fadeOut)
	hide:SetOrder(2)
	group:SetScript("OnFinished", function()
		texture:Hide()
	end)
	return group
end

function W.AddEffects(button)
	-- The same highlight art the game's item buttons use, tinted and pulsed.
	local glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
	glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	glow:SetBlendMode("ADD")
	glow:SetAllPoints()
	glow:SetAlpha(0)
	glow:Hide()
	button.FbGlow = glow
	button.FbGlowAnim = makeAnimation(glow, 1, 0.15, 0.9)

	local flash = button:CreateTexture(nil, "OVERLAY", nil, 6)
	flash:SetColorTexture(1, 0.1, 0.05)
	flash:SetAllPoints()
	flash:SetAlpha(0)
	flash:Hide()
	button.FbFlash = flash
	button.FbFlashAnim = makeAnimation(flash, 0.8, 0.05, 0.6)
end

function W.Glow(button, r, g, b)
	if not button.FbGlow then
		return
	end
	button.FbGlow:SetVertexColor(r, g, b)
	button.FbGlow:Show()
	button.FbGlowAnim:Stop()
	button.FbGlowAnim:Play()
end

function W.Flash(button)
	if not button.FbFlash then
		return
	end
	button.FbFlash:Show()
	button.FbFlashAnim:Stop()
	button.FbFlashAnim:Play()
end
