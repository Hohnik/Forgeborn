-- A tiny test runner for Lua 5.1. Usage: lua5.1 tests/run.lua (from the repository root).
local T = { passed = 0, failed = 0, current = nil, failures = {} }

local function describe(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

function T.test(name, fn)
	T.current = name
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		T.passed = T.passed + 1
	else
		T.failed = T.failed + 1
		table.insert(T.failures, name .. "\n    " .. tostring(err):gsub("\n", "\n    "))
	end
end

function T.eq(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. describe(expected) .. ", got " .. describe(actual), 2)
	end
end

function T.near(actual, expected, tolerance, message)
	if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
		error((message or "values differ") .. ": expected " .. describe(expected) .. " ± " .. tolerance .. ", got " .. describe(actual), 2)
	end
end

function T.ok(value, message)
	if not value then
		error(message or "expected a true value", 2)
	end
end

function T.report()
	for _, failure in ipairs(T.failures) do
		print("FAIL " .. failure)
	end
	print(string.format("%d passed, %d failed", T.passed, T.failed))
	return T.failed == 0
end

-- Loads addon files into one shared namespace, the way the WoW client does: each file gets (addonName, ns) as "...".
function T.loadAddonFiles(files, ns, env)
	ns = ns or {}
	for _, file in ipairs(files) do
		local chunk, err = loadfile(file)
		if not chunk then
			error("cannot load " .. file .. ": " .. tostring(err))
		end
		if env then
			setfenv(chunk, env)
		end
		chunk("Forgeborn", ns)
	end
	return ns
end

return T
