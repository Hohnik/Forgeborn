-- Window tests: the player's clicks, drags, menus and popups, run in the strict mock client in English and German.
local T = ...
local Mock = dofile("tests/wowmock.lua")

local ITEMS = {
	BOOTS = { id = 1001, name = "Tattered Boots", quality = 0, ilvl = 20, equipLoc = "INVTYPE_FEET", classID = 4, subclassID = 2 },
	SWORD = { id = 1002, name = "Rusty Sword", quality = 1, ilvl = 18, equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 },
	SHIRT = { id = 1003, name = "Chain Shirt of the Bear", quality = 2, ilvl = 22, equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 3 },
	HELM = { id = 1004, name = "Blue Plate Helm", quality = 3, ilvl = 21, equipLoc = "INVTYPE_HEAD", classID = 4, subclassID = 4 },
}

local function newClient(options)
	local client = Mock.New(options)
	for _, def in pairs(ITEMS) do
		local copy = {}
		for k, v in pairs(def) do
			copy[k] = v
		end
		client:DefineItem(copy)
	end
	client:LoadAddon()
	return client
end

local function scripted(...)
	local values, i = { ... }, 0
	return function(n)
		i = i + 1
		local v = assert(values[i], "scripted random ran out")
		assert(v >= 1 and v <= n, "scripted value " .. v .. " outside 1.." .. n)
		return v
	end
end

local function loot(client, item)
	client:OpenLoot({ item.id })
	client:TakeLoot()
end

-- Hovers every slot and part of the window that has a tooltip; none may fail.
local function hoverAll(client, parts)
	local list = { parts.anvil.slot, parts.pending }
	for _, group in ipairs({ parts.bench, parts.shelf, parts.supplies, parts.display }) do
		for _, slot in ipairs(group) do
			table.insert(list, slot)
		end
	end
	for _, card in ipairs(client.ns.UI.cards) do
		table.insert(list, card.slot)
	end
	for _, region in ipairs(list) do
		client:RunScript(region, "OnEnter")
		client:RunScript(region, "OnLeave")
	end
	client:RunScript(parts.frame.PortraitContainer, "OnEnter")
	client:RunScript(parts.odds.bar, "OnEnter")
end

