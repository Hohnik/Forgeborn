-- Rules engine tests: the numbers in docs/design.md and tools/playtest must come out of Rules.lua.
local T = ...
local ns = T.loadAddonFiles({ "Data.lua", "Rules.lua" })
local Data, Rules = ns.Data, ns.Rules
local BREAK, CRACK, MISS, HIT, GREAT = Data.BREAK, Data.CRACK, Data.MISS, Data.HIT, Data.GREAT

local function piece(startQuality, level, extra)
	local p = { startQuality = startQuality, level = level, itemLevel = 20, kind = "armor", embers = 0, frenzy = 0, safe = 0, swings = 0 }
	for k, v in pairs(extra or {}) do
		p[k] = v
	end
	return p
end

-- A scripted random source: returns the given numbers in turn.
local function scripted(...)
	local values, i = { ... }, 0
	return function(n)
		i = i + 1
		local v = values[i]
		assert(v, "scripted random ran out")
		assert(v >= 1 and v <= n, "scripted value " .. v .. " outside 1.." .. n)
		return v
	end
end

-- Roll that lands on the first ticket of an outcome in a bag.
local function rollFor(bag, outcome, safe)
	local tickets = Rules.Tickets(bag)
	local sum = 0
	for o = BREAK, outcome - 1 do
		if not safe or o >= HIT then
			sum = sum + tickets[o]
		end
	end
	return sum + 1
end

-- The bag of a piece as it is now.
local function bagOf(p, mods)
	return Rules.Bag(Rules.PieceGrade(p), mods)
end

T.test("the grade counts levels from the start of gray", function()
	T.eq(Rules.Grade(0, 0), 0)
	T.eq(Rules.Grade(0, 14), 14)
	T.eq(Rules.Grade(1, 0), 4)
	T.eq(Rules.Grade(2, 0), 8)
	T.eq(Rules.Grade(3, 0), 13, "a blue drop starts at grade 13")
	T.eq(Rules.Grade(4, 2), 21)
	T.eq(Rules.Grade(5, 0), 26)
end)

T.test("break curve: the design points, and it rises with every level", function()
	local points = { [0] = 0, [2] = 0.02, [4] = 0.06, [8] = 0.12, [13] = 0.20, [19] = 0.30, [26] = 0.40, [36] = 0.55, [50] = 0.70 }
	for grade, chance in pairs(points) do
		T.near(Rules.BreakChance(grade), chance, 1e-12, "grade " .. grade)
	end
	T.near(Rules.BreakChance(10), 0.152, 1e-12, "between two points it rises evenly")
	T.near(Rules.BreakChance(80), 0.70, 1e-12, "after the last point it stays")
	for grade = 0, 49 do
		T.ok(Rules.BreakChance(grade + 1) > Rules.BreakChance(grade), "break rises from grade " .. grade)
	end
end)

T.test("the bag: the deck plus a Break pile that gives the curve's chance", function()
	for grade = 0, 60 do
		local bag = Rules.Bag(grade, Rules.NewMods())
		T.eq(bag[CRACK], 2); T.eq(bag[MISS], 4); T.eq(bag[HIT], 12); T.eq(bag[GREAT], 2)
		local total = bag[BREAK] + 20
		T.near(bag[BREAK] / total, Rules.BreakChance(grade), 1e-12, "grade " .. grade)
		local tickets, sum = Rules.Tickets(bag), 0
		for o = BREAK, GREAT do
			sum = sum + tickets[o]
		end
		T.eq(sum, 1000, "tickets at grade " .. grade)
	end
	local blue = Rules.Tickets(Rules.Bag(13))
	T.eq(blue[BREAK], 200); T.eq(blue[CRACK], 80); T.eq(blue[MISS], 160); T.eq(blue[HIT], 480); T.eq(blue[GREAT], 80)
end)

