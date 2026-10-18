--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Package = ReplicatedStorage.Fusion
local Fusion = require(Package)

local timestamp = require(Package.Graph.timestamp)

return function()
	local it = getfenv().it

	it("should always increase", function()
		local expect = getfenv().expect

		local last = timestamp()
		for _ = 1, 10000 do
			local now = timestamp()
			expect(now > last).to.equal(true)
			last = now
		end
	end)

	it("should stay close to os.clock()", function()
		local expect = getfenv().expect

		expect(timestamp()).to.be.near(os.clock(), 0.01)
	end)

	it("should give distinct change times to values set back to back", function()
		local expect = getfenv().expect

		local scope = Fusion.scoped(Fusion)
		local a = scope:Value(0)
		local b = scope:Value(0)
		a:set(1)
		b:set(1)
		expect(b.lastChange > a.lastChange).to.equal(true)
		Fusion.doCleanup(scope)
	end)
end
