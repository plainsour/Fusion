--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Outputs the current external time as a state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local timestamp = require(Package.Graph.timestamp)
local change = require(Package.Graph.change)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type ExternalTime = Types.StateObject<number>

type Self = ExternalTime

local class = {}
class.type = "State"
class.kind = "ExternalTime"
class.timeliness = "lazy"
class.dependencySet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local allTimers: {Self} = {}
local deadTimers = 0
local updateDepth = 0

local function compactTimers(): ()
	local write = 0
	for read = 1, #allTimers do
		local timer = allTimers[read]
		if timer.scope ~= nil then
			write += 1
			allTimers[write] = timer
		end
	end
	for index = #allTimers, write + 1, -1 do
		allTimers[index] = nil
	end
	deadTimers = 0
end

local function ExternalTime(
	scope: Types.Scope<unknown>
): ExternalTime
	local createdAt = timestamp()
	local self: Self = setmetatable(
		{
			createdAt = createdAt,
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep(),
		},
		METATABLE
	) :: any
	local destroy = function()
		if self.scope == nil then
			return
		end
		self.scope = nil
		deadTimers += 1
		if updateDepth == 0 and deadTimers * 2 > #allTimers then
			compactTimers()
		end
	end
	self.oldestChore = destroy
	nicknames[self.oldestChore] = "ExternalTime"
	table.insert(scope, destroy)
	table.insert(allTimers, self)
	return self
end

function class._evaluate(
	self: Self
): boolean
	-- While someone else could call `change()` on this object, it wouldn't be
	-- idiomatic. So, since the only idiomatic time this function runs is when
	-- the external update step runs, it's safe enough to assume that the result
	-- has always meaningfully changed. The worst that can happen is unexpected
	-- refreshing for people doing unorthodox shenanigans, which is an OK trade.
	self._EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep()
	return true
end

local function changeAllTimers(): ()
	local index = 1
	while index <= #allTimers do
		local timer = allTimers[index]
		if timer.scope == nil then
			index += 1
			continue
		elseif next(timer.dependentSet) == nil then
			timer._EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep()
			timer.lastChange = timestamp()
			timer.validity = "valid"
		else
			change(timer)
		end
		index += 1
	end
end

External.bindToUpdateStep(function(
	externalNow: number
): ()
	updateDepth += 1
	local ok, err = pcall(changeAllTimers)
	updateDepth -= 1
	if updateDepth == 0 and deadTimers > 0 then
		compactTimers()
	end
	if not ok then
		error(err, 0)
	end
end)

table.freeze(class)
return ExternalTime
