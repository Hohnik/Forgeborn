-- A strict mock of the WoW Forever client for Forgeborn's tests (Lua 5.1).
--
-- Widgets only have the methods the real client documents (tests/fixtures/forever_widgets.lua, generated from
-- Blizzard's UI source); calling anything else fails like it would in game. Anchor points, draw layers, money
-- values and popup texts are checked the way the client would use them.
--
--   local Mock = dofile("tests/wowmock.lua")
--   local client = Mock.New({ locale = "enUS" })
--   client:LoadAddon()            -- runs every file in Forgeborn.toc
--   client:Fire("ADDON_LOADED", "Forgeborn")
local API = dofile("tests/fixtures/forever_widgets.lua")

local Mock = {}
Mock.__index = Mock

local function union(lists)
	local set = {}
	for _, name in ipairs(lists) do
		local tbl = assert(API[name], "widget API table missing: " .. name)
		for method in pairs(tbl) do
			set[method] = true
		end
	end
	return set
end

local REGION = { "SimpleObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleAnimatableObjectAPI" }
local function with(base, extra)
	local list = {}
	for _, v in ipairs(base) do
		table.insert(list, v)
	end
	for _, v in ipairs(extra) do
		table.insert(list, v)
	end
	return list
end

local ALLOWED = {
	Frame = union(with(REGION, { "SimpleFrameAPI" })),
	Button = union(with(REGION, { "SimpleFrameAPI", "SimpleButtonAPI" })),
	StatusBar = union(with(REGION, { "SimpleFrameAPI", "SimpleStatusBarAPI" })),
	GameTooltip = union(with(REGION, { "SimpleFrameAPI", "FrameAPITooltip" })),
	Texture = union(with(REGION, { "SimpleRegionAPI", "SimpleTextureBaseAPI", "SimpleTextureAPI" })),
	MaskTexture = union(with(REGION, { "SimpleRegionAPI", "SimpleTextureBaseAPI", "SimpleMaskTextureAPI" })),
	FontString = union(with(REGION, { "SimpleRegionAPI", "SimpleFontStringAPI" })),
	AnimationGroup = union({ "SimpleObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleAnimGroupAPI" }),
	Alpha = union({ "SimpleObjectAPI", "SimpleFrameScriptObjectAPI", "SimpleAnimAPI", "SimpleAnimAlphaAPI" }),
}
ALLOWED.ItemButton = ALLOWED.Button
-- Tooltip methods the docs leave out but Blizzard's own code calls hundreds of times.
for _, m in ipairs({ "SetOwner", "AddLine", "AddDoubleLine", "IsOwned", "ClearLines", "NumLines" }) do
	ALLOWED.GameTooltip[m] = true
end

local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local LAYERS = { BACKGROUND = true, BORDER = true, ARTWORK = true, OVERLAY = true, HIGHLIGHT = true }
local SCRIPTS = {
	OnEvent = true, OnShow = true, OnHide = true, OnClick = true, OnEnter = true, OnLeave = true, OnUpdate = true,
	OnDragStart = true, OnDragStop = true, OnReceiveDrag = true, OnMouseDown = true, OnMouseUp = true,
	OnFinished = true, OnPlay = true, OnStop = true, OnLoad = true, OnSizeChanged = true, OnValueChanged = true,
}

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local IMPL = {}

local function check(cond, message)
	if not cond then
		error(message, 3)
	end
end

local function isRegion(v)
	return type(v) == "table" and v.__mockType ~= nil
end

function IMPL.GetName(self) return self.__name end
function IMPL.GetParent(self) return self.__parent end
function IMPL.GetObjectType(self) return self.__mockType end
function IMPL.IsObjectType(self, t) return self.__mockType == t end
function IMPL.Show(self)
	if not self.__shown then
		self.__shown = true
		if self:IsVisible() then
			self.__client:RunScript(self, "OnShow")
		end
	end
end
function IMPL.Hide(self)
	if self.__shown then
		local wasVisible = self:IsVisible()
		self.__shown = false
		if wasVisible then
			self.__client:RunScript(self, "OnHide")
		end
	end
end
function IMPL.SetShown(self, shown)
	if shown then self:Show() else self:Hide() end
end
function IMPL.IsShown(self) return self.__shown end
function IMPL.IsVisible(self)
	local node = self
	while node do
		if not node.__shown then
			return false
		end
		node = node.__parent
	end
	return true
end
function IMPL.SetScript(self, name, fn)
	check(SCRIPTS[name], "unknown script handler " .. tostring(name))
	check(fn == nil or type(fn) == "function", "SetScript needs a function")
	self.__scripts[name] = fn
end
function IMPL.GetScript(self, name) return self.__scripts[name] end
function IMPL.HookScript(self, name, fn)
	local old = self.__scripts[name]
	self.__scripts[name] = function(...)
		if old then old(...) end
		fn(...)
	end
end
function IMPL.SetPoint(self, point, rel, relPoint, x, y)
	check(POINTS[point], "bad anchor point " .. tostring(point))
	if type(rel) == "number" then
		x, y, rel, relPoint = rel, relPoint, nil, nil
	end
	if type(rel) == "string" and POINTS[rel] and relPoint == nil then
		relPoint, rel = rel, nil
	end
	check(rel == nil or isRegion(rel) or type(rel) == "string", "bad relative frame for SetPoint")
	check(relPoint == nil or type(relPoint) == "number" or POINTS[relPoint], "bad relative point " .. tostring(relPoint))
	check(x == nil or type(x) == "number", "SetPoint x must be a number")
	check(y == nil or type(y) == "number", "SetPoint y must be a number")
	self.__points[point] = { rel, relPoint, x, y }
end
function IMPL.ClearAllPoints(self) self.__points = {} end
function IMPL.SetAllPoints(self) self.__points.all = true end
function IMPL.GetNumPoints(self)
	local n = 0
	for _ in pairs(self.__points) do n = n + 1 end
	return n
end
function IMPL.SetSize(self, w, h)
	check(type(w) == "number" and type(h) == "number", "SetSize needs two numbers")
	self.__w, self.__h = w, h
end
function IMPL.SetWidth(self, w)
	check(type(w) == "number", "SetWidth needs a number")
	self.__w = w
end
function IMPL.SetHeight(self, h)
	check(type(h) == "number", "SetHeight needs a number")
	self.__h = h
end
function IMPL.GetWidth(self) return self.__w or 0 end
function IMPL.GetHeight(self) return self.__h or 0 end
function IMPL.GetSize(self) return self.__w or 0, self.__h or 0 end
function IMPL.SetAlpha(self, a)
	check(type(a) == "number", "SetAlpha needs a number")
	self.__alpha = a
end
function IMPL.GetAlpha(self) return self.__alpha or 1 end
function IMPL.SetScale(self, s)
	check(type(s) == "number" and s > 0, "SetScale needs a positive number")
	self.__scale = s
end
function IMPL.GetScale(self) return self.__scale or 1 end
function IMPL.GetEffectiveScale(self) return self.__scale or 1 end
function IMPL.EnableMouse(self, on) self.__mouse = on and true or false end
function IMPL.IsMouseEnabled(self) return self.__mouse end
function IMPL.IsMouseOver(self) return self.__mouseOver == true end
function IMPL.SetFrameStrata(self, s)
	check(type(s) == "string", "SetFrameStrata needs a string")
	self.__strata = s
end
function IMPL.SetFrameLevel(self, l)
	check(type(l) == "number", "SetFrameLevel needs a number")
	self.__level = l
end
function IMPL.GetFrameLevel(self) return self.__level or 1 end
function IMPL.SetID(self, id)
	check(type(id) == "number", "SetID needs a number")
	self.__id = id
end
function IMPL.GetID(self) return self.__id or 0 end
function IMPL.RegisterEvent(self, event)
	check(type(event) == "string", "RegisterEvent needs a string")
	check(self.__client.knownEvents == nil or self.__client.knownEvents[event], "unknown event " .. event)
	self.__events[event] = true
end
function IMPL.UnregisterEvent(self, event) self.__events[event] = nil end
function IMPL.IsEventRegistered(self, event) return self.__events[event] == true end
function IMPL.RegisterForDrag(self, ...)
	for i = 1, select("#", ...) do
		check(select(i, ...) == "LeftButton" or select(i, ...) == "RightButton", "bad drag button")
	end
	self.__drag = true
end
function IMPL.RegisterForClicks(self, ...)
	for i = 1, select("#", ...) do
		check(type(select(i, ...)) == "string", "RegisterForClicks needs strings")
	end
end
function IMPL.SetMovable(self, on) self.__movable = on end
function IMPL.StartMoving(self)
	check(self.__movable, "StartMoving on a frame that isn't movable")
end
function IMPL.CreateTexture(self, name, layer, inherits, sublevel)
	check(layer == nil or LAYERS[layer], "bad draw layer " .. tostring(layer))
	check(sublevel == nil or (type(sublevel) == "number" and sublevel >= -8 and sublevel <= 7), "bad texture sublevel")
	return self.__client:NewRegion("Texture", name, self)
end
function IMPL.CreateMaskTexture(self, name, layer)
	check(layer == nil or LAYERS[layer], "bad draw layer " .. tostring(layer))
	return self.__client:NewRegion("MaskTexture", name, self)
end
function IMPL.CreateFontString(self, name, layer, inherits)
	check(layer == nil or LAYERS[layer], "bad draw layer " .. tostring(layer))
	check(inherits == nil or self.__client.fonts[inherits], "unknown font object " .. tostring(inherits))
	return self.__client:NewRegion("FontString", name, self)
end
function IMPL.CreateAnimationGroup(self)
	local group = self.__client:NewRegion("AnimationGroup", nil, self)
	group.__shown = true
	group.__animations = {}
	return group
end
function IMPL.CreateAnimation(self, kind)
	check(kind == "Alpha", "the mock only supports Alpha animations")
	local anim = self.__client:NewRegion("Alpha", nil, self)
	table.insert(self.__animations, anim)
	return anim
end
function IMPL.Play(self)
	self.__playing = true
	self.__client.animationsPlayed = (self.__client.animationsPlayed or 0) + 1
	-- Finish at once so OnFinished runs in the tests.
	self.__playing = false
	self.__client:RunScript(self, "OnFinished")
end
function IMPL.Stop(self) self.__playing = false end
function IMPL.IsPlaying(self) return self.__playing == true end
function IMPL.SetFromAlpha(self, a) check(type(a) == "number", "SetFromAlpha needs a number") end
function IMPL.SetToAlpha(self, a) check(type(a) == "number", "SetToAlpha needs a number") end
function IMPL.SetDuration(self, d) check(type(d) == "number" and d >= 0, "SetDuration needs a number") end
function IMPL.SetOrder(self, o) check(type(o) == "number", "SetOrder needs a number") end

local function textValue(v)
	check(v == nil or type(v) == "string" or type(v) == "number", "SetText needs a string, number or nil, got " .. type(v))
	return v ~= nil and tostring(v) or nil
end
function IMPL.SetText(self, text) self.__text = textValue(text) end
function IMPL.GetText(self) return self.__text end
function IMPL.SetFormattedText(self, fmt, ...) self.__text = string.format(fmt, ...) end
function IMPL.SetTextColor(self, r, g, b)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetTextColor needs numbers")
	self.__color = { r, g, b }
end
function IMPL.GetStringWidth(self)
	local plain = (self.__text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return #plain * 6
end
function IMPL.SetJustifyH(self, j)
	check(j == "LEFT" or j == "CENTER" or j == "RIGHT", "bad SetJustifyH value " .. tostring(j))
end
function IMPL.SetWordWrap(self, on) check(type(on) == "boolean", "SetWordWrap needs a boolean") end
function IMPL.IsTruncated(self) return false end

function IMPL.SetTexture(self, tex, wrapH, wrapV)
	check(tex == nil or type(tex) == "string" or type(tex) == "number", "SetTexture needs a path or file ID")
	self.__texture = tex
end
function IMPL.GetTexture(self) return self.__texture end
function IMPL.SetAtlas(self, atlas) self.__texture = atlas end
function IMPL.SetColorTexture(self, r, g, b, a)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetColorTexture needs numbers")
	check(a == nil or type(a) == "number", "SetColorTexture alpha must be a number")
	self.__colorTexture = { r, g, b, a }
end
function IMPL.SetVertexColor(self, r, g, b)
	check(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor needs numbers")
	self.__vertex = { r, g, b }
end
function IMPL.SetBlendMode(self, mode)
	check(mode == "ADD" or mode == "BLEND" or mode == "MOD" or mode == "ALPHAKEY" or mode == "DISABLE", "bad blend mode")
end
function IMPL.SetDesaturated(self, on) self.__desaturated = on and true or false end
function IMPL.IsDesaturated(self) return self.__desaturated end
function IMPL.AddMaskTexture(self, mask)
	check(isRegion(mask) and mask.__mockType == "MaskTexture", "AddMaskTexture needs a mask texture")
end

function IMPL.Enable(self) self.__enabled = true end
function IMPL.Disable(self) self.__enabled = false end
function IMPL.SetEnabled(self, on)
	check(type(on) == "boolean", "SetEnabled needs a boolean")
	self.__enabled = on
end
function IMPL.IsEnabled(self) return self.__enabled ~= false end
function IMPL.Click(self, button)
	if self:IsEnabled() and self:IsVisible() then
		self.__client:RunScript(self, "OnClick", button or "LeftButton", false)
	end
end
function IMPL.SetMotionScriptsWhileDisabled(self, on) self.__motion = on end

function IMPL.SetStatusBarTexture(self, tex)
	self.__barTexture = self.__barTexture or self.__client:NewRegion("Texture", nil, self)
	self.__barTexture:SetTexture(tex)
end
function IMPL.GetStatusBarTexture(self) return self.__barTexture end
function IMPL.SetMinMaxValues(self, lo, hi) self.__min, self.__max = lo, hi end
function IMPL.SetValue(self, v) self.__value = v end
function IMPL.GetValue(self) return self.__value end

-- Tooltip
function IMPL.SetOwner(self, owner, anchor)
	check(isRegion(owner), "SetOwner needs a frame")
	check(type(anchor) == "string" and anchor:find("^ANCHOR_"), "SetOwner needs an ANCHOR_ value")
	self.__owner = owner
	self.__lines = {}
end
function IMPL.AddLine(self, text, r, g, b, wrap)
	check(type(text) == "string" or type(text) == "number", "AddLine needs text")
	table.insert(self.__lines, tostring(text))
end
function IMPL.AddDoubleLine(self, left, right)
	check(left ~= nil and right ~= nil, "AddDoubleLine needs two texts")
	table.insert(self.__lines, tostring(left) .. " | " .. tostring(right))
end
function IMPL.IsOwned(self, owner) return self.__owner == owner end

local regionMeta = {}
regionMeta.__index = function(self, key)
	local kind = rawget(self, "__mockType")
	local impl = IMPL[key]
	local allowed = ALLOWED[kind]
	if allowed and allowed[key] then
		if impl then
			return impl
		end
		return function() end -- a real method the tests don't need to model
	end
	return nil
end

function Mock:NewRegion(kind, name, parent)
	local region = setmetatable({
		__mockType = kind, __name = name, __parent = parent, __client = self,
		__shown = true, __scripts = {}, __events = {}, __points = {},
	}, regionMeta)
	if name then
		self.env[name] = region
	end
	table.insert(self.regions, region)
	return region
end

function Mock:RunScript(region, name, ...)
	local fn = region.__scripts[name]
	if fn then
		return fn(region, ...)
	end
end

---------------------------------------------------------------------------
-- Templates (only what Forgeborn reads from them)
---------------------------------------------------------------------------

local TEMPLATES = {}

TEMPLATES.InsetFrameTemplate = function() end

TEMPLATES.UIPanelButtonTemplate = function(client, f)
	f.Text = client:NewRegion("FontString", nil, f)
end
TEMPLATES.SharedButtonLargeTemplate = TEMPLATES.UIPanelButtonTemplate

TEMPLATES.PortraitFrameTemplate = function(client, f)
	f.PortraitContainer = client:NewRegion("Frame", nil, f)
	f.PortraitContainer.portrait = client:NewRegion("Texture", nil, f.PortraitContainer)
	f.TitleContainer = client:NewRegion("Frame", nil, f)
	f.TitleContainer.TitleText = client:NewRegion("FontString", nil, f.TitleContainer)
	f.TitleContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -1)
	f.TitleContainer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -1)
	f.TitleContainer.TitleText:SetPoint("TOP", f, "TOP", 0, -5)
	f.CloseButton = client:NewRegion("Button", f.__name and (f.__name .. "CloseButton"), f)
	-- UIPanelCloseButton_OnClick
	f.CloseButton.__scripts.OnClick = function(self)
		local parent = self:GetParent()
		local continueHide = true
		if parent.onCloseCallback then
			continueHide = parent.onCloseCallback(self)
		end
		if continueHide then
			client.env.HideUIPanel(parent)
		end
	end
	function f.SetTitle(self, text) self.TitleContainer.TitleText:SetText(text) end
	function f.GetTitleText(self) return self.TitleContainer.TitleText end
	function f.SetPortraitToAsset(self, texture) self.PortraitContainer.portrait:SetTexture(texture) end
	function f.GetPortrait(self) return self.PortraitContainer.portrait end
end
TEMPLATES.ButtonFrameTemplate = function(client, f)
	TEMPLATES.PortraitFrameTemplate(client, f)
	f.Inset = client:NewRegion("Frame", f.__name and (f.__name .. "Inset"), f)
end

TEMPLATES.PanelTabButtonTemplate = function(client, f, parent)
	f.Text = client:NewRegion("FontString", nil, f)
	f.Text:SetPoint("CENTER", f, "CENTER", 0, 2)
	f:SetHeight(32)
	for _, key in ipairs({ "Left", "Right", "Middle", "LeftActive", "RightActive", "MiddleActive" }) do
		f[key] = client:NewRegion("Texture", nil, f)
	end
	-- parentArray="Tabs"
	parent.Tabs = parent.Tabs or {}
	table.insert(parent.Tabs, f)
	local setText = IMPL.SetText
	f.SetText = function(self, text)
		setText(self, text)
		self.Text:SetText(text)
	end
end

TEMPLATES.ColoredProgressBarTemplate = function(client, f)
	f.FillArea = client:NewRegion("Frame", nil, f)
	f.Fill = client:NewRegion("Texture", nil, f)
	f.Text = client:NewRegion("FontString", nil, f)
	function f.SetFillPercent(self, percent)
		check(type(percent) == "number", "SetFillPercent needs a number")
		self.__fill = math.min(1, math.max(0, percent))
	end
	function f.SetText(self, text) self.Text:SetText(text) end
end

local function itemButton(client, f)
	f.__w, f.__h = 37, 37
	f.icon = client:NewRegion("Texture", nil, f)
	f.Count = client:NewRegion("FontString", nil, f)
	f.Count.__shown = false
	f.IconBorder = client:NewRegion("Texture", nil, f)
	f.IconOverlay = client:NewRegion("Texture", nil, f)
	f.NormalTexture = client:NewRegion("Texture", nil, f)
end

---------------------------------------------------------------------------
-- The client
---------------------------------------------------------------------------

function Mock.New(options)
	options = options or {}
	local self = setmetatable({}, Mock)
	self.regions = {}
	self.chat = {}
	self.errors = {}
	self.sounds = {}
	self.timers = {}
	self.popups = {}
	self.now = options.now or 1792700000 -- server time (seconds)
	self.uptime = 1000
	self.combat = false
	self.locale = options.locale or "enUS"
	self.level = options.level or 20
	self.race = options.race or "Human"
	self.project = options.project or "forever" -- or "retail"
	self.avgItemLevel = options.avgItemLevel or 650
	self.identityRestricted = false -- while true, UnitRace returns a secret value
	self.items = {}
	self.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
	self.bagSize = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	self.loot = {}
	self.nextGUID = 1
	self.fonts = {}
	for _, font in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalLarge", "GameFontHighlightSmall",
		"GameFontNormalSmall", "GameFontDisableSmall", "GameFontDisable", "GameFontRedSmall", "NumberFontNormal" }) do
		self.fonts[font] = true
	end
	self:BuildEnv(options)
	return self
