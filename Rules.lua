-- Forgeborn: the rules engine (v0.4). Pure Lua 5.1, no WoW API calls, so it runs in the tests.
--
-- v0.4 follows ForgeTax's anvil: the odds depend on the item's grade, so they change with every level a swing
-- gains or loses, and every level multiplies the value by Data.VALUE_PER_LEVEL.
--
-- A forged item ("piece") is a table:
--   startQuality  quality it dropped at (0 gray .. 5 orange)
--   level         +N, counted from the start quality
--   itemLevel     real item level, used for the value
--   kind          "weapon" or "armor"
--   embers        normal swings since the last Frenzy (reset when it is put on the anvil)
--   frenzy        safe swings left from a Frenzy
--   safe          safe swings left from sharpening stones
--   afterMiss     true after a Miss until the next Hit (Dark Iron Bar)
--   sulfuronUsed  true once the Sulfuron Ingot has turned a Break into a Crack for this item
--   swings        swings taken on this item
local _, ns = ...

local Data = ns.Data
local Rules = {}
ns.Rules = Rules

local BREAK, CRACK, MISS, HIT, GREAT = Data.BREAK, Data.CRACK, Data.MISS, Data.HIT, Data.GREAT
local floor, max, min = math.floor, math.max, math.min

-- Quality reached at a level, and the level where that quality starts (a Crack never goes below it).
function Rules.QualityAt(startQuality, level)
	local quality, start = startQuality, 0
	while quality < Data.MAX_QUALITY and level >= start + Data.LEVELS_TO_NEXT[quality] do
		start = start + Data.LEVELS_TO_NEXT[quality]
		quality = quality + 1
	end
	return quality, start
end

-- Level where each quality starts, counted from the start of gray: 0, 4, 8, 13, 19, 26.
local QUALITY_START = { [0] = 0 }
for quality = 1, Data.MAX_QUALITY do
	QUALITY_START[quality] = QUALITY_START[quality - 1] + Data.LEVELS_TO_NEXT[quality - 1]
end
Rules.QUALITY_START = QUALITY_START

-- The grade sets the odds: the level counted from the start of gray. A blue drop at +0 is grade 13.
function Rules.Grade(startQuality, level)
	return QUALITY_START[startQuality] + level
end

function Rules.PieceGrade(piece)
	return Rules.Grade(piece.startQuality, piece.level)
end