T.test("the odds change with every hit", function()
	local mods = Rules.NewMods()
	local p = piece(0, 9)
	local before = Rules.NextOdds(p, mods)
	p.level = 10
	local after = Rules.NextOdds(p, mods)
	T.ok(after[BREAK] > before[BREAK], "a Hit raises the Break chance")
	T.ok(after[HIT] < before[HIT], "and lowers the others")
	p.level = 9
	T.near(Rules.NextOdds(p, mods)[BREAK], before[BREAK], 1e-12, "a Crack lowers it again")
end)

T.test("quality ladder from gray: 4, 4, 5, 6, 7 levels", function()
	local starts = { [0] = 0, 4, 8, 13, 19, 26 }
	for level = 0, 40 do
		local q, start = Rules.QualityAt(0, level)
		local expected = 0
		for quality = 1, 5 do
			if level >= starts[quality] then
				expected = quality
			end
		end
		T.eq(q, expected, "quality at level " .. level)
		T.eq(start, starts[expected], "floor at level " .. level)
	end
	for q = 0, 5 do
		T.eq(Rules.QUALITY_START[q], starts[q], "start of quality " .. q)
	end
	T.eq(Rules.LevelsToNext(0, 14), 5, "blue +14 needs 5 more levels")
	T.eq(Rules.LevelsToNext(0, 26), nil, "orange has no next quality")
end)

T.test("a blue drop counts its levels from blue", function()
	T.eq(Rules.QualityAt(3, 0), 3)
	T.eq(Rules.QualityAt(3, 5), 3)
	T.eq(Rules.QualityAt(3, 6), 4)
	T.eq(Rules.QualityAt(3, 13), 5)
	T.eq(Rules.QualityAt(5, 0), 5)
	T.eq(Rules.QualityAt(5, 50), 5)
end)

T.test("value: item level x start quality factor x 1.2 per level", function()
	local mods = Rules.NewMods()
	-- Gray +0 at item level 20: 20 silver. Every level is worth x1.2.
	T.eq(Rules.ValueCopper(piece(0, 0), mods), 2000)
	T.eq(Rules.ValueCopper(piece(0, 1), mods), 2400)
	T.eq(Rules.ValueCopper(piece(0, 2), mods), 2880)
	T.eq(Rules.ValueCopper(piece(0, 13), mods), 21399, "gray taken to blue: 20 x 1.2^13 silver")
	-- A blue drop starts at its quality factor: 20 x 3.2 = 64 silver, then x1.2 per level.
	T.eq(Rules.ValueCopper(piece(3, 0), mods), 6400)
	T.eq(Rules.ValueCopper(piece(3, 5), mods), 15925)
	for level = 0, 30 do
		local now = Rules.ValueSilver(piece(2, level), mods)
		T.near(Rules.ValueSilver(piece(2, level + 1), mods) / now, 1.2, 1e-9, "level " .. level)
	end
end)

T.test("odds percentages always add up to 100", function()
	local mods = Rules.NewMods()
	for grade = 0, 60 do
		for _, safe in ipairs({ false, true }) do
			local pct = Rules.Percentages(Rules.Odds(Rules.Bag(grade, mods), safe))
			local sum = 0
			for o = BREAK, GREAT do
				sum = sum + pct[o]
			end
			T.eq(sum, 100, "grade " .. grade .. (safe and " safe" or ""))
		end
	end
	local blue = Rules.Percentages(Rules.Odds(Rules.Bag(13, mods), false))
	T.eq(blue[BREAK], 20); T.eq(blue[CRACK], 8); T.eq(blue[MISS], 16); T.eq(blue[HIT], 48); T.eq(blue[GREAT], 8)
	local blueSafe = Rules.Percentages(Rules.Odds(Rules.Bag(13, mods), true))
	T.eq(blueSafe[BREAK], 0); T.eq(blueSafe[MISS], 0); T.eq(blueSafe[HIT], 86); T.eq(blueSafe[GREAT], 14)
	-- 1/3 each would round to 33, 33, 33; the remainder rule makes it 100.
	local thirds = Rules.Percentages({ 1 / 3, 1 / 3, 1 / 3, 0, 0 })
	T.eq(thirds[1] + thirds[2] + thirds[3], 100)
end)

