-- Forgeborn: the anvil, the Workbench, selling, the Display case and the forge records.
local _, ns = ...

local Data, Rules = ns.Data, ns.Rules
local Forge = {}
ns.Forge = Forge

-- Randomness for swings: math.random over the token bag, with replacement. Tests may replace it.
function Forge.Random(n)
	return math.random(n)
end

function Forge.Quality(piece)
	return (Rules.QualityAt(piece.startQuality, piece.level))
end

-- Sale value in copper, with tools and Display case bonus.
function Forge.Value(piece)
	return Rules.ValueCopper(piece, ns.Economy.Mods(), ns.Economy.TrophyBonus())
end

-- Sale value in copper if the piece were at another level (the value after a Hit, for the window).
function Forge.ValueAt(piece, level)
	local copy = {}
	for k, v in pairs(piece) do
		copy[k] = v
	end
	copy.level = level
	return Forge.Value(copy)
end

-- Finds a piece by uid: returns piece, "anvil" | "bench", bench slot.
function Forge.Find(uid)
	local db = ns.db
	if db.anvil and db.anvil.uid == uid then
		return db.anvil, "anvil"
	end
	for slot = 1, Data.WORKBENCH_SLOTS do
		local piece = db.workbench[slot]
		if piece and piece.uid == uid then
			return piece, "bench", slot
		end
	end
	return nil
end

-- Removes a piece from wherever it is and returns it.
function Forge.Take(uid)
	local piece, where, slot = Forge.Find(uid)
	if where == "anvil" then
		ns.db.anvil = nil
	elseif where == "bench" then
		ns.db.workbench[slot] = nil
	end
	return piece
end

function Forge.FreeBenchSlot()
	for slot = 1, Data.WORKBENCH_SLOTS do
		if not ns.db.workbench[slot] then
			return slot
		end
	end
	return nil
end

-- Embers reset whenever a piece is put on the anvil.
local function arrive(piece)
	if piece then
		piece.embers = 0
	end
end

-- Workbench slot -> anvil. A piece already on the anvil goes back to that Workbench slot.
function Forge.PutOnAnvil(slot)
	local db = ns.db
	local piece = db.workbench[slot]
	if not piece then
		return nil, "ERR_EMPTY_SLOT"
	end
	db.workbench[slot] = db.anvil
	db.anvil = piece
	arrive(piece)
	return piece
end

-- Anvil -> Workbench (the given slot or the first free one). An occupied slot swaps with the anvil.
function Forge.Park(slot)
	local db = ns.db
	local piece = db.anvil
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	slot = slot or Forge.FreeBenchSlot()
	if not slot then
		return nil, "ERR_BENCH_FULL"
	end
	local other = db.workbench[slot]
	db.workbench[slot] = piece
	db.anvil = other
	arrive(other)
	return piece
end

function Forge.SwapBench(a, b)
	local bench = ns.db.workbench
	if a == b or not bench[a] then
		return nil, "ERR_EMPTY_SLOT"
	end
	bench[a], bench[b] = bench[b], bench[a]
	return true
end

function Forge.DiscardBench(slot)
	local piece = ns.db.workbench[slot]
	if not piece then
		return nil, "ERR_EMPTY_SLOT"
	end
	ns.db.workbench[slot] = nil
	return piece
end

-- Sort key for the Workbench: lowest quality first, then lowest item level, then lowest +N.
local function lower(a, b)
	local qa, qb = Forge.Quality(a), Forge.Quality(b)
	if qa ~= qb then
		return qa < qb
	end
	if a.itemLevel ~= b.itemLevel then
		return a.itemLevel < b.itemLevel
	end
	return a.level < b.level
end

-- A new drop arrives. With a full Workbench the weakest item goes, which can be the new drop itself
-- (on a full tie the new drop goes, so forged progress is kept).
-- Returns added (true/false) and the piece that was dropped, if any.
function Forge.AddDrop(piece)
	local db = ns.db
	piece.uid = ns.DB.NewUID()
	local free = Forge.FreeBenchSlot()
	if free then
		db.workbench[free] = piece
		return true, nil
	end
	local weakestSlot
	for slot = 1, Data.WORKBENCH_SLOTS do
		local current = db.workbench[slot]
		if not weakestSlot or lower(current, db.workbench[weakestSlot]) then
			weakestSlot = slot
		end
	end
	local weakest = db.workbench[weakestSlot]
	if not lower(weakest, piece) then
		return false, piece
	end
	db.workbench[weakestSlot] = piece
	return true, weakest
end

-- One swing on the anvil.
function Forge.Strike()
	local db = ns.db
	local piece = db.anvil
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	local mods = ns.Economy.Mods()
	local valueBefore = Rules.ValueCopper(piece, mods, ns.Economy.TrophyBonus())
	local result = Rules.Strike(piece, mods, Forge.Random)
	result.piece = piece
	local records, stats = db.records, db.stats
	stats.swings = stats.swings + 1
	if result.broken then
		stats.breaks = stats.breaks + 1
		records.streak = 0
		result.lostValue = valueBefore
		db.anvil = nil
	else
		records.streak = records.streak + 1
		if records.streak > records.bestStreak then
			records.bestStreak = records.streak
		end
		local quality = result.qualityAfter
		if (records.best[quality] or -1) < piece.level then
			records.best[quality] = piece.level
			result.newRecord = true
		end
		if result.qualityUp and quality == Data.MAX_QUALITY and piece.startQuality == 0 then
			records.grayToOrange = records.grayToOrange + 1
		end
		result.value = Forge.Value(piece)
	end
	return result
end

function Forge.Sell()
	local db = ns.db
	local piece = db.anvil
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	local value = Forge.Value(piece)
	ns.Economy.AddGold(value)
	db.stats.sold = db.stats.sold + 1
	db.stats.earned = db.stats.earned + value
	local records = db.records
	if value > records.bestSale then
		records.bestSale = value
		records.bestSaleName = piece.name
		records.bestSaleQuality = Forge.Quality(piece)
	end
	db.anvil = nil
	return value, piece
end

-- Keeps a piece (from the anvil or the Workbench) as a trophy instead of selling it.
function Forge.Display(uid)
	local db = ns.db
	local piece = Forge.Find(uid)
	if not piece then
		return nil, "ERR_NO_ITEM"
	end
	if #db.display >= ns.Economy.DisplaySlots() then
		return nil, "ERR_CASE_FULL"
	end
	local trophy = {
		itemID = piece.itemID,
		name = piece.name,
		link = piece.link,
		icon = piece.icon,
		startQuality = piece.startQuality,
		quality = Forge.Quality(piece),
		level = piece.level,
		itemLevel = piece.itemLevel,
		value = Forge.Value(piece),
		date = GetServerTime(),
	}
	Forge.Take(uid)
	table.insert(db.display, trophy)
	return trophy
end