local function scenario(locale, project)
	local prefix = "[" .. locale .. (project and (", " .. project) or "") .. "] "
	local client, ns, env, L, parts

	T.test(prefix .. "the window opens like a native panel and shows an empty anvil", function()
		client = newClient({ locale = locale, project = project })
		client:Login(nil)
		ns, env, L = client.ns, client.env, client.ns.L
		env.SlashCmdList.FORGEBORN("")
		parts = ns.UI.parts
		local frame = env.ForgebornFrame
		T.ok(frame and frame:IsShown(), "window shown")
		T.eq(client.panelShown, frame, "opened with ShowUIPanel")
		T.eq(env.UIPanelWindows.ForgebornFrame.area, "left")
		T.eq(frame.TitleContainer.TitleText:GetText(), "Forgeborn")
		T.eq(parts.anvil.name:GetText(), L.ANVIL_EMPTY)
		T.ok(not parts.anvil.forge:IsEnabled() and not parts.anvil.sell:IsEnabled(), "buttons off without an item")
		T.ok(parts.odds.empty:IsShown())
		T.eq(#ns.UI.cards, 5)
		T.ok(ns.UI.cards[1].ask:GetText() ~= nil, "the first daily order shows")
		T.ok(ns.UI.cards[2].empty:IsShown(), "empty daily slots say when the next order comes")
		hoverAll(client, parts)
	end)

	T.test(prefix .. "click a Workbench item to put it on the anvil; the odds bar fills", function()
		loot(client, ITEMS.BOOTS)
		loot(client, ITEMS.HELM)
		T.eq(parts.bench[1].mockIcon, 134400)
		T.eq(parts.bench[2].mockQuality, 3)
		parts.bench[1]:Click("LeftButton")
		T.eq(ns.db.anvil.name, "Tattered Boots")
		T.ok(parts.anvil.forge:IsEnabled() and parts.anvil.sell:IsEnabled())
		T.ok(parts.anvil.name:GetText():find("Tattered Boots +0", 1, true))
		-- Gray: no Break, 5% crack, 10% miss, 70% hit, 15% great.
		T.ok(not parts.odds.segments[1]:IsShown(), "no Break section on gray")
		T.eq(parts.odds.percents[4]:GetText(), "70%")
		T.eq(parts.odds.percents[5]:GetText(), "15%")
		T.eq(parts.odds.labels[5]:GetText(), "+2")
		T.eq(parts.anvil.embers:GetText(), string.format(L.EMBERS, 0, 7))
		hoverAll(client, parts)
	end)

	T.test(prefix .. "Forge strikes, shows the result, fills embers and fires Frenzy", function()
		-- 6 hits, then a 7th normal swing (miss) fires Frenzy.
		ns.Forge.Random = scripted(4, 4, 4, 5, 5, 5, 3)
		for _ = 1, 7 do
			parts.anvil.forge:Click()
		end
		local piece = ns.db.anvil
		T.eq(piece.level, 6)
		T.eq(piece.frenzy, 3)
		T.ok(parts.anvil.status:GetText():find(L.STATUS_FRENZY_STARTS, 1, true), "Frenzy shown")
		T.eq(parts.anvil.embers:GetText(), string.format(L.FRENZY_LEFT, 3))
		-- During Frenzy only the hits are on the bar.
		T.ok(not parts.odds.segments[2]:IsShown() and not parts.odds.segments[3]:IsShown())
		ns.Forge.Random = scripted(1)
		parts.anvil.forge:Click()
		T.ok(parts.anvil.status:GetText():find(L.STATUS_SAFE_PREFIX, 1, true))
		T.ok(#client.sounds > 0, "sounds played")
		hoverAll(client, parts)
	end)

	T.test(prefix .. "a quality-up glows and a break empties the anvil", function()
		local piece = ns.db.anvil
		piece.frenzy, piece.level = 0, 7
		ns.Forge.Random = scripted(5) -- white bag: 5 is a Hit -> +8 = green
		parts.anvil.forge:Click()
		T.eq(ns.Forge.Quality(piece), 2)
		T.ok(parts.anvil.status:GetText():find(ns.QualityName(2), 1, true))
		local played = client.animationsPlayed or 0
		ns.Forge.Random = scripted(1) -- green bag: Break
		parts.anvil.forge:Click()
		T.eq(ns.db.anvil, nil)
		T.ok((client.animationsPlayed or 0) > played, "the slot flashed")
		T.ok(client:LastChat():find("Tattered Boots", 1, true), "break reported in chat")
		T.eq(parts.anvil.name:GetText(), L.ANVIL_EMPTY)
	end)

	T.test(prefix .. "Sell pays addon gold and the footer shows it", function()
		parts.bench[2]:Click("LeftButton")
		T.eq(ns.db.anvil.name, "Blue Plate Helm")
		local value = ns.Forge.Value(ns.db.anvil)
		parts.anvil.sell:Click()
		T.eq(ns.db.gold, value)
		T.eq(parts.gold:GetText(), env.GetMoneyString(value, true))
		T.ok(parts.anvil.status:GetText():find("Blue Plate Helm", 1, true))
	end)

	T.test(prefix .. "drag and drop: anvil, Workbench, Display case", function()
		loot(client, ITEMS.SWORD)
		loot(client, ITEMS.SHIRT)
		local swordSlot = ns.db.workbench[1].name == "Rusty Sword" and 1 or 2
		local shirtSlot = 3 - swordSlot
		client:Drag(parts.bench[swordSlot], parts.anvil.slot)
		T.eq(ns.db.anvil.name, "Rusty Sword")
		-- Anvil onto the shirt's slot swaps them.
		client:Drag(parts.anvil.slot, parts.bench[shirtSlot])
		T.eq(ns.db.anvil.name, "Chain Shirt of the Bear")
		T.eq(ns.db.workbench[shirtSlot].name, "Rusty Sword")
		-- Workbench to Workbench swaps slots.
		client:Drag(parts.bench[shirtSlot], parts.bench[4])
		T.eq(ns.db.workbench[4].name, "Rusty Sword")
		-- Anvil to the Display case.
		client:Drag(parts.anvil.slot, parts.display[2])
		T.eq(#ns.db.display, 1)
		T.eq(ns.db.display[1].name, "Chain Shirt of the Bear")
		T.eq(parts.display[1].mockQuality, 2)
		T.ok(parts.trophyBonus:GetText() ~= "", "trophy bonus shown")
		-- Dropping on nothing does nothing.
		client:Drag(parts.bench[4], nil)
		T.eq(ns.db.workbench[4].name, "Rusty Sword")
		-- If the client also sends a click when the drag ends, it doesn't put the item on the anvil.
		client:DragWithClick(parts.bench[4], nil)
		T.eq(ns.db.workbench[4].name, "Rusty Sword")
		T.eq(ns.db.anvil, nil)
		hoverAll(client, parts)
	end)

	T.test(prefix .. "menus: throw away a Workbench item, remove a trophy", function()
		parts.bench[4]:Click("RightButton")
		T.ok(client.menu and #client.menu.entries == 3)
		client:ClickMenu(L.MENU_DISCARD)
		local popup = client:Popup()
		T.ok(popup and popup.text:find("Rusty Sword", 1, true), "asks first")
		client:AcceptPopup()
		T.eq(ns.db.workbench[4], nil)
		parts.display[1]:Click("RightButton")
		client:ClickMenu(L.MENU_REMOVE_TROPHY)
		client:AcceptPopup()
		T.eq(#ns.db.display, 0)
	end)

	T.test(prefix .. "orders: drag onto the card, Send pays; Reject asks and costs reputation", function()
		ns.db.orders.daily = {}
		local order = ns.Orders.Generate(false, "ARGENT")
		order.group, order.armorType, order.minQuality, order.ilvlMin, order.ilvlMax = "CHEST", nil, 2, 15, 25
		table.insert(ns.db.orders.daily, order)
		ns.Changed()
		loot(client, ITEMS.SHIRT)
		local slot
		for i = 1, 4 do
			if ns.db.workbench[i] and ns.db.workbench[i].name == "Chain Shirt of the Bear" then
				slot = i
			end
		end
		local card = ns.UI.cards[1]
		T.eq(card.order, order)
		T.ok(not card.send:IsEnabled(), "Send needs an item")
		client:Drag(parts.bench[slot], card.slot)
		T.ok(card.send:IsEnabled())
		T.ok(card.reward:GetText():find("500", 1, true), "exact reward shown")
		local gold = ns.db.gold
		local value = ns.Forge.Value(ns.db.workbench[slot])
		card.send:Click()
		T.eq(ns.db.gold, gold + 2 * value)
		T.eq(ns.db.rep.ARGENT, 500)
		T.eq(ns.db.workbench[slot], nil)
		T.ok(client:LastChat():find("500", 1, true))
		-- A wrong item is refused on Send.
		local order2 = ns.Orders.Generate(false, "THORIUM")
		order2.group, order2.armorType, order2.minQuality, order2.ilvlMin, order2.ilvlMax = "FEET", nil, 1, 1, 60
		table.insert(ns.db.orders.daily, order2)
		loot(client, ITEMS.HELM)
		ns.Changed()
		for i = 1, 4 do
			if ns.db.workbench[i] then
				client:Drag(parts.bench[i], ns.UI.cards[1].slot)
			end
		end
		local errors = #client.errors
		ns.UI.cards[1].send:Click()
		T.eq(#client.errors, errors + 1)
		T.eq(client.errors[#client.errors], L.ERR_ORDER_SLOT)
		-- Right-click takes the staged item back.
		ns.UI.cards[1].slot:Click("RightButton")
		T.ok(not ns.UI.cards[1].send:IsEnabled())
		ns.UI.cards[1].reject:Click()
		T.ok(client:Popup().text:find("125", 1, true))
		client:AcceptPopup()
		T.eq(#ns.db.orders.daily, 0)
		T.eq(ns.db.rep.THORIUM, 0)
		hoverAll(client, parts)
	end)

	T.test(prefix .. "a weekly order card counts what was sent", function()
		local weekly = ns.db.orders.weekly
		weekly.group, weekly.armorType, weekly.minQuality, weekly.ilvlMin, weekly.ilvlMax = "ANY", nil, 1, 1, 60
		ns.Changed()
		local card = ns.UI.cards[4]
		T.eq(card.order, weekly)
		local slot
		for i = 1, 4 do
			if ns.db.workbench[i] then
				slot = i
			end
		end
		client:Drag(parts.bench[slot], card.slot)
		card.send:Click()
		T.eq(weekly.sent, 1)
		T.ok(card.range:GetText():find("1", 1, true))
		T.ok(client:LastChat():find("1", 1, true))
		card.reject:Click()
		T.ok(client:Popup().text:find(L.CONFIRM_REJECT_WEEKLY, 1, true), "warns that sent items are lost")
		client:CancelPopup()
	end)

	T.test(prefix .. "the Shop: tabs, lockboxes, reveal, and a new tool for a full shelf", function()
		ns.db.gold = 5000000
		parts.shop:Click()
		local shop = ns.Shop.parts
		T.ok(shop.frame:IsShown(), "Shop open")
		T.eq(shop.header.title:GetText(), L.SHOP_GENERAL_TITLE)
		T.ok(shop.rows[1]:IsShown() and shop.rows[5]:IsShown() and not shop.rows[6]:IsShown())
		T.ok(shop.rows[1].buy:IsShown(), "Bronze is for sale")
		T.ok(not shop.rows[2].buy:IsShown() and shop.rows[2].status:IsShown(), "Iron is locked")
		-- Fill the shelf, then open a box that gives a new tool.
		for _, id in ipairs({ "HAMMER", "WEAK_FLUX", "HEAVY_STONE", "LAVA_CORE" }) do
			ns.Economy.ReceiveTool(id, ns.Data.TOOLS[id].base)
		end
		ns.Economy.Random = scripted(1, 3) -- rare tool #3: FIERY_CORE
		shop.rows[1].buy:Click()
		T.ok(client:Popup().text:find(ns.LockboxName("BRONZE"), 1, true))
		client:AcceptPopup()
		T.eq(ns.db.pendingTool.id, "FIERY_CORE")
		T.ok(shop.reveal.text:IsShown() and shop.reveal.text:GetText():find(ns.ToolName("FIERY_CORE"), 1, true))
		T.ok(parts.pending:IsShown(), "the main window shows the new tool")
		-- Buying is blocked until the tool is placed: the button is off and says why.
		T.ok(not shop.rows[1].buy:IsEnabled(), "Buy is off while a new tool waits")
		client:RunScript(shop.rows[1].buy, "OnEnter")
		T.eq(env.GameTooltip.__text, L.ERR_PENDING_TOOL)
		local _, err = ns.Economy.BuyLockbox("BRONZE")
		T.eq(err, "ERR_PENDING_TOOL")
		-- Drag it onto the shelf: replacing asks first.
		client:Drag(parts.pending, parts.shelf[1])
		T.ok(client:Popup().text:find(ns.ToolName("HAMMER"), 1, true))
		client:AcceptPopup()
		T.eq(ns.db.shelf[1].id, "FIERY_CORE")
		T.eq(ns.db.pendingTool, nil)
		T.ok(not parts.pending:IsShown())
		-- Great hits now give +3, and the odds label says so.
		loot(client, ITEMS.BOOTS)
		for i = 1, 4 do
			if ns.db.workbench[i] then
				parts.bench[i]:Click("LeftButton")
				break
			end
		end
		T.eq(parts.odds.labels[5]:GetText(), "+3")
		-- Faction tabs.
		for tab = 2, 5 do
			env["ForgebornShopFrameTab" .. tab]:Click()
			T.ok(shop.header.bar:IsShown(), "reputation bar on tab " .. tab)
			T.ok(shop.header.standing:GetText() ~= "")
			for _, row in ipairs(shop.rows) do
				if row:IsShown() then
					client:RunScript(row.slot, "OnEnter")
					client:RunScript(row.buy, "OnEnter")
				end
			end
		end
		-- Thorium Brotherhood at Honored sells its first tool.
		ns.db.rep.THORIUM = 9000
		env.ForgebornShopFrameTab2:Click()
		T.ok(shop.rows[1].buy:IsShown() and shop.rows[1].buy:IsEnabled())
		shop.rows[1].buy:Click()
		client:AcceptPopup()
		T.eq(ns.db.pendingTool.id, "ENCHANTED_THORIUM")
		parts.pending:Click("RightButton")
		client:ClickMenu(L.MENU_DISCARD_TOOL)
		client:AcceptPopup()
		T.eq(ns.db.pendingTool, nil)
		env.ForgebornShopFrameTab1:Click()
		-- One-use items: buy, then click to use on the anvil item.
		shop.rows[4].buy:Click()
		T.eq(ns.db.consumables.COARSE_STONE, 1)
		parts.supplies[1]:Click("LeftButton")
		T.eq(ns.db.anvil.safe, 1)
		T.eq(parts.anvil.embers:GetText(), string.format(L.SAFE_LEFT, 1))
		hoverAll(client, parts)
		parts.shop:Click()
		T.ok(not shop.frame:IsShown(), "the Shop button toggles")
	end)

	T.test(prefix .. "closing works in and out of combat", function()
		local frame = env.ForgebornFrame
		frame.CloseButton:Click()
		T.ok(not frame:IsShown(), "closed with HideUIPanel")
		client.combat = true
		env.SlashCmdList.FORGEBORN("")
		T.ok(frame:IsShown(), "opens in combat")
		local errors = #client.errors
		frame.CloseButton:Click()
		T.ok(not frame:IsShown(), "closes in combat")
		ns.Shop.Open()
		ns.Shop.parts.frame.CloseButton:Click()
		T.ok(not ns.Shop.IsShown(), "the Shop closes in combat too")
		T.eq(#client.errors, errors, "no blocked action")
		client.combat = false
		local found = false
		for _, name in ipairs(env.UISpecialFrames) do
			if name == "ForgebornFrame" then
				found = true
			end
		end
		T.ok(found, "Esc closes the window")
	end)

	T.test(prefix .. "slash commands, settings and the minimap menu", function()
		local chat = #client.chat
		env.SlashCmdList.FORGEBORN("records")
		T.ok(#client.chat > chat)
		env.SlashCmdList.FORGEBORN("help")
		T.eq(client:LastChat():find(L.HELP, 1, true) ~= nil, true)
		env.SlashCmdList.FORGEBORN("settings")
		T.eq(client.settingsOpened, 77)
		local settings = client.settingsCategory.settings
		T.eq(settings.FORGEBORN_SOUND.get(), true)
		settings.FORGEBORN_SOUND.set(false)
		T.eq(ns.db.settings.sound, false)
		local sounds = #client.sounds
		ns.PlaySound("LOOT_WINDOW_COIN_SOUND")
		T.eq(#client.sounds, sounds, "sound off")
		settings.FORGEBORN_SOUND.set(true)
		env.Forgeborn_OnCompartmentClick("Forgeborn", "LeftButton")
		T.ok(env.ForgebornFrame:IsShown())
		env.Forgeborn_OnCompartmentClick("Forgeborn", "RightButton")
		T.ok(ns.Shop.IsShown())
		env.Forgeborn_OnCompartmentEnter("Forgeborn", env.UIParent)
		env.Forgeborn_OnCompartmentLeave("Forgeborn", env.UIParent)
		env.SlashCmdList.FORGEBORN("reset")
		client:AcceptPopup()
		T.eq(ns.db.gold, 0)
		T.eq(ns.db, env.ForgebornCharDB)
		T.eq(#ns.db.orders.daily, 1, "a fresh start gets today's order")
		T.eq(settings.FORGEBORN_SOUND.get(), true, "settings read the new data")
		hoverAll(client, parts)
	end)
end

scenario("enUS")
scenario("deDE")
-- The same scenario as the retail test build (branch retail-test) runs it.
scenario("enUS", "retail")

T.test("Orgrimmar for an orc, and standing names fall back to our own", function()
	local client = newClient({ race = "Orc", standingLabels = false })
	client:Login(nil)
	local ns = client.ns
	T.eq(ns.FactionName("CITY"), "Orgrimmar")
	T.eq(ns.StandingName(3), "Honored")
	local goblin = newClient({ race = "Goblin" })
	goblin:Login(nil)
	T.eq(goblin.ns.CityKey(), "STORMWIND", "unknown race: by faction")
end)

T.test("the capital city survives boss encounters, where the race is a secret value", function()
	-- Logged in normally: the city is known, so a restriction later changes nothing.
	local client = newClient({ race = "Dwarf" })
	client:Login(nil)
	local ns = client.ns
	T.eq(ns.db.city, "IRONFORGE")
	client.identityRestricted = true
	local order = ns.Orders.Generate(false, "CITY")
	table.insert(ns.db.orders.daily, order)
	client.env.SlashCmdList.FORGEBORN("")
	T.eq(ns.UI.cards[2].header:GetText():find("Ironforge", 1, true) ~= nil, true)
	ns.Shop.Open(4)
	T.eq(ns.Shop.parts.header.title:GetText(), "Ironforge")
	-- Reloaded during the encounter: the saved city is used and the secret is never touched.
	local saved = client.env.ForgebornCharDB
	local reloaded = newClient({ race = "Dwarf" })
	reloaded.identityRestricted = true
	reloaded:Login(saved)
	T.eq(reloaded.ns.FactionName("CITY"), "Ironforge")
	T.ok(reloaded.secretRaceRead, "the race was read as a secret")
	-- First login ever during a restriction: the faction's city until the race can be read.
	local fresh = newClient({ race = "Dwarf" })
	fresh.identityRestricted = true
	fresh:Login(nil)
	T.eq(fresh.ns.CityKey(), "STORMWIND")
	fresh.identityRestricted = false
	T.eq(fresh.ns.CityKey(), "IRONFORGE")
end)

T.test("Forever and retail: progress bar and order item levels", function()
	local forever = newClient({ level = 30 })
	forever:Login(nil)
	T.ok(forever.ns.Compat.isForever and not forever.ns.Compat.isRetail)
	local order = forever.ns.Orders.Generate(false, "ARGENT")
	T.eq(order.ilvlMin, 25); T.eq(order.ilvlMax, 35)
	forever.ns.Shop.Open(2)
	T.ok(forever.ns.Shop.parts.header.bar.SetFillPercent and forever.ns.Shop.parts.header.bar.FillArea, "Forever's own bar")
	local retail = newClient({ project = "retail", level = 80, avgItemLevel = 641 })
	retail:Login(nil)
	T.ok(retail.ns.Compat.isRetail and not retail.ns.Compat.isForever)
	order = retail.ns.Orders.Generate(false, "ARGENT")
	T.eq(order.ilvlMin, 631); T.eq(order.ilvlMax, 651)
	retail.ns.Shop.Open(2)
	T.eq(retail.ns.Shop.parts.header.bar:GetObjectType(), "StatusBar", "a plain status bar in retail")
end)

T.test("item names come from the client when it has them", function()
	local client = newClient({ locale = "frFR" })
	client.itemNames = { [17010] = "Cœur de feu" }
	client:Login(nil)
	local ns = client.ns
	T.eq(ns.ToolName("FIERY_CORE"), "Cœur de feu")
	T.eq(ns.ToolName("LAVA_CORE"), "Lava Core", "English until the client has the name")
end)

T.test("every tool and rank has effect text", function()
	local client = newClient({ locale = "deDE" })
	client:Login(nil)
	local ns = client.ns
	for id, def in pairs(ns.Data.TOOLS) do
		for rank = def.base, 4 do
			local text = ns.ToolEffectText(id, rank)
			T.ok(text ~= "" and not text:find("%%[%a%d]"), id .. " rank " .. rank .. ": " .. text)
		end
	end
	T.eq(ns.ToolEffectText("WEAK_FLUX", 1), "-1 Riss-Marker")
end)

T.test("order texts read naturally in English and German", function()
	local en = newClient({ locale = "enUS" })
	en:Login(nil)
	local de = newClient({ locale = "deDE" })
	de:Login(nil)
	local daily = { weekly = false, group = "FEET", minQuality = 3, count = 1 }
	local typed = { weekly = false, group = "HANDS", armorType = 1, minQuality = 1, count = 1 }
	local weekly = { weekly = true, group = "ARMOR", minQuality = 3, count = 3 }
	local weeklyTyped = { weekly = true, group = "ARMOR", armorType = 4, minQuality = 2, count = 3 }
	T.eq(en.ns.OrderAskText(daily), "Blue boots")
	T.eq(en.ns.OrderAskText(typed), "White cloth gloves")
	T.eq(en.ns.OrderAskText(weekly), "3 blue armour pieces")
	T.eq(en.ns.OrderAskText(weeklyTyped), "3 green plate armour pieces")
	T.eq(de.ns.OrderAskText(daily), "Stiefel (blau)")
	T.eq(de.ns.OrderAskText(typed), "Stoff-Handschuhe (weiß)")
	T.eq(de.ns.OrderAskText(weekly), "3 Rüstungsteile (blau)")
	T.eq(de.ns.OrderAskText(weeklyTyped), "3 Platten-Rüstungsteile (grün)")
end)
