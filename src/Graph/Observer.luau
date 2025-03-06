--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A graph object that runs user code when it's updated by the reactive graph.

	http://elttob.uk/Fusion/0.3/api-reference/state/types/observer/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local castToGraph = require(Package.Graph.castToGraph)
local depend = require(Package.Graph.depend)
local evaluate = require(Package.Graph.evaluate)
local peek = require(Package.State.peek)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type Self = Types.Observer & {
	_watchingGraph: Types.GraphObject?,
	_changeListeners: {[unknown]: (peekedValue: any) -> ()}
}

local class = {}
class.type = "Observer"
class.timeliness = "eager"
class.dependentSet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local function Observer(
	scope: Types.Scope<unknown>,
	watching: unknown
): Types.Observer
	local createdAt = os.clock()

	local self: Self = setmetatable(
		{
			scope = scope,
			createdAt = createdAt,
			dependencySet = {},
			lastChange = nil,
			validity = "invalid",
			_watchingGraph = castToGraph(watching),
			_changeListeners = {}
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestChore = destroy
	nicknames[self.oldestChore] = "Observer"
	table.insert(scope, destroy)

	if self._watchingGraph ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestChore,
			self._watchingGraph.scope, self._watchingGraph.oldestChore,
			checkLifetime.formatters.observer
		)
	end

	-- Eagerly evaluated objects need to evaluate themselves so that they're
	-- valid at all times.
	evaluate(self, true)

	return self
end

function class.onBind(
	self: Self,
	callback: (peekedValue: any) -> ()
): () -> ()
	External.doChoreImmediate(callback)
	return self:onChange(callback)
end

function class.onChange(
	self: Self,
	callback: (peekedValue: any) -> ()
): () -> ()
	local uniqueIdentifier = table.freeze {}
	self._changeListeners[uniqueIdentifier] = callback
	return function()
		self._changeListeners[uniqueIdentifier] = nil
	end
end

function class._evaluate(
	self: Self
): ()
	for _, callback in self._changeListeners do
		External.doChoreImmediate(callback)
	end
	return true
end

table.freeze(class)
return Observer :: Types.ObserverConstructor