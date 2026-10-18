--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	The generic implementation for all `For` objects.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
-- Graph
local timestamp = require(Package.Graph.timestamp)
local depend = require(Package.Graph.depend)
-- State
local ForTypes = require(Package.State.For.ForTypes)
-- Utility
local nicknames = require(Package.Utility.nicknames)

local Disassembly = require(Package.State.For.Disassembly)

type Self<S, KI, KO, VI, VO> = Types.For<KO, VO> & {
	_disassembly: ForTypes.Disassembly<S, KI, KO, VI, VO>,
	_canPatch: boolean
}

local class = {}
class.type = "State"
class.kind = "For"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function For<S, KI, KO, VI, VO>(
	scope: Types.Scope<S>,
	inputTable: Types.UsedAs<{[KI]: VI}>,
	constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>
): Types.For<KO, VO>
	local createdAt = timestamp()
	local self: Self<S, KI, KO, VI, VO> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = {},
			_canPatch = false,
			_disassembly = Disassembly(
				scope,
				inputTable,
				constructor
			)
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
	nicknames[self.oldestChore] = "For"
	table.insert(scope, destroy)

	return self
end

function class._evaluate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>
): boolean
	if self.scope == nil then
		return false
	end

	local disassembly = self._disassembly
	local since = self.lastChange
	local output = self._EXTREMELY_DANGEROUS_usedAsValue
	local function use<T>(
		maybeState: Types.UsedAs<T>
	): T
		return depend(self, maybeState)
	end
	depend(self, disassembly)
	if
		since ~= nil and
		self._canPatch and
		not disassembly._membershipChanged and
		disassembly:patch(use, output)
	then
		return true
	end
	table.clear(output)
	self._canPatch = disassembly:populate(use, output)
	disassembly._membershipChanged = false

	return true
end

table.freeze(class)
return For