T.test("expected value of one more swing matches the playtest script", function()
	-- tools/playtest/ev_per_swing.py prints: 113.1, 105.6, 97.6, 87.2, 75.6, 63.8
	local expected = { [0] = 113.1, 105.6, 97.6, 87.2, 75.6, 63.8 }
	local mods = Rules.NewMods()
	local starts = Rules.QUALITY_START
	for q = 0, 5 do
		local lo, hi = starts[q], q < 5 and starts[q + 1] or starts[q] + 7
		local sum, n = 0, 0
		for level = lo, hi - 1 do
			local odds = Rules.Odds(Rules.Bag(level, mods), false)
			local _, floorLevel = Rules.QualityAt(0, level)
			local function v(l) return Rules.ValueSilver(piece(0, l), mods) end
			local ev = odds[HIT] * v(level + 1) + odds[GREAT] * v(level + 2) + odds[MISS] * v(level)
				+ odds[CRACK] * v(math.max(floorLevel, level - 1))
			sum = sum + ev / v(level)
			n = n + 1
		end
		T.near(sum / n * 100, expected[q], 0.05, "quality " .. q)
	end
end)

T.test("hit, great hit, miss and crack move the level", function()
	local mods = Rules.NewMods()
	local p = piece(0, 5) -- white +5
	local r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), HIT)))
	T.eq(r.outcome, HIT); T.eq(p.level, 6); T.eq(r.gain, 1)
	r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), GREAT)))
	T.eq(r.outcome, GREAT); T.eq(p.level, 8); T.ok(r.qualityUp, "white +6 -> green +8 is a quality-up")
	r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), MISS)))
	T.eq(r.outcome, MISS); T.eq(p.level, 8)
	r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), CRACK)))
	T.eq(r.outcome, CRACK); T.eq(p.level, 8, "a crack never drops below the start of green"); T.eq(r.gain, 0)
	p.level = 10
	r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), CRACK)))
	T.eq(p.level, 9); T.eq(r.gain, -1)
end)

T.test("a break destroys the piece and adds no frenzy", function()
	local mods = Rules.NewMods()
	local p = piece(0, 14, { embers = 6 })
	local r = Rules.Strike(p, mods, scripted(1))
	T.eq(r.outcome, BREAK); T.ok(r.broken); T.eq(p.frenzy, 0); T.eq(p.level, 14)
end)

T.test("seven normal swings fire a Frenzy of three safe swings", function()
	local mods = Rules.NewMods()
	local p = piece(0, 0)
	local bag = Rules.Bag(0, mods)
	for i = 1, 6 do
		local r = Rules.Strike(p, mods, scripted(rollFor(bag, MISS)))
		T.ok(not r.frenzyStarted, "no frenzy after " .. i)
		T.eq(p.embers, i)
	end
	local r = Rules.Strike(p, mods, scripted(rollFor(bag, MISS)))
	T.ok(r.frenzyStarted, "frenzy after 7"); T.eq(p.embers, 0); T.eq(p.frenzy, 3)
	-- Safe swings draw only from Hit and Great hit, and add no embers.
	for i = 1, 3 do
		r = Rules.Strike(p, mods, scripted(1))
		T.ok(r.safe); T.eq(r.outcome, HIT); T.eq(p.embers, 0); T.eq(p.frenzy, 3 - i)
	end
	r = Rules.Strike(p, mods, scripted(rollFor(bag, MISS)))
	T.ok(not r.safe); T.eq(p.embers, 1)
end)

T.test("safe swings can't Miss, Crack or Break (Monte Carlo)", function()
	math.randomseed(7)
	local mods = Rules.NewMods()
	for _, grade in ipairs({ 0, 4, 8, 13, 19, 26, 50 }) do
		local bag = Rules.Bag(grade, mods)
		for _ = 1, 2000 do
			local outcome = Rules.Draw(bag, true, math.random)
			T.ok(outcome == HIT or outcome == GREAT, "safe draw gave " .. outcome)
		end
	end
end)

