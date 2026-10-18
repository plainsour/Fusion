local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = ReplicatedStorage.Fusion
local External = require(Fusion.External)
local Value = require(Fusion.State.Value)
local Computed = require(Fusion.State.Computed)
local ForValues = require(Fusion.State.ForValues)
local ForPairs = require(Fusion.State.ForPairs)
local peek = require(Fusion.State.peek)
local Observer = require(Fusion.Graph.Observer)
local Spring = require(Fusion.Animation.Spring)
local Tween = require(Fusion.Animation.Tween)
local doCleanup = require(Fusion.Memory.doCleanup)
local scoped = require(Fusion.Memory.scoped)
local innerScope = require(Fusion.Memory.innerScope)
local deriveScope = require(Fusion.Memory.deriveScope)
local detach = require(Fusion.Memory.detach)
local formatError = require(Fusion.Logging.formatError)
local parseError = require(Fusion.Logging.parseError)
local ExternalDebug = require(Fusion.ExternalDebug)
local change = require(Fusion.Graph.change)

local function withCapturedErrors(fn)
	local captured = {}
	local provider = {
		policies = {allowWebLinks = false},
		logErrorNonFatal = function(s) table.insert(captured, s) end,
		logWarn = function(s) table.insert(captured, s) end,
		doChoreImmediate = function(f, ...) task.spawn(f, ...) end,
		doChoreDeferred = function(f, ...) end,
		startScheduler = function() end, stopScheduler = function() end,
	}
	local old = External.setExternalProvider(provider)
	local ok, err = pcall(fn)
	External.setExternalProvider(old)
	if not ok then error(err, 0) end
	return captured
end

