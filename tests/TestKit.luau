--!strict
-- Mini-framework de tests pour Lune (exécution hors Studio).

local TestKit = {}

local passed = 0
local failures: { string } = {}
local currentSuite = ""

local function describe(value: any): string
	if typeof(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function TestKit.suite(name: string)
	currentSuite = name
	print(`\n▶ {name}`)
end

function TestKit.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`  ✓ {name}`)
	else
		table.insert(failures, `{currentSuite} › {name} : {err}`)
		print(`  ✗ {name}\n      {err}`)
	end
end

function TestKit.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "valeur"} : attendu {describe(expected)}, obtenu {describe(actual)}`, 2)
	end
end

function TestKit.truthy(value: any, label: string?)
	if not value then
		error(`{label or "condition"} : attendu vrai, obtenu {describe(value)}`, 2)
	end
end

function TestKit.falsy(value: any, label: string?)
	if value then
		error(`{label or "condition"} : attendu faux, obtenu {describe(value)}`, 2)
	end
end

function TestKit.summary(): boolean
	print(`\n{passed} test(s) réussi(s), {#failures} échec(s)`)
	for _, failure in failures do
		print(`  ✗ {failure}`)
	end
	return #failures == 0
end

return TestKit