T.test("draw frequencies match the odds (Monte Carlo)", function()
	math.randomseed(2026)
	local mods = Rules.NewMods()
	for _, grade in ipairs({ 0, 4, 8, 13, 19, 26, 50 }) do
		local bag = Rules.Bag(grade, mods)
		local odds = Rules.Odds(bag, false)
		local seen, n = { 0, 0, 0, 0, 0 }, 40000
		for _ = 1, n do
			local o = Rules.Draw(bag, false, math.random)
			seen[o] = seen[o] + 1
		end
		for o = BREAK, GREAT do
			T.near(seen[o] / n, odds[o], 0.012, "grade " .. grade .. " outcome " .. o)
		end
	end
end)

T.test("stone swings come after Frenzy and add no embers", function()
	local mods = Rules.NewMods()
	local p = piece(3, 0, { frenzy = 1, safe = 2, embers = 3 })
	Rules.Strike(p, mods, scripted(1))
	T.eq(p.frenzy, 0); T.eq(p.safe, 2); T.eq(p.embers, 3)
	Rules.Strike(p, mods, scripted(1))
	T.eq(p.safe, 1); T.eq(p.embers, 3)
	Rules.Strike(p, mods, scripted(1))
	T.eq(p.safe, 0); T.eq(p.embers, 3)
	local r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), MISS)))
	T.ok(not r.safe); T.eq(p.embers, 4)
end)

local function shelf(...)
	local s = {}
	for i, entry in ipairs({ ... }) do
		s[i] = { id = entry[1], rank = entry[2] }
	end
	return s
end

T.test("token tools change the bag and never go below zero", function()
	local mods = Rules.ModsFromShelf(shelf({ "HAMMER", 1 }, { "WEAK_FLUX", 1 }, { "STRONG_FLUX", 2 }, { "ARCANITE", 3 }))
	local gray = Rules.Bag(0, mods)
	T.eq(gray[BREAK], 0); T.eq(gray[CRACK], 0); T.eq(gray[MISS], 4); T.eq(gray[HIT], 14); T.eq(gray[GREAT], 2)
	local orange = Rules.Bag(26, mods)
	T.near(orange[BREAK], 20 * 0.4 / 0.6 - 2, 1e-9, "Arcanite takes 2 from the Break pile")
	T.eq(orange[CRACK], 0); T.eq(orange[MISS], 4); T.eq(orange[HIT], 14); T.eq(orange[GREAT], 2)
	local lava = Rules.Bag(19, Rules.ModsFromShelf(shelf({ "LAVA_CORE", 3 })))
	T.eq(lava[GREAT], 5)
	local enchanted = Rules.Bag(13, Rules.ModsFromShelf(shelf({ "ENCHANTED_THORIUM", 2 })))
	T.eq(enchanted[HIT], 13); T.eq(enchanted[MISS], 3)
end)

T.test("tools that add tokens also lower the Break chance (as in ForgeTax)", function()
	local plain = Rules.Odds(Rules.Bag(13, Rules.NewMods()), false)
	local hammer = Rules.Odds(Rules.Bag(13, Rules.ModsFromShelf(shelf({ "HAMMER", 1 }))), false)
	T.near(plain[BREAK], 0.2, 1e-12)
	T.near(hammer[BREAK], 0.185, 1e-12, "5 Break weight out of 27 instead of 20% (rounded to tickets)")
	local flux = Rules.Odds(Rules.Bag(13, Rules.ModsFromShelf(shelf({ "WEAK_FLUX", 1 }))), false)
	T.ok(flux[BREAK] > plain[BREAK], "removing tokens raises it")
end)

T.test("a rank that doesn't exist for a tool has no effect", function()
	local mods = Rules.ModsFromShelf(shelf({ "STRONG_FLUX", 1 }, { "SULFURON", 3 }))
	T.eq(mods.crack, 0); T.eq(mods.sulfuron, false)
	T.eq(Rules.ToolValue("FIERY_CORE", 4), 5)
	T.eq(Rules.ToolValue("NOT_A_TOOL", 1), nil)
end)

