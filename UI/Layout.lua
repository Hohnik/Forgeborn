-- Forgeborn: where everything in the main window sits.
--
-- Change the numbers by hand, or visually: open tools/layout-editor/index.html in a browser, drag and resize
-- things, press "Copy Lua" and paste the result over this file.
--
-- Positions are pixels from the top-left corner of the box a thing sits in; y counts down.
--   box, button, bar  { x, y, width, height }
--   text              { x, y, width }      one line, or more where it wraps; its height follows the font
--   slot              { x, y, size }       an item slot is 37 px; other sizes scale it
--   row               { x, y, step }       a row of item slots: the first slot, then one every "step" px
--   cards             { x, y, width, height, gap }
local _, ns = ...

ns.Layout = {
	window = { 780, 590 }, -- width, height

	-- In the window
	anvil = { 8, 60, 404, 268 }, -- box: the anvil
	storage = { 8, 332, 404, 216 }, -- box: Workbench, Shelf, Supplies, Display case
	orders = { 418, 60, 354, 488 }, -- box: crafting orders
	gold = { 18, 560, 240 }, -- text: "Addon gold" and the amount
	shopHint = { 398, 561, 250 }, -- text, right-aligned
	shop = { 658, 556, 110, 24 }, -- button: Shop

	-- In the anvil box
	nextSwing = { 12, 10, 180 }, -- text: "Next swing"
	embers = { 138, 11, 150 }, -- text, right-aligned: "Embers 3/7"
	pips = { 294, 11, 98, 12 }, -- the 7 ember circles
	odds = { 12, 32, 380, 22 }, -- bar: odds of the next swing; the outcome labels sit under it
	anvilSlot = { 177, 84, 50 }, -- slot: the anvil
	itemName = { 12, 142, 380 }, -- text, centred
	itemInfo = { 12, 164, 380 }, -- text, centred: quality, item level, levels to the next quality
	itemValue = { 12, 180, 380 }, -- text, centred: value and value after a Hit
	status = { 10, 200, 384 }, -- text, centred, 2 lines: what the last swing did
	forge = { 12, 226, 182, 32 }, -- button: Forge
	sell = { 210, 226, 182, 32 }, -- button: Sell

	-- In the storage box
	workbenchTitle = { 12, 10, 180 }, -- text
	workbench = { 14, 30, 44 }, -- row of 4 slots
	shelfTitle = { 208, 10, 180 }, -- text
	shelf = { 210, 30, 44 }, -- row of 4 slots
	suppliesTitle = { 12, 78, 180 }, -- text
	supplies = { 14, 98, 44 }, -- row of 2 slots: sharpening stones
	newTool = { 210, 98, 37 }, -- slot: a new tool waiting for a shelf slot
	newToolText = { 255, 98, 140 }, -- text, 3 lines
	displayTitle = { 12, 146, 180 }, -- text
	trophyBonus = { 242, 148, 150 }, -- text, right-aligned
	display = { 14, 166, 44 }, -- row of 6 slots: the Display case

	-- In the orders box
	ordersTitle = { 12, 10, 180 }, -- text
	waiting = { 192, 12, 150 }, -- text, right-aligned: orders waiting
	cards = { 10, 32, 334, 86, 4 }, -- the order cards, top to bottom

	-- In each order card
	cardHeader = { 10, 8, 260 }, -- text: faction · daily or weekly
	cardAsk = { 10, 24, 270 }, -- text: what the order asks for
	cardRange = { 10, 42, 270 }, -- text: item levels
	cardReward = { 10, 58, 156 }, -- text, 2 lines: the reward
	cardSlot = { 287, 8, 37 }, -- slot: drop an item here
	cardSend = { 172, 56, 74, 22 }, -- button: Send
	cardReject = { 250, 56, 74, 22 }, -- button: Reject
	cardEmpty = { 12, 30, 310 }, -- text, centred, 2 lines: shown on an empty card
}