end

local function linkFor(itemID, name, quality)
	return string.format("|cff%s|Hitem:%d::::::::20:::::|h[%s]|h|r", quality >= 3 and "0070dd" or "ffffff", itemID, name)
end

-- Adds an item to the fake item database.
function Mock:DefineItem(def)
	def.link = linkFor(def.id, def.name, def.quality)
	def.icon = def.icon or 134400
	self.items[def.id] = def
	return def
end

local function itemIDOf(info)
	if type(info) == "number" then
		return info
	end
	if type(info) == "string" then
		return tonumber(info:match("item:(%d+)")) or tonumber(info)
	end
	return nil
end

-- Puts an item in the first free bag slot (as if it arrived). Returns bag, slot.
function Mock:GiveItem(itemID)
	for bag = 0, 4 do
		for slot = 1, self.bagSize[bag] do
			if not self.bags[bag][slot] then
				self.bags[bag][slot] = { id = itemID, guid = "Item-0-" .. self.nextGUID }
				self.nextGUID = self.nextGUID + 1
				return bag, slot
			end
		end
	end
	error("bags full")
end

function Mock:RemoveItem(bag, slot)
	self.bags[bag][slot] = nil
end

-- Opens a loot window with these item IDs (and fires LOOT_READY, LOOT_OPENED).
function Mock:OpenLoot(itemIDs, isFromItem)
	self.loot = {}
	for _, id in ipairs(itemIDs) do
		table.insert(self.loot, id)
	end
	self:Fire("LOOT_READY", false)
	self:Fire("LOOT_OPENED", false, isFromItem or false)