T.test("shelf holes are skipped", function()
	local mods = Rules.ModsFromShelf({ [1] = nil, [2] = { id = "HAMMER", rank = 1 }, [4] = { id = "FIERY_CORE", rank = 2 } })
	T.eq(mods.hit, 2); T.eq(mods.greatGain, 3)
end)

T.test("Fiery Core: great hits give +3", function()
	local mods = Rules.ModsFromShelf(shelf({ "FIERY_CORE", 2 }))
	local p = piece(0, 0)
	Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), GREAT)))
	T.eq(p.level, 3)
end)

T.test("Dark Iron Bar: the next Hit after a Miss gives +2", function()
	local mods = Rules.ModsFromShelf(shelf({ "DARK_IRON", 2 }))
	local p = piece(0, 0)
	Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), MISS)))
	T.ok(p.afterMiss)
	Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), GREAT)))
	T.eq(p.level, 2); T.ok(p.afterMiss, "a great hit does not use up the bonus")
	local r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), HIT)))
	T.eq(p.level, 4); T.ok(r.darkIron); T.ok(not p.afterMiss)
	Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), HIT)))
	T.eq(p.level, 5)
	-- Without the tool a Hit after a Miss is a plain +1.
	local plain = piece(0, 0, { afterMiss = true })
	Rules.Strike(plain, Rules.NewMods(), scripted(rollFor(bagOf(plain), HIT)))
	T.eq(plain.level, 1)
end)

T.test("Sulfuron Ingot turns the first Break of each piece into a Crack", function()
	local mods = Rules.ModsFromShelf(shelf({ "SULFURON", 4 }))
	local p = piece(3, 3)
	local r = Rules.Strike(p, mods, scripted(1))
	T.eq(r.drawn, BREAK); T.eq(r.outcome, CRACK); T.ok(r.sulfuron); T.ok(not r.broken); T.eq(p.level, 2)
	r = Rules.Strike(p, mods, scripted(1))
	T.eq(r.outcome, BREAK); T.ok(r.broken)
end)

T.test("Blood of the Mountain and Elemental Flux change Frenzy", function()
	local mods = Rules.ModsFromShelf(shelf({ "BLOOD", 3 }, { "ELEMENTAL_FLUX", 3 }))
	T.eq(mods.frenzySwings, 5); T.eq(mods.frenzyEvery, 5)
	local p = piece(0, 0)
	for _ = 1, 4 do
		Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), MISS)))
	end
	local r = Rules.Strike(p, mods, scripted(rollFor(bagOf(p, mods), MISS)))
	T.ok(r.frenzyStarted); T.eq(p.frenzy, 5)
	local legendary = Rules.ModsFromShelf(shelf({ "BLOOD", 4 }, { "ELEMENTAL_FLUX", 4 }))
	T.eq(legendary.frenzySwings, 7); T.eq(legendary.frenzyEvery, 4)
end)

T.test("value tools: weapons, armour, orange and purple-plus", function()
	local weapon = piece(0, 0, { kind = "weapon" })
	T.eq(Rules.ValueCopper(weapon, Rules.ModsFromShelf(shelf({ "HEAVY_STONE", 1 }))), 2500)
	T.eq(Rules.ValueCopper(weapon, Rules.ModsFromShelf(shelf({ "THORIUM_BAR", 2 }))), 2000, "armour tool doesn't touch weapons")
	local armor = piece(0, 0)
	T.eq(Rules.ValueCopper(armor, Rules.ModsFromShelf(shelf({ "THORIUM_BAR", 2 }))), 2400)
	local orange = piece(5, 0)
	T.eq(Rules.ValueCopper(orange, Rules.NewMods()), 13000)
	T.eq(Rules.ValueCopper(orange, Rules.ModsFromShelf(shelf({ "RIGHTEOUS_ORB", 3 }))), 18200)
	T.eq(Rules.ValueCopper(orange, Rules.ModsFromShelf(shelf({ "RIGHTEOUS_ORB", 4 }))), 24050)
	T.eq(Rules.ValueCopper(piece(4, 0), Rules.ModsFromShelf(shelf({ "RIGHTEOUS_ORB", 4 }))), 9200, "purple gets no orange bonus")
	local purple = piece(4, 0)
	T.eq(Rules.ValueCopper(purple, Rules.ModsFromShelf(shelf({ "ELEMENTAL_STONE", 3 }))), 11040)
	T.eq(Rules.ValueCopper(piece(3, 0), Rules.ModsFromShelf(shelf({ "ELEMENTAL_STONE", 3 }))), 6400, "blue gets no purple bonus")
	T.eq(Rules.ValueCopper(armor, Rules.NewMods(), 0.05), 2100, "trophy bonus")
end)

