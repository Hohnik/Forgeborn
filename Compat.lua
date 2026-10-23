-- Forgeborn: the few differences between WoW Forever and retail WoW. The retail test build
-- (branch retail-test) runs exactly the code that ships for Forever; only these answers change.
local _, ns = ...

local Data = ns.Data
local Compat = {}
ns.Compat = Compat

-- Forever sets WOW_PROJECT_ID to WOW_PROJECT_CAMELOT (18); retail to WOW_PROJECT_MAINLINE (1).
Compat.isForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
Compat.isRetail = not Compat.isForever and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Forever's own progress bar template (used by its Reputation window) doesn't exist in retail.
Compat.hasColoredProgressBar = Compat.isForever

-- The item levels a crafting order asks for, near the character.
-- In Forever an item's level follows the character's level (the 2004 world), so orders use the level.
-- In retail item levels run far above character levels, so the test build uses the average equipped item level.
function Compat.OrderItemLevels(playerLevel, maxPlayerLevel)
	if Compat.isRetail then
		local _, equipped = GetAverageItemLevel()
		local center = math.floor((tonumber(equipped) or 1) + 0.5)
		return math.max(1, center - Data.ILVL_RANGE_RETAIL), center + Data.ILVL_RANGE_RETAIL
	end
	local high = nil
	if playerLevel < maxPlayerLevel then
		high = playerLevel + Data.ILVL_RANGE
	end
	return math.max(1, playerLevel - Data.ILVL_RANGE), high
end
