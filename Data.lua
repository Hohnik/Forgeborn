-- Forgeborn: static game data. No WoW API calls, so the tests can load it in plain Lua.
local _, ns = ...

local Data = {}
ns.Data = Data

Data.MAX_QUALITY = 5 -- orange (Enum.ItemQuality.Legendary)

-- Levels needed to leave each quality: gray, white, green, blue, purple. Orange has no cap.
Data.LEVELS_TO_NEXT = { [0] = 4, [1] = 4, [2] = 5, [3] = 6, [4] = 7 }

-- Value factor of the quality an item dropped at (gray .. orange).
Data.VALUE_FACTOR = { [0] = 1, [1] = 1.5, [2] = 2.2, [3] = 3.2, [4] = 4.6, [5] = 6.5 }

-- Every level multiplies the value: a Hit x1.2, a Great hit (+2) x1.44, a Crack /1.2.
Data.VALUE_PER_LEVEL = 1.2

-- Strike outcomes, in odds-bar order.
Data.BREAK, Data.CRACK, Data.MISS, Data.HIT, Data.GREAT = 1, 2, 3, 4, 5
Data.OUTCOMES = { 1, 2, 3, 4, 5 }

-- Rules v0.4: the odds change with every level, like ForgeTax's anvil.
-- The grade is the level counted from the start of gray, so a blue drop at +0 is grade 13 (see Rules.Grade).
--
-- The deck holds the other four outcomes, in outcome order: Break (set by the curve), Crack (-1), Miss (0),
-- Hit (+1), Great hit (+2). Tools add or remove tokens here.
Data.DECK = { 0, 2, 4, 12, 2 }

-- Break chance in percent by grade, on the plain deck. Between two points it rises evenly; after the last point
-- it stays. The Break pile gets the weight that gives this chance on the plain deck, so tools that add tokens to
-- the other piles also lower the Break chance.
Data.BREAK_CURVE = {
	{ 0, 0 }, -- gray +0
	{ 2, 2 },
	{ 4, 6 }, -- white
	{ 8, 12 }, -- green
	{ 13, 20 }, -- blue
	{ 19, 30 }, -- purple
	{ 26, 40 }, -- orange
	{ 36, 55 },
	{ 50, 70 }, -- and up
}

-- Every swing draws one ticket out of this many (the deck scaled to whole tickets).
Data.TICKETS = 1000

Data.EMBERS_FOR_FRENZY = 7
Data.FRENZY_SWINGS = 3
Data.WORKBENCH_SLOTS = 4
Data.SHELF_SLOTS = 4
Data.DISPLAY_BASE_SLOTS = 3

-- Tool rarity ranks. Each rank shows in a WoW quality colour.
Data.RANK_COMMON, Data.RANK_RARE, Data.RANK_EPIC, Data.RANK_LEGENDARY = 1, 2, 3, 4
Data.RANK_QUALITY = { [1] = 1, [2] = 3, [3] = 4, [4] = 5 }
-- Gold (copper) paid out when a duplicate arrives for a tool that is already at its highest rank.
Data.RANK_SALVAGE = { [1] = 10000, [2] = 50000, [3] = 250000, [4] = 1000000 }

