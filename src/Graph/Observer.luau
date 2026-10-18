--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A graph object that runs user code when it's updated by the reactive graph.

	https://elttob.uk/Fusion/0.3/api-reference/state/types/observer/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local timestamp = require(Package.Graph.timestamp)
local castToGraph = require(Package.Graph.castToGraph)
local depend = require(Package.Graph.depend)
local evaluate = require(Package.Graph.evaluate)
local peek = require(Package.State.peek)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type Self = Types.Observer<any> & {
	_watching: unknown,
	_watchingGraph: Types.GraphObject?,
	_changeListeners: {[unknown]: Types.ObserverCallback<any>}
}

local class = {}
class.type = "Observer"
class.timeliness = "eager"
class.dependentSet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local function Observer(
	scope: Types.Scope<unknown>,
	watching: unknown
): Types.Observer<any>
	local createdAt = timestamp()

	local self: Self = setmetatable(
		{
			scope = scope,
			createdAt = createdAt,
			dependencySet = {},
			lastChange = nil,
			validity = "invalid",
			_watching = watching,
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
	callback: Types.ObserverCallback<any>
): () -> ()
	External.doChoreImmediate(callback, peek(self._watching))
	return self:onChange(callback)
end

function class.onChange(
	self: Self,
	callback: Types.ObserverCallback<any>
): () -> ()
	local uniqueIdentifier = table.freeze {}
	self._changeListeners[uniqueIdentifier] = callback
	return function()
		self._changeListeners[uniqueIdentifier] = nil
	end
end

function class._evaluate(
	self: Self
): boolean
	local value = depend(self, self._watching)
	local listeners = self._changeListeners :: {[any]: Types.ObserverCallback<any>}
	local firstID, firstCallback = next(listeners)
	if firstID == nil then
		return true
	elseif next(listeners, firstID) == nil then
		External.doChoreImmediate(firstCallback, value)
		return true
	end
	for id, callback in table.clone(listeners) do
		if listeners[id] == callback then
			External.doChoreImmediate(callback, value)
		end
	end
	return true
end

table.freeze(class)
return Observer :: Types.ObserverConstructor
