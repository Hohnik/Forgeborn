-- Runs every test file. From the repository root: lua5.1 tests/run.lua
package.path = "./tests/?.lua;" .. package.path
local T = require("testlib")

local files = { ... }
if #files == 0 then
	files = { "tests/test_rules.lua" }
	local extra = { "tests/test_game.lua", "tests/test_ui.lua", "tests/test_layout.lua", "tests/test_retail.lua" }
	for _, file in ipairs(extra) do
		local handle = io.open(file, "r")
		if handle then
			handle:close()
			table.insert(files, file)
		end
	end
end

for _, file in ipairs(files) do
	print("== " .. file)
	local chunk = assert(loadfile(file))
	chunk(T)
end

if not T.report() then
	os.exit(1)
end
