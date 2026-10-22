-- Forgeborn: finds newly looted weapons and armour and puts a forge copy on the Workbench.
--
-- Only real drops count: items shown in a loot window (mobs, chests) and won loot rolls.
-- 1. The loot window's weapons and armour become "expected drops" (by item ID, for a few minutes).
--    Loot from a container item in the bags (LOOT_OPENED with isFromItem) does not count.
-- 2. On BAG_UPDATE_DELAYED the bags are scanned for item GUIDs that weren't there before.
--    A new item whose ID matches an expected drop goes to the Workbench.
-- 3. Nothing counts while a merchant, mailbox, trade, auction house or bank window is open,
--    and quest rewards (QUEST_LOOT_RECEIVED) cancel a matching expectation.
-- The real item is never touched; the Workbench holds a copy that lives only in the saved data.
local _, ns = ...

local Data = ns.Data
local Loot = {}
ns.Loot = Loot

local expected = {} -- { itemID = n, expires = t }
local known = nil -- item GUID -> true, from the last scan
local lastLoot = {} -- expectations added by the current loot window
local lootFromItem = false -- the open loot window belongs to a container item in the bags
local blockers = {} -- window name -> true while open

local ARMOR_LOCS, WEAPON_LOCS = {}, {}
for _, locs in pairs(Data.ARMOR_SLOTS) do
	for _, loc in ipairs(locs) do
		ARMOR_LOCS[loc] = true
	end
end
for _, locs in pairs(Data.WEAPON_GROUPS) do
	for _, loc in ipairs(locs) do
		WEAPON_LOCS[loc] = true
	end
end

-- Weapons and armour only. Rings, necklaces, trinkets, shirts, tabards, relics, thrown weapons
-- and fishing poles are left out.
function Loot.IsEligible(itemInfo)
	if not itemInfo then
		return false
	end
	local itemID, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemInfo)
	if not itemID then
		return false
	end
	if classID == Data.CLASS_WEAPON then
		return WEAPON_LOCS[equipLoc] == true and subclassID ~= Data.WEAPON_SUBCLASS_FISHING_POLE
	elseif classID == Data.CLASS_ARMOR then
		return ARMOR_LOCS[equipLoc] == true
	end
	return false
end

local function now()
	return GetTime()
end

local function expect(itemID, seconds)
	local entry = { itemID = itemID, expires = now() + seconds }
	table.insert(expected, entry)
	return entry
end

local function pruneExpected()
	local t = now()
	for i = #expected, 1, -1 do
		if expected[i].expires < t then
			table.remove(expected, i)
		end
	end
end

-- Uses up one expectation for an item ID. Returns true if there was one.
local function consumeExpected(itemID)
	pruneExpected()
	for i, entry in ipairs(expected) do
		if entry.itemID == itemID then
			table.remove(expected, i)
			return true
		end
	end
	return false
end

local function cancelEntries(entries)
	for _, entry in ipairs(entries) do
		for i = #expected, 1, -1 do
			if expected[i] == entry then
				table.remove(expected, i)
			end
		end
	end
end

-- LOOT_READY can fire more than once for one window, so the window's expectations are rebuilt, not added twice.
function Loot.OnLootReady()
	cancelEntries(lastLoot)
	lastLoot = {}
	if lootFromItem then
		return
	end
	for slot = 1, GetNumLootItems() do
		if GetLootSlotType(slot) == Enum.LootSlotType.Item then
			local link = GetLootSlotLink(slot)
			if link and Loot.IsEligible(link) then
				local itemID = C_Item.GetItemInfoInstant(link)
				table.insert(lastLoot, expect(itemID, Data.EXPECTED_DROP_SECONDS))
			end
		end
	end
end

function Loot.OnLootOpened(_, isFromItem)
	if isFromItem then
		lootFromItem = true
		cancelEntries(lastLoot)
		lastLoot = {}
	end
end

function Loot.OnLootClosed()
	lastLoot = {}
	lootFromItem = false
end

function Loot.OnRollWon(itemLink)
	if itemLink and Loot.IsEligible(itemLink) then
		expect((C_Item.GetItemInfoInstant(itemLink)), Data.ROLL_WON_SECONDS)
	end
end

function Loot.OnQuestLoot(itemLink)
	if itemLink then
		local itemID = C_Item.GetItemInfoInstant(itemLink)
		if itemID then
			consumeExpected(itemID)
		end
	end
end

function Loot.SetBlocked(window, isOpen)
	blockers[window] = isOpen or nil
end

function Loot.IsBlocked()
	return next(blockers) ~= nil
end

-- A window's close event could be missed; looting or a loading screen means no such window is open.
function Loot.ClearBlocked()
	blockers = {}
end

-- Every weapon and armour GUID in the bags: guid -> { bag, slot, itemID, link }.
local function scanBags()
	local found = {}
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and info.hyperlink then
				local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
				if C_Item.DoesItemExist(location) then
					local guid = C_Item.GetItemGUID(location)
					if guid then
						found[guid] = { bag = bag, slot = slot, itemID = info.itemID, link = info.hyperlink }
					end
				end
			end
		end
	end
	return found
end

-- Remembers what is in the bags now, without adding anything (login, reload).
function Loot.Snapshot()
	known = {}
	for guid in pairs(scanBags()) do
		known[guid] = true
	end
end

-- Builds a forge copy from a looted item. Calls done(piece) once the item data is loaded.
function Loot.MakePiece(link, done)
	local item = Item:CreateFromItemLink(link)
	if item:IsItemEmpty() then
		return
	end
	item:ContinueOnItemLoad(function()
		local name, itemLink, quality, _, _, _, _, _, equipLoc, icon, _, classID, subclassID = C_Item.GetItemInfo(link)
		if not name then
			return
		end
		local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
		local itemID = C_Item.GetItemInfoInstant(link)
		local piece = {
			itemID = itemID,
			name = name,
			link = itemLink or link,
			icon = icon,
			startQuality = math.min(math.max(quality or 0, 0), Data.MAX_QUALITY),
			level = 0,
			itemLevel = math.max(1, math.floor(itemLevel or 1)),
			kind = classID == Data.CLASS_WEAPON and "weapon" or "armor",
			equipLoc = equipLoc or "",
			armorType = classID == Data.CLASS_ARMOR and subclassID or nil,
			embers = 0,
			frenzy = 0,
			safe = 0,
			swings = 0,
		}
		done(piece)
	end)
end

-- Scans the bags for new drops. onDrop(piece, added, dropped) is called for each new drop.
function Loot.Scan(onDrop)
	local found = scanBags()
	if not known then
		known = {}
		for guid in pairs(found) do
			known[guid] = true
		end
		return
	end
	local blocked = Loot.IsBlocked()
	for guid, entry in pairs(found) do
		if not known[guid] then
			known[guid] = true
			if not blocked and Loot.IsEligible(entry.link) and consumeExpected(entry.itemID) then
				Loot.MakePiece(entry.link, function(piece)
					local added, dropped = ns.Forge.AddDrop(piece)
					if onDrop then
						onDrop(piece, added, dropped)
					end
				end)
			end
		end
	end
	-- Forget GUIDs that left the bags, so the table doesn't grow forever.
	for guid in pairs(known) do
		if not found[guid] then
			known[guid] = nil
		end
	end
end

-- For tests.
function Loot.Reset()
	expected, known, lastLoot, blockers, lootFromItem = {}, nil, {}, {}, false
end

function Loot.ExpectedCount()
	pruneExpected()
	return #expected
end