return function()
	local it = getfenv().it

	it("spring keeps non-animatable goals instead of becoming nil", function()
		local expect = getfenv().expect
		local scope = {}
		local goal = Value(scope, "hello")
		local spring = Spring(scope, goal)
		for i = 1, 5 do External.performUpdateStep(100 + i / 60) end
		expect(peek(spring)).to.equal("hello")
		goal:set("world")
		for i = 6, 10 do External.performUpdateStep(100 + i / 60) end
		expect(peek(spring)).to.equal("world")
		doCleanup(scope)
	end)

	it("spring rejects negative / mistyped speed without NaN", function()
		local expect = getfenv().expect
		local errors = withCapturedErrors(function()
			local scope = {}
			local goal = Value(scope, 0)
			local speed = Value(scope, -5)
			local spring = Spring(scope, goal, speed)
			goal:set(10)
			for i = 1, 30 do External.performUpdateStep(200 + i / 60) end
			local v = peek(spring)
			expect(v == v).to.equal(true)
			speed:set("fast")
			goal:set(20)
			for i = 31, 60 do External.performUpdateStep(200 + i / 60) end
			expect(peek(spring) == peek(spring)).to.equal(true)
			doCleanup(scope)
		end)
		local joined = table.concat(errors, "\n")
		expect(string.find(joined, "invalidSpringSpeed", 1, true) ~= nil).to.equal(true)
		expect(string.find(joined, "mistypedSpringSpeed", 1, true) ~= nil).to.equal(true)
	end)

	it("spring methods on constant goals warn instead of erroring", function()
		local expect = getfenv().expect
		local errors = withCapturedErrors(function()
			local scope = {}
			local spring = Spring(scope, 5)
			spring:setPosition(3)
			spring:addVelocity(1)
			spring:setVelocity(nil)
			expect(peek(spring)).to.equal(5)
			doCleanup(scope)
		end)
		expect(string.find(table.concat(errors), "springConstantGoal", 1, true) ~= nil).to.equal(true)
	end)

	it("tween with a nil goal doesn't break", function()
		local expect = getfenv().expect
		local scope = {}
		local goal = Value(scope, nil)
		local tween = Tween(scope, goal)
		expect(peek(tween)).to.equal(nil)
		goal:set(5)
		External.performUpdateStep(300)
		expect(function() peek(tween) end).never.to.throw()
		doCleanup(scope)
	end)

	it("tween with a mistyped tween info logs and keeps working", function()
		local expect = getfenv().expect
		local errors = withCapturedErrors(function()
			local scope = {}
			local goal = Value(scope, 1)
			local tween = Tween(scope, goal, Value(scope, "nope"))
			goal:set(2)
			External.performUpdateStep(400)
			expect(function() peek(tween) end).never.to.throw()
			doCleanup(scope)
		end)
		expect(string.find(table.concat(errors), "mistypedTweenInfo", 1, true) ~= nil).to.equal(true)
	end)

	it("detach removes table chores as a whole", function()
		local expect = getfenv().expect
		local scope = scoped()
		local inner = innerScope(scope)
		local obj = {destroy = function() end}
		table.insert(scope, obj)
		detach(scope, inner, obj)
		expect(table.find(scope, inner)).to.equal(nil)
		expect(table.find(scope, obj)).to.equal(nil)
		local a, b = function() end, function() end
		table.insert(scope, a); table.insert(scope, b)
		detach(scope, {a, b})
		expect(#scope).to.equal(0)
	end)

	it("doCleanup keeps going after a failing chore and can run again", function()
		local expect = getfenv().expect
		local ran = {}
		local scope = {
			function() table.insert(ran, 1) end,
			function() error("boom", 0) end,
			function() table.insert(ran, 3) end,
		}
		expect(function() doCleanup(scope) end).to.throw("boom")
		expect(#ran).to.equal(2)
		expect(function() doCleanup(scope) end).never.to.throw()
	end)

	it("errors inside evaluation don't leave objects stuck busy", function()
		local expect = getfenv().expect
		local scope = {}
		local input = Value(scope, 5 :: any)
		local forValues = ForValues(scope, input, function(_, _, v) return v end)
		local ok1, err1 = pcall(peek, forValues)
		local ok2, err2 = pcall(peek, forValues)
		expect(ok1).to.equal(false)
		expect(ok2).to.equal(false)
		expect(string.find(tostring(err2), "infiniteLoop", 1, true)).to.equal(nil)
		input:set({1, 2})
		expect(peek(forValues)[2]).to.equal(2)
		doCleanup(scope)
	end)

	it("formatError tolerates % in error messages", function()
		local expect = getfenv().expect
		local errObj = parseError("100% broken")
		local s = formatError(nil, "callbackError", errObj)
		expect(string.find(s, "100% broken", 1, true) ~= nil).to.equal(true)
		expect(select("#", formatError(nil, "callbackError", errObj))).to.equal(1)
	end)

	it("parseError handles non-string errors", function()
		local expect = getfenv().expect
		expect(function() parseError({} :: any) end).never.to.throw()
		expect(function() parseError(nil :: any) end).never.to.throw()
	end)

	it("ForPairs error context names the key", function()
		local expect = getfenv().expect
		local errors = withCapturedErrors(function()
			local scope = {}
			local f = ForPairs(scope, {mykey = "myvalue"}, function() error("fail") end)
			peek(f)
			doCleanup(scope)
		end)
		local joined = table.concat(errors, "\n")
		expect(string.find(joined, "key mykey and value myvalue", 1, true) ~= nil).to.equal(true)
	end)

	it("Observer passes constants to onBind", function()
		local expect = getfenv().expect
		local scope = {}
		local got
		Observer(scope, 5):onBind(function(v) got = v end)
		expect(got).to.equal(5)
		doCleanup(scope)
	end)

	it("Observer tolerates listeners connecting during callbacks", function()
		local expect = getfenv().expect
		local scope = {}
		local v = Value(scope, 1)
		local obs = Observer(scope, v)
		local fires = 0
		obs:onChange(function()
			fires += 1
			for _ = 1, 20 do obs:onChange(function() end) end
		end)
		expect(function() v:set(2) end).never.to.throw()
		expect(fires).to.equal(1)
		doCleanup(scope)
	end)

	it("ForValues compacts omitted first items to start at 1", function()
		local expect = getfenv().expect
		local scope = {}
		local f = ForValues(scope, {"a", "b", "c"}, function(_, _, v) return if v == "a" then nil else v end)
		local out = peek(f)
		expect(out[1]).to.equal("b")
		expect(out[2]).to.equal("c")
		expect(out[3]).to.equal(nil)
		local g = ForValues(scope, {"a", "b"}, function(_, _, v) return if v == "a" then nil else v end)
		expect(peek(g)[1]).to.equal("b")
		doCleanup(scope)
	end)

	it("change() handles deep diamond graphs quickly", function()
		local expect = getfenv().expect
		local scope = {}
		local root = Value(scope, 0)
		local prev = root
		for _ = 1, 24 do
			local p = prev
			local l = Computed(scope, function(use) return use(p) + 1 end)
			local r = Computed(scope, function(use) return use(p) + 1 end)
			prev = Computed(scope, function(use) return use(l) + use(r) end)
		end
		peek(prev)
		local t = os.clock()
		expect(function() root:set(1) end).never.to.throw()
		expect(os.clock() - t < 0.5).to.equal(true)
		doCleanup(scope)
	end)

	it("untrackScope reaches the debugger as untrack", function()
		local expect = getfenv().expect
		local calls = {}
		ExternalDebug.setDebugger({
			startDebugging = function() end, stopDebugging = function() end,
			trackScope = function() table.insert(calls, "track") end,
			untrackScope = function() table.insert(calls, "untrack") end,
		})
		local scope = scoped()
		doCleanup(scope)
		ExternalDebug.setDebugger(nil)
		expect(calls[1]).to.equal("track")
		expect(calls[2]).to.equal("untrack")
	end)

	it("deriveScope works on plain table scopes with methods", function()
		local expect = getfenv().expect
		local derived = deriveScope({}, {foo = 1})
		expect(derived.foo).to.equal(1)
	end)

	it("NumberRange tweens and springs survive overshooting", function()
		local expect = getfenv().expect
		local lerpType = require(Fusion.Animation.lerpType)
		local packType = require(Fusion.Animation.packType)
		local range = lerpType(NumberRange.new(0, 10), NumberRange.new(0, 0), 1.1)
		expect(range.Min <= range.Max).to.equal(true)
		local packed = packType({0, -1}, "NumberRange")
		expect(packed.Min).to.equal(-1)
		expect(packed.Max).to.equal(0)
	end)

	it("isSimilar doesn't treat every NaN value as similar", function()
		local expect = getfenv().expect
		local isSimilar = require(Fusion.Utility.isSimilar)
		expect(isSimilar(0 / 0, Vector3.new(0 / 0, 0, 0))).to.equal(false)
		expect(isSimilar(Vector3.new(0 / 0, 0, 0), Vector3.new(0 / 0, 5, 5))).to.equal(false)
		expect(isSimilar(Vector3.new(0 / 0, 5, 5), Vector3.new(0 / 0, 5, 5))).to.equal(true)
		expect(isSimilar(CFrame.new(0 / 0, 1, 2), CFrame.new(0 / 0, 1, 3))).to.equal(false)
		local scope = {}
		local value = Value(scope, Vector3.new(0 / 0, 0, 0))
		value:set(Vector3.new(0 / 0, 5, 5))
		expect(peek(value).Y).to.equal(5)
		doCleanup(scope)
	end)
end