-- Tools. "values" holds the effect per rank; ranks below "base" do not exist for that tool.
-- Effect kinds:
--   hit, great, crack, miss, break : token changes (crack/miss/break are removed, so the values are positive)
--   greatGain        : levels a Great hit gives
--   afterMissHit     : levels the next Hit gives after a Miss
--   frenzySwings     : safe swings per Frenzy
--   frenzyEvery      : normal swings needed for a Frenzy
--   weaponValue, armorValue, highValue, orangeValue : value bonus (0.25 = +25%); highValue applies to purple
--                      and orange, orangeValue to orange
--   sulfuron         : the first Break of each item becomes a Crack
Data.TOOLS = {
	HAMMER = { item = 5956, icon = "Interface\\Icons\\INV_Hammer_20", base = 1, effect = "hit", values = { 2, 3, 4, 5 } },
	WEAK_FLUX = { item = 2880, icon = "Interface\\Icons\\INV_Misc_Ammo_Gunpowder_02", base = 1, effect = "crack", values = { 1, 2, 3, 4 } },
	HEAVY_STONE = { item = 2871, icon = "Interface\\Icons\\INV_Stone_SharpeningStone_03", base = 1, effect = "weaponValue", values = { 0.25, 0.35, 0.5, 0.75 } },
	STRONG_FLUX = { item = 3466, icon = "Interface\\Icons\\INV_Misc_Ammo_Gunpowder_01", base = 2, effect = "crack", values = { nil, 2, 3, 4 } },
	THORIUM_BAR = { item = 12359, icon = "Interface\\Icons\\INV_Ingot_07", base = 2, effect = "armorValue", values = { nil, 0.2, 0.3, 0.45 } },
	FIERY_CORE = { item = 17010, icon = "Interface\\Icons\\Spell_Fire_FlameBolt", base = 2, effect = "greatGain", values = { nil, 3, 4, 5 } },
	LAVA_CORE = { item = 17011, icon = "Interface\\Icons\\Spell_Nature_Earthquake", base = 2, effect = "great", values = { nil, 2, 3, 4 } },
	DARK_IRON = { item = 11371, icon = "Interface\\Icons\\INV_Ingot_Mithril", base = 2, effect = "afterMissHit", values = { nil, 2, 3, 4 } },
	ARCANITE = { item = 12360, icon = "Interface\\Icons\\INV_Misc_StoneTablet_05", base = 3, effect = "break", values = { nil, nil, 2, 3 } },
	BLOOD = { item = 11382, icon = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_03", base = 3, effect = "frenzySwings", values = { nil, nil, 5, 7 } },
	ELEMENTAL_FLUX = { item = 18567, icon = "Interface\\Icons\\Spell_Frost_FireResistanceTotem", base = 3, effect = "frenzyEvery", values = { nil, nil, 5, 4 } },
	RIGHTEOUS_ORB = { item = 12811, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03", base = 3, effect = "orangeValue", values = { nil, nil, 0.4, 0.85 } },
	SULFURON = { item = 17203, icon = "Interface\\Icons\\Spell_Fire_SealOfFire", base = 4, effect = "sulfuron", values = { nil, nil, nil, 1 } },
	-- Thorium Brotherhood wares, not in lockboxes.
	ENCHANTED_THORIUM = { item = 12655, icon = "Interface\\Icons\\INV_Ingot_Eternium", base = 2, effect = "hitMiss", values = { nil, 1, 2, 3 }, exclusive = true },
	ELEMENTAL_STONE = { item = 18262, icon = "Interface\\Icons\\INV_Stone_02", base = 3, effect = "highValue", values = { nil, nil, 0.2, 0.35 }, exclusive = true },
}

-- Display and lockbox order.
Data.TOOL_ORDER = {
	"HAMMER", "WEAK_FLUX", "HEAVY_STONE", "STRONG_FLUX", "THORIUM_BAR", "FIERY_CORE", "LAVA_CORE",
	"DARK_IRON", "ARCANITE", "BLOOD", "ELEMENTAL_FLUX", "RIGHTEOUS_ORB", "SULFURON", "ENCHANTED_THORIUM", "ELEMENTAL_STONE",
}

-- One-use items. "safe" = swings that can't Miss, Crack or Break.
Data.CONSUMABLES = {
	COARSE_STONE = { item = 2863, icon = "Interface\\Icons\\INV_Stone_SharpeningStone_02", safe = 1, price = 20000 },
	DENSE_STONE = { item = 12404, icon = "Interface\\Icons\\INV_Stone_SharpeningStone_05", safe = 3, price = 50000, needs = { faction = "CITY", rank = 2 } },
}
Data.CONSUMABLE_ORDER = { "COARSE_STONE", "DENSE_STONE" }

-- Lockboxes. Prices in copper. Each roll walks the table top to bottom; chances are out of 1000.
--   tool    : a random tool of that base rank from the lockbox pool
--   item    : a one-use item
--   purse   : addon gold between min and max copper
Data.LOCKBOXES = {
	BRONZE = {
		item = 4632, icon = "Interface\\Icons\\INV_Misc_OrnateBox", price = 50000, quality = 2,
		table = {
			{ chance = 100, kind = "tool", rank = 2 },
			{ chance = 250, kind = "tool", rank = 1 },
			{ chance = 400, kind = "item", id = "COARSE_STONE" },
			{ chance = 100, kind = "item", id = "DENSE_STONE" },
			{ chance = 150, kind = "purse", min = 10000, max = 40000 },
		},
	},
	IRON = {
		item = 4634, icon = "Interface\\Icons\\INV_Misc_OrnateBox", price = 200000, quality = 3,
		needs = { faction = "STEAMWHEEDLE", rank = 3 },
		table = {
			{ chance = 30, kind = "tool", rank = 3 },
			{ chance = 300, kind = "tool", rank = 2 },
			{ chance = 400, kind = "tool", rank = 1 },
			{ chance = 120, kind = "item", id = "DENSE_STONE" },
			{ chance = 150, kind = "purse", min = 50000, max = 150000 },
		},
	},
	THORIUM = {
		item = 5759, icon = "Interface\\Icons\\INV_Misc_OrnateBox", price = 1000000, quality = 4,
		needs = { faction = "STEAMWHEEDLE", rank = 4 },
		table = {
			{ chance = 10, kind = "tool", rank = 4 },
			{ chance = 150, kind = "tool", rank = 3 },
			{ chance = 840, kind = "tool", rank = 2 },
		},
	},
}
Data.LOCKBOX_ORDER = { "BRONZE", "IRON", "THORIUM" }

-- Reputation, like WoW: Neutral, Friendly, Honored, Revered, Exalted (ranks 1 to 5).
-- Values are totals from the start of Neutral.
Data.REP_THRESHOLDS = { 0, 3000, 9000, 21000, 42000 }
Data.REP_MAX = 42999
Data.RANK_NEUTRAL, Data.RANK_FRIENDLY, Data.RANK_HONORED, Data.RANK_REVERED, Data.RANK_EXALTED = 1, 2, 3, 4, 5
-- FACTION_STANDING_LABEL4 .. 8 are the game's own names for these ranks.
Data.REP_STANDING_ID = { 4, 5, 6, 7, 8 }

Data.FACTION_ORDER = { "THORIUM", "STEAMWHEEDLE", "CITY", "ARGENT" }

-- Wares per faction and rank. kind: "tool" (buy a tool), "lockbox", "consumable", "perk" (no purchase).
Data.FACTIONS = {
	THORIUM = {
		wares = {
			{ rank = 3, kind = "tool", id = "ENCHANTED_THORIUM", price = 400000 },
			{ rank = 4, kind = "tool", id = "ELEMENTAL_STONE", price = 1500000 },
			{ rank = 5, kind = "tool", id = "SULFURON", price = 6000000 },
		},
	},
	STEAMWHEEDLE = {
		wares = {
			{ rank = 3, kind = "lockbox", id = "IRON" },
			{ rank = 4, kind = "lockbox", id = "THORIUM" },
			{ rank = 5, kind = "perk", id = "LOCKBOX_DISCOUNT" },
		},
	},
	CITY = {
		wares = {
			{ rank = 2, kind = "consumable", id = "DENSE_STONE" },
			{ rank = 3, kind = "perk", id = "ORDER_SLOT" },
			{ rank = 4, kind = "perk", id = "SUPPLY_DISCOUNT_1" },
			{ rank = 5, kind = "perk", id = "SUPPLY_DISCOUNT_2" },
		},
	},
	ARGENT = {
		wares = {
			{ rank = 2, kind = "perk", id = "DISPLAY_SLOT_1" },
			{ rank = 3, kind = "perk", id = "DISPLAY_SLOT_2" },
			{ rank = 4, kind = "perk", id = "TROPHY_BONUS_1" },
			{ rank = 5, kind = "perk", id = "TROPHY_BONUS_2" },
		},
	},
}

Data.LOCKBOX_DISCOUNT = 0.2 -- Steamwheedle Exalted
Data.SUPPLY_DISCOUNT = { [4] = 0.25, [5] = 0.5 } -- capital city Revered, Exalted

-- Display case bonus to sale value per trophy, by the trophy's final quality (0.0025 = +0.25%).
Data.TROPHY_BONUS = { [0] = 0, [1] = 0, [2] = 0.0025, [3] = 0.005, [4] = 0.0075, [5] = 0.01 }
Data.TROPHY_MULTIPLIER = { [4] = 1.5, [5] = 2 } -- Argent Dawn Revered, Exalted

-- Crafting orders.
Data.DAILY_SLOTS = 3
Data.DAILY_SLOTS_BONUS = 1 -- capital city Honored
Data.WEEKLY_COUNT = 3
Data.DAILY_REP = 500
Data.WEEKLY_REP = 2000
Data.DAILY_GOLD_FACTOR = 2
Data.WEEKLY_GOLD_FACTOR = 4
Data.STEP_BONUS = 0.5 -- per quality step above the ask
Data.REJECT_SHARE = 0.25
Data.ILVL_RANGE = 5
Data.ILVL_RANGE_RETAIL = 10 -- retail test build: around the average equipped item level
Data.PLATE_LEVEL = 40

-- Equipment groups an order can ask for. Armour slots listed in "typed" can also carry an armour type.
Data.ARMOR_SLOTS = {
	HEAD = { "INVTYPE_HEAD" },
	SHOULDER = { "INVTYPE_SHOULDER" },
	CHEST = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
	WAIST = { "INVTYPE_WAIST" },
	LEGS = { "INVTYPE_LEGS" },
	FEET = { "INVTYPE_FEET" },
	WRIST = { "INVTYPE_WRIST" },
	HANDS = { "INVTYPE_HAND" },
	BACK = { "INVTYPE_CLOAK" },
	SHIELD = { "INVTYPE_SHIELD" },
	OFFHAND = { "INVTYPE_HOLDABLE" },
}
Data.TYPED_ARMOR_SLOTS = { "HEAD", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HANDS" }
Data.ALL_ARMOR_SLOTS = { "HEAD", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HANDS", "BACK", "SHIELD", "OFFHAND" }
Data.WEAPON_GROUPS = {
	ONEHAND = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND" },
	TWOHAND = { "INVTYPE_2HWEAPON" },
	RANGED = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" },
}
Data.WEAPON_GROUP_ORDER = { "ONEHAND", "TWOHAND", "RANGED" }
Data.WEAPON_GROUP_WEIGHTS = { ONEHAND = 45, TWOHAND = 35, RANGED = 20 }

-- Armour types (Enum.ItemArmorSubclass).
Data.ARMOR_CLOTH, Data.ARMOR_LEATHER, Data.ARMOR_MAIL, Data.ARMOR_PLATE = 1, 2, 3, 4

-- Item classes (Enum.ItemClass) and the weapon subclasses that are not forged.
Data.CLASS_WEAPON, Data.CLASS_ARMOR = 2, 4
Data.WEAPON_SUBCLASS_FISHING_POLE = 20

-- Minimum quality an order asks for: weights for white, green, blue, purple.
Data.ASK_WEIGHTS = {
	default = { [1] = 15, [2] = 45, [3] = 30, [4] = 10 },
	STEAMWHEEDLE = { [1] = 0, [2] = 30, [3] = 50, [4] = 20 },
	CITY = { [1] = 30, [2] = 50, [3] = 20, [4] = 0 },
	weekly = { [1] = 20, [2] = 50, [3] = 30, [4] = 0 },
}

-- Capital city by race file name, then by player faction.
Data.CITY_BY_RACE = {
	Human = "STORMWIND", NightElf = "STORMWIND", Dwarf = "IRONFORGE", Gnome = "IRONFORGE",
	Orc = "ORGRIMMAR", Troll = "ORGRIMMAR", Tauren = "ORGRIMMAR", Scourge = "UNDERCITY",
}
Data.CITY_BY_FACTION = { Alliance = "STORMWIND", Horde = "ORGRIMMAR" }

-- Records and the anvil keep these per item.
Data.SECONDS_PER_DAY = 86400
Data.SECONDS_PER_WEEK = 604800
Data.EXPECTED_DROP_SECONDS = 300
Data.ROLL_WON_SECONDS = 600