-- Break chance (0 to 1) at a grade on the plain deck, read from Data.BREAK_CURVE.
function Rules.BreakChance(grade)
	local curve = Data.BREAK_CURVE
	if grade <= curve[1][1] then
		return curve[1][2] / 100
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if grade <= b[1] then
			return (a[2] + (b[2] - a[2]) * (grade - a[1]) / (b[1] - a[1])) / 100
		end
	end
	return curve[#curve][2] / 100
end

-- Levels still needed for the next quality, or nil at orange.
function Rules.LevelsToNext(startQuality, level)
	local quality, start = Rules.QualityAt(startQuality, level)
	if quality >= Data.MAX_QUALITY then
		return nil
	end
	return start + Data.LEVELS_TO_NEXT[quality] - level
end

function Rules.NewMods()
	return {
		hit = 0, great = 0, crack = 0, miss = 0, brk = 0,
		greatGain = 2,
		afterMissHit = nil,
		frenzySwings = Data.FRENZY_SWINGS,
		frenzyEvery = Data.EMBERS_FOR_FRENZY,
		weaponValue = 0, armorValue = 0, highValue = 0, orangeValue = 0,
		sulfuron = false,
	}
end

-- Effect value of a tool at a rank, or nil when that rank doesn't exist for the tool.
function Rules.ToolValue(toolID, rank)
	local def = Data.TOOLS[toolID]
	if not def or type(rank) ~= "number" then
		return nil
	end
	return def.values[rank]
end

-- Combined effect of the tools on the shelf. shelf[1..SHELF_SLOTS] = { id = toolID, rank = n } or nil.
function Rules.ModsFromShelf(shelf)
	local mods = Rules.NewMods()
	if not shelf then
		return mods
	end
	for slot = 1, Data.SHELF_SLOTS do
		local tool = shelf[slot]
		local def = tool and Data.TOOLS[tool.id]
		local value = def and Rules.ToolValue(tool.id, tool.rank)
		if value then
			local effect = def.effect
			if effect == "hit" then
				mods.hit = mods.hit + value
			elseif effect == "great" then
				mods.great = mods.great + value
			elseif effect == "crack" then
				mods.crack = mods.crack + value
			elseif effect == "miss" then
				mods.miss = mods.miss + value
			elseif effect == "break" then
				mods.brk = mods.brk + value
			elseif effect == "hitMiss" then
				mods.hit = mods.hit + value
				mods.miss = mods.miss + value
			elseif effect == "greatGain" then
				mods.greatGain = max(mods.greatGain, value)
			elseif effect == "afterMissHit" then
				mods.afterMissHit = max(mods.afterMissHit or 1, value)
			elseif effect == "frenzySwings" then
				mods.frenzySwings = max(mods.frenzySwings, value)
			elseif effect == "frenzyEvery" then
				mods.frenzyEvery = min(mods.frenzyEvery, value)
			elseif effect == "orangeValue" then
				mods.orangeValue = mods.orangeValue + value
			elseif effect == "weaponValue" then
				mods.weaponValue = mods.weaponValue + value
			elseif effect == "armorValue" then
				mods.armorValue = mods.armorValue + value
			elseif effect == "highValue" then
				mods.highValue = mods.highValue + value
			elseif effect == "sulfuron" then
				mods.sulfuron = true
			end
		end
	end
	return mods
end

-- Token weights for a grade after tools, in outcome order. Crack, Miss, Hit and Great hit come from Data.DECK;
-- Break gets the weight that gives the curve's chance on the plain deck. Break's weight depends on the grade, not on
-- the deck size, so a tool that adds tokens to another pile also lowers the Break chance (as in ForgeTax).
function Rules.Bag(grade, mods)
	local deck = Data.DECK
	local plain = deck[CRACK] + deck[MISS] + deck[HIT] + deck[GREAT]
	local chance = min(Rules.BreakChance(grade), 0.99)
	local bag = { plain * chance / (1 - chance), deck[CRACK], deck[MISS], deck[HIT], deck[GREAT] }
	if mods then
		bag[BREAK] = max(0, bag[BREAK] - mods.brk)
		bag[CRACK] = max(0, bag[CRACK] - mods.crack)
		bag[MISS] = max(0, bag[MISS] - mods.miss)
		bag[HIT] = bag[HIT] + mods.hit
		bag[GREAT] = bag[GREAT] + mods.great
	end
	return bag
end

-- Splits size into whole numbers in proportion to the weights (largest remainder), in outcome order.
local function apportion(weights, size)
	local total = 0
	for outcome = BREAK, GREAT do
		total = total + (weights[outcome] or 0)
	end
	local result, remainders, used = {}, {}, 0
	for outcome = BREAK, GREAT do
		local exact = total > 0 and (weights[outcome] or 0) * size / total or 0
		result[outcome] = floor(exact)
		remainders[outcome] = exact - result[outcome]
		used = used + result[outcome]
	end
	local left = size - used
	while left > 0 do
		local best
		for outcome = BREAK, GREAT do
			if remainders[outcome] > 0 and (not best or remainders[outcome] > remainders[best]) then
				best = outcome
			end
		end
		if not best then
			break
		end
		result[best] = result[best] + 1
		remainders[best] = 0
		left = left - 1
	end
	return result
end

-- The bag as whole tickets out of Data.TICKETS. Every swing draws one of these, so the odds shown are exact.
function Rules.Tickets(bag)
	return apportion(bag, Data.TICKETS)
end

-- A safe swing redraws Miss, Crack and Break, which is the same as drawing only from Hit and Great hit.
local function counts(tickets, outcome, safe)
	if safe and outcome < HIT then
		return 0
	end
	return tickets[outcome]
end

-- Chance of each outcome (fractions that add up to 1).
function Rules.Odds(bag, safe)
	local tickets = Rules.Tickets(bag)
	local total = 0
	for outcome = BREAK, GREAT do
		total = total + counts(tickets, outcome, safe)
	end
	local odds = {}
	for outcome = BREAK, GREAT do
		odds[outcome] = total > 0 and counts(tickets, outcome, safe) / total or 0
	end
	return odds
end

-- Whole percentages that always add up to 100 (largest remainder).
function Rules.Percentages(odds)
	return apportion(odds, 100)
end

-- Draws one ticket with replacement. rand(n) returns a whole number from 1 to n (math.random).
function Rules.Draw(bag, safe, rand)
	local tickets = Rules.Tickets(bag)
	local total = 0
	for outcome = BREAK, GREAT do
		total = total + counts(tickets, outcome, safe)
	end
	if total <= 0 then
		return MISS
	end
	local roll = rand(total)
	for outcome = BREAK, GREAT do
		roll = roll - counts(tickets, outcome, safe)
		if roll <= 0 then
			return outcome
		end
	end
	return GREAT
end

function Rules.IsSafe(piece)
	return (piece.frenzy or 0) > 0 or (piece.safe or 0) > 0
end

-- The odds of the next swing for a piece.
function Rules.NextOdds(piece, mods)
	return Rules.Odds(Rules.Bag(Rules.PieceGrade(piece), mods), Rules.IsSafe(piece))
end

-- One swing. Changes the piece and returns what happened.
function Rules.Strike(piece, mods, rand)
	local qualityBefore, floorLevel = Rules.QualityAt(piece.startQuality, piece.level)
	local safe = Rules.IsSafe(piece)
	local drawn = Rules.Draw(Rules.Bag(Rules.PieceGrade(piece), mods), safe, rand)
	local result = {
		drawn = drawn,
		outcome = drawn,
		safe = safe,
		levelBefore = piece.level,
		qualityBefore = qualityBefore,
	}

	if drawn == BREAK and mods.sulfuron and not piece.sulfuronUsed then
		piece.sulfuronUsed = true
		result.outcome = CRACK
		result.sulfuron = true
	end

	local outcome, gain = result.outcome, 0
	if outcome == BREAK then
		result.broken = true
	elseif outcome == CRACK then
		gain = -1
	elseif outcome == MISS then
		piece.afterMiss = true
	elseif outcome == HIT then
		if piece.afterMiss and mods.afterMissHit then
			gain = mods.afterMissHit
			result.darkIron = true
		else
			gain = 1
		end
		piece.afterMiss = false
	elseif outcome == GREAT then
		gain = mods.greatGain
	end

	if not result.broken then
		piece.level = max(floorLevel, piece.level + gain)
	end
	result.levelAfter = piece.level
	result.gain = piece.level - result.levelBefore

	if (piece.frenzy or 0) > 0 then
		piece.frenzy = piece.frenzy - 1
	elseif (piece.safe or 0) > 0 then
		piece.safe = piece.safe - 1
	else
		piece.embers = (piece.embers or 0) + 1
	end
	if not result.broken and (piece.frenzy or 0) == 0 and (piece.embers or 0) >= mods.frenzyEvery then
		piece.embers = 0
		piece.frenzy = mods.frenzySwings
		result.frenzyStarted = true
	end
	piece.swings = (piece.swings or 0) + 1

	result.qualityAfter = Rules.QualityAt(piece.startQuality, piece.level)
	result.qualityUp = not result.broken and result.qualityAfter > qualityBefore
	return result
end

-- Value in silver: item level x the start quality's factor x 1.2 per level, then tool and trophy bonuses.
function Rules.ValueSilver(piece, mods, trophyBonus)
	local quality = Rules.QualityAt(piece.startQuality, piece.level)
	local value = piece.itemLevel * Data.VALUE_FACTOR[piece.startQuality] * Data.VALUE_PER_LEVEL ^ piece.level
	if mods then
		if piece.kind == "weapon" then
			value = value * (1 + mods.weaponValue)
		elseif piece.kind == "armor" then
			value = value * (1 + mods.armorValue)
		end
		if quality >= 4 then
			value = value * (1 + mods.highValue)
		end
		if quality == Data.MAX_QUALITY then
			value = value * (1 + mods.orangeValue)
		end
	end
	return value * (1 + (trophyBonus or 0))
end

-- Value in copper, rounded to the nearest copper.
function Rules.ValueCopper(piece, mods, trophyBonus)
	return floor(Rules.ValueSilver(piece, mods, trophyBonus) * 100 + 0.5)
end
