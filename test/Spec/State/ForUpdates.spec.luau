--!strict
--!nolint LocalUnused
local task = nil -- Disable usage of Roblox's task scheduler

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = ReplicatedStorage.Fusion

local ForKeys = require(Fusion.State.ForKeys)
local ForPairs = require(Fusion.State.ForPairs)
local ForValues = require(Fusion.State.ForValues)
local Value = require(Fusion.State.Value)
local peek = require(Fusion.State.peek)
local doCleanup = require(Fusion.Memory.doCleanup)

return function()
	local it = getfenv().it

	it("updates a single item when its inner state changes", function()
		local expect = getfenv().expect

		local scope = {}
		local multipliers = {Value(scope, 1), Value(scope, 1), Value(scope, 1)}
		local forValues = ForValues(scope, {1, 2, 3}, function(use, _, value)
			return value * use(multipliers[value])
		end)
		expect(peek(forValues)[2]).to.equal(2)
		multipliers[2]:set(10)
		local output = peek(forValues)
		expect(output[1]).to.equal(1)
		expect(output[2]).to.equal(20)
		expect(output[3]).to.equal(3)
		multipliers[3]:set(5)
		multipliers[1]:set(7)
		output = peek(forValues)
		expect(output[1]).to.equal(7)
		expect(output[2]).to.equal(20)
		expect(output[3]).to.equal(15)
		doCleanup(scope)
	end)

	it("compacts the array when an item starts returning nil", function()
		local expect = getfenv().expect

		local scope = {}
		local omit = Value(scope, false)
		local forValues = ForValues(scope, {"a", "b", "c"}, function(use, _, value)
			if value == "b" and use(omit) then
				return nil
			end
			return value
		end)
		expect(#peek(forValues)).to.equal(3)
		omit:set(true)
		local output = peek(forValues)
		expect(#output).to.equal(2)
		expect(table.find(output, "b")).to.equal(nil)
		omit:set(false)
		output = peek(forValues)
		expect(#output).to.equal(3)
		expect(table.find(output, "b")).never.to.equal(nil)
		doCleanup(scope)
	end)

	it("moves an item when its output key changes", function()
		local expect = getfenv().expect

		local scope = {}
		local prefix = Value(scope, "x")
		local forPairs = ForPairs(scope, {a = 1, b = 2}, function(use, _, key, value)
			if key == "a" then
				return use(prefix) .. key, value
			end
			return key, value
		end)
		expect(peek(forPairs).xa).to.equal(1)
		prefix:set("y")
		local output = peek(forPairs)
		expect(output.xa).to.equal(nil)
		expect(output.ya).to.equal(1)
		expect(output.b).to.equal(2)
		doCleanup(scope)
	end)

	it("updates ForKeys values when only the input values change", function()
		local expect = getfenv().expect

		local scope = {}
		local data = Value(scope, {a = 1, b = 2})
		local forKeys = ForKeys(scope, data, function(_, _, key)
			return string.upper(key)
		end)
		expect(peek(forKeys).A).to.equal(1)
		data:set({a = 10, b = 2})
		local output = peek(forKeys)
		expect(output.A).to.equal(10)
		expect(output.B).to.equal(2)
		doCleanup(scope)
	end)

	it("updates ForValues outputs when values change in place", function()
		local expect = getfenv().expect

		local scope = {}
		local data = Value(scope, {1, 2, 3, 4})
		local computations = 0
		local forValues = ForValues(scope, data, function(_, _, value)
			computations += 1
			return value * 10
		end)
		peek(forValues)
		expect(computations).to.equal(4)
		data:set({1, 2, 99, 4})
		local output = peek(forValues)
		expect(computations).to.equal(5)
		expect(output[1]).to.equal(10)
		expect(output[2]).to.equal(20)
		expect(output[3]).to.equal(990)
		expect(output[4]).to.equal(40)
		data:set({1, 2})
		output = peek(forValues)
		expect(#output).to.equal(2)
		expect(output[3]).to.equal(nil)
		doCleanup(scope)
	end)

	it("keeps depending on items that didn't change", function()
		local expect = getfenv().expect

		local scope = {}
		local first = Value(scope, 1)
		local second = Value(scope, 2)
		local states = {first, second}
		local forValues = ForValues(scope, {1, 2}, function(use, _, index)
			return use(states[index])
		end)
		peek(forValues)
		second:set(20)
		expect(peek(forValues)[2]).to.equal(20)
		first:set(10)
		expect(peek(forValues)[1]).to.equal(10)
		second:set(200)
		expect(peek(forValues)[2]).to.equal(200)
		doCleanup(scope)
	end)
end
