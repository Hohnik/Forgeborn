-- Forgeborn: small helpers shared by the game modules and the window (text, colours, sounds, events).
local _, ns = ...

local Data, Rules = ns.Data, ns.Rules
local L = ns.L

---------------------------------------------------------------------------
-- Change notifications: game modules call ns.Changed(), the window listens.
---------------------------------------------------------------------------

local listeners = {}

function ns.OnChanged(fn)
	table.insert(listeners, fn)
end

function ns.Changed()
	for _, fn in ipairs(listeners) do
		fn()
	end
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

function ns.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffe6b34dForgeborn|r: " .. tostring(text))
end

function ns.PlaySound(key)
	if ns.db and ns.db.settings.sound and SOUNDKIT and SOUNDKIT[key] then
		PlaySound(SOUNDKIT[key])
	end
end

-- Addon gold as gold, silver and copper with coin icons.
function ns.Money(copper)
	return GetMoneyString(math.max(0, math.floor(copper)), true)
end

-- Error keys from the game modules, as text.
function ns.ErrorText(key)
	return L[key] or tostring(key)
end

function ns.Error(key)
	UIErrorsFrame:AddMessage(ns.ErrorText(key), 1, 0.1, 0.1, 1)
end

---------------------------------------------------------------------------
-- Colours and names
---------------------------------------------------------------------------

function ns.QualityColor(quality)
	local r, g, b = C_Item.GetItemQualityColor(quality or 1)
	return r or 1, g or 1, b or 1
end

function ns.Colorize(text, quality)
	local r, g, b = ns.QualityColor(quality)
	return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

function ns.QualityName(quality)
	return L["QUALITY_" .. quality]
end

-- The client knows every item's name in the player's language; until it has loaded, use our own.
local function itemName(itemID, fallbackKey)
	local name = C_Item.GetItemNameByID(itemID)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return L[fallbackKey]
end

function ns.ToolName(id)
	return itemName(Data.TOOLS[id].item, "TOOL_" .. id)
end

function ns.ConsumableName(id)
	return itemName(Data.CONSUMABLES[id].item, "ITEM_" .. id)
end

function ns.LockboxName(id)
	return itemName(Data.LOCKBOXES[id].item, "LOCKBOX_" .. id)
end

-- Asks the client to load the names of every item we show, so they appear in the player's language.
function ns.RequestItemNames()
	local ids = {}
	for _, def in pairs(Data.TOOLS) do
		table.insert(ids, def.item)
	end
	for _, def in pairs(Data.CONSUMABLES) do
		table.insert(ids, def.item)
	end
	for _, def in pairs(Data.LOCKBOXES) do
		table.insert(ids, def.item)
	end
	for _, id in ipairs(ids) do
		if not C_Item.IsItemDataCachedByID(id) then
			C_Item.RequestLoadItemDataByID(id)
		end
	end
end

function ns.RankName(rank)
	return L["RANK_" .. rank]
end

-- The capital city of this character's race (or faction).
function ns.CityKey()
	local _, raceFile = UnitRace("player")
	local city = raceFile and Data.CITY_BY_RACE[raceFile]
	if not city then
		city = Data.CITY_BY_FACTION[UnitFactionGroup("player") or ""] or "STORMWIND"
	end
	return city
end

function ns.FactionName(faction)
	if faction == "CITY" then
		return L["CITY_" .. ns.CityKey()]
	end
	return L["FACTION_" .. faction]
end

function ns.FactionShortName(faction)
	if faction == "CITY" then
		return L["CITY_" .. ns.CityKey()]
	end
	return L["FACTION_SHORT_" .. faction]
end

-- Neutral .. Exalted in the player's language (the game's own standing names).
function ns.StandingName(rank)
	local id = Data.REP_STANDING_ID[rank]
	local name = id and _G["FACTION_STANDING_LABEL" .. id]
	if type(name) == "string" and name ~= "" then
		return name
	end
	return L["STANDING_" .. rank]
end

-- What a tool does at a rank, as one line of text.
function ns.ToolEffectText(id, rank)
	local def = Data.TOOLS[id]
	local value = Rules.ToolValue(id, rank)
	if not def or not value then
		return ""
	end
	local key = "EFFECT_" .. def.effect
	if def.effect == "weaponValue" or def.effect == "armorValue" or def.effect == "highValue" then
		return string.format(L[key], math.floor(value * 100 + 0.5))
	elseif def.effect == "orangeFactor" then
		return string.format(L[key], (string.format("%g", value)))
	elseif def.effect == "sulfuron" then
		return L[key]
	end
	if value == 1 and rawget(L, key .. "_ONE") then
		key = key .. "_ONE"
	end
	return string.format(L[key], value, value)
end

-- "Blue one-hand weapon", "3 blue armour pieces", "White cloth gloves".
-- Some languages put the quality after the item (L.ASK_THING_FIRST).
function ns.OrderAskText(order)
	local qualityName = ns.QualityName(order.minQuality)
	local lower = string.lower(qualityName)
	local thing
	if order.weekly then
		if order.armorType and order.group == "ARMOR" then
			thing = string.format(L.ASK_ARMOR_TYPE_PIECES, L["ARMOR_TYPE_" .. order.armorType])
		else
			thing = L["ASK_PIECES_" .. order.group]
		end
		if L.ASK_THING_FIRST then
			return string.format(L.ASK_WEEKLY, order.count, thing, lower)
		end
		return string.format(L.ASK_WEEKLY, order.count, lower, thing)
	end
	if order.armorType then
		thing = string.format(L.ASK_TYPED_SLOT, L["ARMOR_TYPE_" .. order.armorType], L["SLOT_" .. order.group])
	else
		thing = L["SLOT_" .. order.group]
	end
	if L.ASK_THING_FIRST then
		return string.format(L.ASK_DAILY, thing, lower)
	end
	return string.format(L.ASK_DAILY, qualityName, thing)
end

function ns.ItemLevelRangeText(order)
	if order.ilvlMax then
		return string.format(L.ILVL_RANGE, order.ilvlMin, order.ilvlMax)
	end
	return string.format(L.ILVL_MIN, order.ilvlMin)
end

-- "5 h 12 min", "12 min", "1 min".
function ns.DurationText(seconds)
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.max(1, math.floor((seconds % 3600) / 60))
	if days > 0 then
		return string.format(L.DURATION_DAYS, days, hours)
	elseif hours > 0 then
		return string.format(L.DURATION_HOURS, hours, minutes)
	end
	return string.format(L.DURATION_MINUTES, minutes)
end

-- The name of a forged copy with its +N, in its current quality colour.
function ns.PieceTitle(piece)
	return ns.Colorize(string.format("%s +%d", piece.name, piece.level), ns.Forge.Quality(piece))
end