-- Best stop-or-swing strategy (Frenzy, embers and Sulfuron included) over a horizon of swings,
-- as a ratio to selling at once. 1.0 means selling at once is best.
local function bestStrategy(startLevel, mods, horizon)
	local memo = {}
	local function value(level)
		return Rules.ValueSilver({ startQuality = 0, level = level, itemLevel = 60 }, mods)
	end
	local function V(level, embers, frenzy, used, h)
		local key = level .. ":" .. embers .. ":" .. frenzy .. ":" .. tostring(used) .. ":" .. h
		if memo[key] then
			return memo[key]
		end
		local sell = value(level)
		if h == 0 then
			memo[key] = sell
			return sell
		end
		local _, floorLevel = Rules.QualityAt(0, level)
		local odds = Rules.Odds(Rules.Bag(level, mods), frenzy > 0)
		local ev = 0
		for o = BREAK, GREAT do
			if odds[o] > 0 then
				local outcome, nowUsed = o, used
				if o == BREAK and mods.sulfuron and not used then
					outcome, nowUsed = CRACK, true
				end
				if outcome ~= BREAK then
					local gain = ({ [CRACK] = -1, [MISS] = 0, [HIT] = 1, [GREAT] = mods.greatGain })[outcome]
					local e, f = embers, frenzy
					if f > 0 then f = f - 1 else e = e + 1 end
					if f == 0 and e >= mods.frenzyEvery then e, f = 0, mods.frenzySwings end
					ev = ev + odds[o] * V(math.max(floorLevel, level + gain), e, f, nowUsed, h - 1)
				end
			end
		end
		local best = math.max(sell, ev)
		memo[key] = best
		return best
	end
	return V(startLevel, 0, 0, false, horizon) / value(startLevel)
end

T.test("without tools, selling at once is best from blue up (Frenzy included)", function()
	local mods = Rules.NewMods()
	for _, level in ipairs({ 13, 19, 26 }) do
		T.near(bestStrategy(level, mods, 30), 1, 1e-9, "start level " .. level)
	end
	T.ok(bestStrategy(0, mods, 30) > 1.5, "gray is free money")
end)

T.test("strong tools make purple, then orange, worth forging without making them safe", function()
	local epic = Rules.ModsFromShelf(shelf({ "HAMMER", 3 }, { "FIERY_CORE", 3 }, { "LAVA_CORE", 3 }, { "ARCANITE", 3 }))
	T.ok(bestStrategy(19, epic, 30) > 1, "epic tools make purple worth forging")
	T.near(bestStrategy(26, epic, 30), 1, 1e-9, "but not orange")
	local legendary = Rules.ModsFromShelf(shelf({ "SULFURON", 4 }, { "FIERY_CORE", 4 }, { "LAVA_CORE", 4 }, { "ARCANITE", 4 }))
	T.ok(bestStrategy(26, legendary, 30) > 1, "legendary tools with the Sulfuron Ingot make orange worth forging")
	-- No tool set removes every Break token from purple or orange.
	local mostBreakCut = 0
	for _, id in ipairs(Data.TOOL_ORDER) do
		local def = Data.TOOLS[id]
		if def.effect == "break" then
			mostBreakCut = mostBreakCut + def.values[4]
		end
	end
	T.ok(Rules.Bag(19)[BREAK] - mostBreakCut > 0, "purple keeps Break tokens")
	T.ok(Rules.Bag(26)[BREAK] - mostBreakCut > 0, "orange keeps Break tokens")
end)