end

-- Takes everything from the loot window into the bags and closes it.
function Mock:TakeLoot()
	for _, id in ipairs(self.loot) do
		if type(id) == "number" then
			self:GiveItem(id)
		end
	end
	self.loot = {}
	self:Fire("LOOT_CLOSED")
	self:Fire("BAG_UPDATE_DELAYED")
end

function Mock:Advance(seconds)
	self.now = self.now + seconds
	self.uptime = self.uptime + seconds
	local due = {}
	for i = #self.timers, 1, -1 do
		local t = self.timers[i]
		if not t.cancelled and t.at <= self.uptime then
			table.remove(self.timers, i)
			table.insert(due, t)
		end
	end
	table.sort(due, function(a, b) return a.at < b.at end)
	for _, t in ipairs(due) do
		t.fn(t.handle)
	end
end

function Mock:Fire(event, ...)
	for _, region in ipairs(self.regions) do
		if region.__events and region.__events[event] then
			self:RunScript(region, "OnEvent", event, ...)
		end
	end
end

-- The last StaticPopup shown.
function Mock:Popup()
	return self.popups[#self.popups]
end

function Mock:AcceptPopup()
	local popup = table.remove(self.popups)
	assert(popup, "no popup to accept")
	local dialog = self.env.StaticPopupDialogs[popup.which]
	if dialog.OnAccept then
		dialog.OnAccept({}, popup.data, nil)
	end
	return popup
end

function Mock:CancelPopup()
	return table.remove(self.popups)
end

function Mock:ClickMenu(text)
	local menu = assert(self.menu, "no menu open")
	for _, entry in ipairs(menu.entries) do
		if entry.text == text then
			self.menu = nil
			entry.fn()
			return true
		end
	end
	error("menu has no entry " .. tostring(text))
end

-- Drags from one button and drops on another, like the player would.
function Mock:Drag(from, to)
	self:RunScript(from, "OnDragStart", "LeftButton")
	for _, r in ipairs(self.regions) do
		r.__mouseOver = false
	end
	if to then
		to.__mouseOver = true
	end
	self:RunScript(from, "OnDragStop")
	if to then
		to.__mouseOver = false
	end
	self.uptime = self.uptime + 1 -- the player takes a moment before the next click
end

-- A drag that ends with the client also sending a click to the source button.
function Mock:DragWithClick(from, to)
	self:RunScript(from, "OnDragStart", "LeftButton")
	for _, r in ipairs(self.regions) do
		r.__mouseOver = false
	end
	if to then
		to.__mouseOver = true
	end
	self:RunScript(from, "OnDragStop")
	self:RunScript(from, "OnClick", "LeftButton", false)
	if to then
		to.__mouseOver = false
	end
	self.uptime = self.uptime + 1
end

function Mock:LastChat()
	return self.chat[#self.chat]
end

---------------------------------------------------------------------------
-- The global environment the addon runs in
---------------------------------------------------------------------------

function Mock:BuildEnv(options)
	local client = self
	local env = {}
	self.env = env
	setmetatable(env, { __index = _G })
	env._G = env

	-- Daily reset at 07:00 UTC, weekly on Wednesday 07:00 UTC (the EU schedule).
	local DAY, WEEK, RESET_OFFSET = 86400, 604800, 7 * 3600
	local WEEK_OFFSET = RESET_OFFSET + 6 * DAY -- 1970-01-01 was a Thursday; +6 days = Wednesday

	env.GetServerTime = function() return client.now end
	env.GetTime = function() return client.uptime end
	env.time = function() return client.now end
	env.GetLocale = function() return client.locale end
	env.UnitLevel = function(unit) assert(unit == "player") return client.level end
	-- A secret value: any use but issecretvalue() fails, like in the client.
	local SECRET = setmetatable({}, {
		__index = function() error("attempt to index a secret value", 2) end,
		__tostring = function() error("attempt to use a secret value", 2) end,
		__concat = function() error("attempt to concatenate a secret value", 2) end,
		__eq = function() error("attempt to compare a secret value", 2) end,
	})
	client.secretValue = SECRET
	env.issecretvalue = function(v) return v == nil and false or rawequal(v, SECRET) end
	env.UnitRace = function()
		if client.identityRestricted then
			client.secretRaceRead = true
			return SECRET, SECRET, SECRET
		end
		return client.race, client.race
	end
	if client.project == "retail" then
		env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
		env.WOW_PROJECT_ID = 1
		env.GetAverageItemLevel = function() return client.avgItemLevel + 3, client.avgItemLevel, client.avgItemLevel end
	else
		env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC, env.WOW_PROJECT_CAMELOT = 1, 2, 18
		env.WOW_PROJECT_ID = 18
		env.GetAverageItemLevel = function() return 22, 21, 21 end
	end
	env.UnitFactionGroup = function() return "Alliance", "Alliance" end
	env.GetMaxLevelForPlayerExpansion = function() return 60 end
	env.InCombatLockdown = function() return client.combat end
	env.GetCursorPosition = function() return 400, 300 end
	env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	env.YES, env.NO = "Yes", "No"
	if options.standingLabels ~= false then
		local labels = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
		for i, label in ipairs(labels) do
			env["FACTION_STANDING_LABEL" .. i] = label
		end
	end
	env.FACTION_BAR_COLORS = {}
	for i = 1, 8 do
		env.FACTION_BAR_COLORS[i] = { r = 0, g = 0.6, b = 0.1 }
	end
	env.BACKPACK_CONTAINER, env.NUM_BAG_SLOTS = 0, 4
	env.Enum = { LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 } }

	env.SOUNDKIT = setmetatable({}, {
		__index = function(_, key)
			if API.__soundkit[key] then
				return 1000
			end
			error("SOUNDKIT has no " .. tostring(key), 2)
		end,
	})
	env.PlaySound = function(id)
		assert(type(id) == "number", "PlaySound needs a sound kit ID")
		table.insert(client.sounds, id)
	end

	env.CreateFrame = function(kind, name, parent, template)
		assert(kind == "Frame" or kind == "Button" or kind == "ItemButton" or kind == "StatusBar", "unknown frame type " .. tostring(kind))
		assert(parent == nil or isRegion(parent), "bad parent")
		assert(template == nil or TEMPLATES[template], "template not modelled by the mock: " .. tostring(template))
		if template == "ColoredProgressBarTemplate" and client.project ~= "forever" then
			error("CreateFrame(): Couldn't find inherited node \"ColoredProgressBarTemplate\"")
		end
		local f = client:NewRegion(kind, name, parent)
		if kind == "ItemButton" then
			itemButton(client, f)
		end
		if template then
			TEMPLATES[template](client, f, parent)
		end
		return f
	end
	env.UIParent = client:NewRegion("Frame", "UIParent", nil)
	env.GameTooltip = client:NewRegion("GameTooltip", "GameTooltip", env.UIParent)
	env.GameTooltip.__shown = false
	env.GameTooltip.__lines = {}
	env.UIErrorsFrame = { AddMessage = function(_, text) table.insert(client.errors, text) end }
	env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(client.chat, text) end }

	env.UIPanelWindows = {}
	env.UISpecialFrames = {}
	env.SlashCmdList = {}
	env.StaticPopupDialogs = {}
	env.ShowUIPanel = function(frame)
		if client.combat then
			table.insert(client.errors, "Interface action failed because of an AddOn")
			return
		end
		client.panelShown = frame
		frame:Show()
	end
	env.HideUIPanel = function(frame)
		if client.combat then
			table.insert(client.errors, "Interface action failed because of an AddOn")
			return
		end
		frame:Hide()
	end
	env.StaticPopup_Show = function(which, arg1, arg2, data)
		local dialog = assert(env.StaticPopupDialogs[which], "no dialog " .. tostring(which))
		assert(dialog.button1, "dialog without a first button")
		local popup = { which = which, text = string.format(dialog.text, arg1, arg2), data = data }
		table.insert(client.popups, popup)
		return popup
	end
	env.MenuUtil = {
		CreateContextMenu = function(owner, generator)
			assert(isRegion(owner), "CreateContextMenu needs an owner")
			local menu = { entries = {} }
			local root = {
				CreateTitle = function(_, text) menu.title = text end,
				CreateButton = function(_, text, fn)
					assert(type(text) == "string" and type(fn) == "function", "CreateButton needs text and a function")
					table.insert(menu.entries, { text = text, fn = fn })
				end,
			}
			generator(owner, root)
			client.menu = menu
		end,
	}
	env.Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function(name)
			local category = { name = name, settings = {}, GetID = function() return 77 end }
			client.settingsCategory = category
			return category, {}
		end,
		RegisterProxySetting = function(category, variable, varType, name, default, get, set)
			assert(varType == "boolean" and type(get) == "function" and type(set) == "function")
			local setting = { variable = variable, name = name, default = default, get = get, set = set }
			category.settings[variable] = setting
			return setting
		end,
		CreateCheckbox = function(category, setting) assert(category and setting) end,
		RegisterAddOnCategory = function(category) client.settingsRegistered = category end,
		OpenToCategory = function(id) client.settingsOpened = id end,
	}

	env.C_Timer = {
		NewTimer = function(seconds, fn)
			assert(type(seconds) == "number" and seconds >= 0, "NewTimer needs seconds")
			local t = { at = client.uptime + seconds, fn = fn }
			t.handle = { Cancel = function() t.cancelled = true end }
			table.insert(client.timers, t)
			return t.handle
		end,
		After = function(seconds, fn)
			table.insert(client.timers, { at = client.uptime + seconds, fn = fn, handle = {} })
		end,
	}
	env.C_DateAndTime = {
		GetSecondsUntilDailyReset = function()
			return DAY - ((client.now - RESET_OFFSET) % DAY)
		end,
		GetSecondsUntilWeeklyReset = function()
			return WEEK - ((client.now - WEEK_OFFSET) % WEEK)
		end,
	}

	local QUALITY_RGB = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
	env.C_Item = {
		GetItemInfoInstant = function(info)
			local def = client.items[itemIDOf(info)]
			if not def then
				return nil
			end
			return def.id, "Armor", "Misc", def.equipLoc, def.icon, def.classID, def.subclassID
		end,
		GetItemInfo = function(info)
			local def = client.items[itemIDOf(info)]
			if not def or client.uncached then
				return nil
			end
			return def.name, def.link, def.quality, def.ilvl, 1, "Armor", "Misc", 1, def.equipLoc, def.icon, 100, def.classID, def.subclassID
		end,
		GetDetailedItemLevelInfo = function(info)
			local def = client.items[itemIDOf(info)]
			return def and def.ilvl, false, def and def.ilvl
		end,
		GetItemQualityColor = function(q)
			assert(type(q) == "number" and QUALITY_RGB[q], "GetItemQualityColor needs a quality 0-5, got " .. tostring(q))
			local c = QUALITY_RGB[q]
			return c[1], c[2], c[3], "ffffffff"
		end,
		GetItemNameByID = function(id)
			assert(type(id) == "number")
			return client.itemNames and client.itemNames[id] or nil
		end,
		IsItemDataCachedByID = function() return false end,
		RequestLoadItemDataByID = function(id) assert(type(id) == "number") end,
		DoesItemExist = function(location)
			return client.bags[location.bag] and client.bags[location.bag][location.slot] ~= nil
		end,
		GetItemGUID = function(location)
			local entry = client.bags[location.bag][location.slot]
			return entry and entry.guid
		end,
	}
	env.C_Container = {
		GetContainerNumSlots = function(bag) return client.bagSize[bag] or 0 end,
		GetContainerItemInfo = function(bag, slot)
			local entry = client.bags[bag] and client.bags[bag][slot]
			if not entry then
				return nil
			end
			local def = client.items[entry.id]
			return { itemID = entry.id, hyperlink = def.link, iconFileID = def.icon, stackCount = 1, quality = def.quality, itemName = def.name }
		end,
	}
	env.ItemLocation = {
		CreateFromBagAndSlot = function(_, bag, slot)
			return { bag = bag, slot = slot }
		end,
	}
	env.Item = {
		CreateFromItemLink = function(_, link)
			assert(type(link) == "string", "CreateFromItemLink needs a link")
			return {
				IsItemEmpty = function() return client.items[itemIDOf(link)] == nil end,
				ContinueOnItemLoad = function(_, fn)
					if client.deferItemLoad then
						client.pendingLoads = client.pendingLoads or {}
						table.insert(client.pendingLoads, fn)
					else
						fn()
					end
				end,
			}
		end,
	}
	env.GetNumLootItems = function() return #client.loot end
	env.GetLootSlotType = function(slot)
		local entry = client.loot[slot]
		if type(entry) == "number" then
			return env.Enum.LootSlotType.Item
		end
		return entry == "money" and env.Enum.LootSlotType.Money or env.Enum.LootSlotType.None
	end
	env.GetLootSlotLink = function(slot)
		local entry = client.loot[slot]
		return type(entry) == "number" and client.items[entry].link or nil
	end

	env.GetMoneyString = function(money, separateThousands)
		assert(type(money) == "number" and money >= 0 and math.floor(money) == money, "GetMoneyString needs whole copper, got " .. tostring(money))
		local gold = math.floor(money / 10000)
		local silver = math.floor((money % 10000) / 100)
		local copper = money % 100
		local parts = {}
		if gold > 0 then table.insert(parts, gold .. "g") end
		if silver > 0 then table.insert(parts, silver .. "s") end
		if copper > 0 or #parts == 0 then table.insert(parts, copper .. "c") end
		return table.concat(parts, " ")
	end
	env.BreakUpLargeNumbers = function(n)
		assert(type(n) == "number", "BreakUpLargeNumbers needs a number")
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	env.SetItemButtonTexture = function(button, texture)
		assert(isRegion(button), "SetItemButtonTexture needs a button")
		button.mockIcon = texture
		button.icon:SetTexture(texture)
	end
	env.SetItemButtonQuality = function(button, quality)
		assert(quality == nil or (type(quality) == "number" and quality >= 0 and quality <= 8), "bad quality " .. tostring(quality))
		button.mockQuality = quality
	end
	env.SetItemButtonCount = function(button, count)
		assert(count == nil or type(count) == "number", "SetItemButtonCount needs a number")
		button.mockCount = count
	end
	env.SetItemButtonDesaturated = function(button, desaturated)
		assert(type(desaturated) == "boolean", "SetItemButtonDesaturated needs a boolean")
		button.mockDesaturated = desaturated
	end

	local function getTab(frame, i)
		return frame.Tabs and frame.Tabs[i] or env[(frame:GetName() or "") .. "Tab" .. i]
	end
	env.PanelTemplates_SetNumTabs = function(frame, n)
		for i = 1, n do
			assert(getTab(frame, i), "tab " .. i .. " is missing")
			if i > 1 then
				getTab(frame, i):SetPoint("TOPLEFT", getTab(frame, i - 1), "TOPRIGHT", 3, 0)
			end
		end
		frame.numTabs = n
	end
	env.PanelTemplates_SetTab = function(frame, id)
		frame.selectedTab = id
		for i = 1, frame.numTabs do
			getTab(frame, i):SetEnabled(i ~= id)
		end
	end
	env.PanelTemplates_TabResize = function(tab, padding, absolute, minWidth, maxWidth)
		assert(isRegion(tab) and tab.Text, "PanelTemplates_TabResize needs a tab")
		tab:SetWidth(math.min(maxWidth or 1000, tab.Text:GetStringWidth() + 20 + (padding or 0)))
	end
end

-- Loads every file of Forgeborn.toc into this client, like the game does.
function Mock:LoadAddon(path)
	path = path or "."
	local ns = {}
	local toc = assert(io.open(path .. "/Forgeborn.toc", "r"))
	for line in toc:lines() do
		line = line:gsub("\r", "")
		if line ~= "" and not line:find("^#") then
			local file = path .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(file))
			setfenv(chunk, self.env)
			chunk("Forgeborn", ns)
		end
	end
	toc:close()
	self.ns = ns
	return ns
end

-- Starts the game: saved data loaded, login, entering the world.
function Mock:Login(savedData)
	self.env.ForgebornCharDB = savedData
	self:Fire("ADDON_LOADED", "Forgeborn", false)
	self:Fire("PLAYER_LOGIN")
	self:Fire("PLAYER_ENTERING_WORLD", true, false)
end

return Mock
