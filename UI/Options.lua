-- Forgeborn: a page in the game's Settings panel (Options > AddOns > Forgeborn).
local _, ns = ...

local L = ns.L
local Options = {}
ns.Options = Options

-- Called once the saved data is loaded. The values are read from ns.db each time, so a reset keeps working.
function Options.Register()
	if Options.category or not Settings or not Settings.RegisterVerticalLayoutCategory then
		return
	end
	local category = Settings.RegisterVerticalLayoutCategory(L.TITLE)
	local function checkbox(variable, key, name, tooltip)
		local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, name, true,
			function()
				return ns.db.settings[key]
			end,
			function(value)
				ns.db.settings[key] = value and true or false
			end)
		Settings.CreateCheckbox(category, setting, tooltip)
	end
	checkbox("FORGEBORN_SOUND", "sound", L.SETTING_SOUND, L.SETTING_SOUND_TIP)
	checkbox("FORGEBORN_ANNOUNCE", "announce", L.SETTING_ANNOUNCE, L.SETTING_ANNOUNCE_TIP)
	Settings.RegisterAddOnCategory(category)
	Options.category = category
end

function Options.Open()
	if not Options.category then
		return
	end
	if InCombatLockdown() then
		ns.Error("ERR_SETTINGS_COMBAT")
		return
	end
	Settings.OpenToCategory(Options.category:GetID())
end
