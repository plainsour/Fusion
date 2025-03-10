--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Breaks down an input table into reactive sub-objects for each pair.
]]

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local depend = require(Package.Graph.depend)
-- State
local castToState = require(Package.State.castToState)
local ForTypes = require(Package.State.For.ForTypes)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)
local deriveScope = require(Package.Memory.deriveScope)
-- Utility
local nameOf = require(Package.Utility.nameOf)
local nicknames = require(Package.Utility.nicknames)

type Self<S, KI, KO, VI, VO> = ForTypes.Disassembly<S, KI, KO, VI, KO> & {
	scope: (S & Types.Scope<unknown>)?,
	_inputTable: Types.UsedAs<{[KI]: VI}>,
	_constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>,
	_subObjects: {[ForTypes.SubObject<S, KI, KO, VI, VO>]: true}
}


local class = {}
class.type = "Graph"
class.kind = "For.Disassembly"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function Disassembly<S, KI, KO, VI, VO>(
	scope: S & Types.Scope<unknown>,
	inputTable: Types.UsedAs<{[KI]: VI}>,
	constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>
): ForTypes.Disassembly<S, KI, KO, VI, KO>
	local createdAt = os.clock()
	local self = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			scope = scope,
			validity = "invalid",
			_inputTable = inputTable,
			_constructor = constructor,
			_subObjects = {}
		}, 
		METATABLE
	) :: any

	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
		for subObject in self._subObjects do
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end
	self.oldestChore = destroy
	nicknames[self.oldestChore] = "For (internal disassembler)"
	table.insert(scope, destroy)

	return self
end

function class.populate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>,
	use: Types.Use,
	output: {[KO]: VO}
): ()
	local minArrayIndex = math.huge
	local maxArrayIndex = -math.huge
	local hasHoles = false
	for subObject in self._subObjects do
		local outputKey, outputValue = subObject:useOutputPair(use)
		if outputKey == nil or outputValue == nil then
			hasHoles = true
			continue
		elseif output[outputKey] ~= nil then
			External.logErrorNonFatal("forKeyCollision", nil, tostring(outputKey))
			continue
		end
		output[outputKey] = outputValue
		if typeof(outputKey) == "number" then
			minArrayIndex = math.min(minArrayIndex, outputKey)
			maxArrayIndex = math.max(maxArrayIndex, outputKey)
		end
	end
	-- Be careful of NaN here
	if hasHoles and maxArrayIndex > minArrayIndex then
		local output: {[number]: VO} = output :: any
		local moveToIndex = minArrayIndex
		for moveFromIndex = minArrayIndex, maxArrayIndex do
			local outputValue = output[moveFromIndex]
			if outputValue == nil then
				continue
			end
			-- The ordering is important in case the indices are the same
			output[moveFromIndex] = nil
			output[moveToIndex] = outputValue
			moveToIndex += 1
		end
	end
end

function class._evaluate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>
): boolean
	local outerScope = self.scope :: S & Types.Scope<unknown>
	local inputState = castToState(self._inputTable)
	local inputTable: {[KI]: VI}
	if inputState ~= nil then
		if inputState.scope == nil then
			External.logError(
				"useAfterDestroy",
				nil,
				`The input {nameOf(inputState, "table")}`,
				`the For object that is watching it`
			)
		end
		inputTable = depend(self, inputState) :: {[KI]: VI}
	else
		inputTable = self._inputTable :: {[KI]: VI}
	end

	local pendingPairs = {} :: {[KI]: VI}
	for key, value in inputTable do
		pendingPairs[key] = value
	end

	local unmatchedPairs = {} :: {ForTypes.SubObject<S, KI, KO, VI, VO>}
	local newSubObjects = {} :: typeof(self._subObjects)

	for subObject in self._subObjects do
		local oldInputKey = subObject.inputKey
		local oldInputValue = subObject.inputValue
		local newInputKey: KI, newInputValue: VI

		-- Reuse when the keys are identical.
		if not subObject.roamKeys and pendingPairs[oldInputKey] ~= nil then
			newInputKey, newInputValue = oldInputKey, pendingPairs[oldInputKey]
		else -- Try and reuse some other pair instead.
			if subObject.roamValues then
				table.insert(unmatchedPairs, subObject)
				continue
			else
				for pendingKey, pendingValue in pendingPairs do
					if pendingValue == oldInputValue then
						-- If the values are the same, then no need to update those,
						-- so prefer this choice to any other.
						newInputKey, newInputValue = pendingKey, pendingValue
						break 
					end
				end
				if not newInputKey then
					table.insert(unmatchedPairs, subObject)
					continue
				end
			end
		end

		newSubObjects[subObject] = true
		if newInputKey ~= oldInputKey then
			subObject.inputKey = newInputKey
			subObject:invalidateInputKey()
		end
		if newInputValue ~= oldInputValue then
			subObject.inputValue = newInputValue
			subObject:invalidateInputValue()
		end
		pendingPairs[newInputKey] = nil
	end

	for _, subObject in unmatchedPairs do
		local oldInputKey = subObject.inputKey
		local oldInputValue = subObject.inputValue
		local newInputKey: KI?, newInputValue: VI? = next(pendingPairs)
		if newInputKey then
			newSubObjects[subObject] = true
			if newInputKey ~= oldInputKey then
				subObject.inputKey = newInputKey :: KI
				subObject:invalidateInputKey()
			end
			if newInputValue ~= oldInputValue then
				subObject.inputValue = newInputValue :: VI
				subObject:invalidateInputValue()
			end
			pendingPairs[newInputKey] = nil
		else
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end
	-- Generate new objects if needed to cover the remaining pending pairs.
	for pendingKey, pendingValue in pendingPairs do
		local subObject = self._constructor(deriveScope(outerScope), pendingKey, pendingValue)
		newSubObjects[subObject] = true
	end

	self._subObjects = newSubObjects

	return true
end

table.freeze(class)
return Disassembly