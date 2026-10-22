-- luacheck config for Forgeborn (WoW Forever, Lua 5.1).
std = "lua51"
max_line_length = false
exclude_files = { "tests/fixtures/*", "docs/**" }

-- Globals the addon defines.
globals = {
	"ForgebornCharDB",
	"SLASH_FORGEBORN1", "SLASH_FORGEBORN2",
	"Forgeborn_OnCompartmentClick", "Forgeborn_OnCompartmentEnter", "Forgeborn_OnCompartmentLeave",
	-- Blizzard tables the addon adds entries to.
	"SlashCmdList", "StaticPopupDialogs", "UIPanelWindows", "UISpecialFrames",
}

-- Blizzard API the addon reads. tools/apicheck/check_api.py checks each one against the Forever UI source.
read_globals = {
	"BACKPACK_CONTAINER", "BreakUpLargeNumbers", "C_Container", "C_DateAndTime", "C_Item", "C_Timer",
	"CreateFrame", "DEFAULT_CHAT_FRAME", "Enum", "FACTION_BAR_COLORS", "ForgebornFrame", "GameTooltip",
	"GetCursorPosition", "GetLocale", "GetLootSlotLink", "GetLootSlotType", "GetMaxLevelForPlayerExpansion",
	"GetMoneyString", "GetNumLootItems", "GetServerTime", "GetTime", "HideUIPanel", "InCombatLockdown", "Item",
	"ItemLocation", "MenuUtil", "NO", "NUM_BAG_SLOTS", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab",
	"PanelTemplates_TabResize", "PlaySound", "SOUNDKIT", "SetItemButtonCount", "SetItemButtonDesaturated",
	"SetItemButtonQuality", "SetItemButtonTexture", "Settings", "ShowUIPanel", "StaticPopup_Show", "UIErrorsFrame",
	"UIParent", "UnitFactionGroup", "UnitLevel", "UnitRace", "YES", "strtrim",
}

files["tests"] = { ignore = { "1..", "212" } }
files["tools"] = { ignore = { "1.." } }
