--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Forms a dependency on a graph object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local evaluate = require(Package.Graph.evaluate)
local castToGraph = require(Package.Graph.castToGraph)
local nameOf = require(Package.Utility.nameOf)

local depend = function<T>(
	dependent: Types.GraphObject,
	dependency: Types.UsedAs<T> | Types.GraphObject
): any
	if castToGraph(dependency) then
		local dependency = dependency :: Types.GraphObject
		-- Ensure dependencies are evaluated and up-to-date
		-- when they are depended on. Also, newly created objects
		-- might not have any transitive dependencies captured yet,
		-- so ensure that they're present.
		if dependency.validity ~= "valid" or dependency.lastChange == nil then
			evaluate(dependency, false)
		end

		if table.isfrozen(dependent.dependencySet) or table.isfrozen(dependency.dependentSet) then
			External.logError("cannotDepend", nil, nameOf(dependent, "Dependent"), nameOf(dependency, "dependency"))
		end
		dependency.dependentSet[dependent] = true
		dependent.dependencySet[dependency] = true

		if (dependency :: any).type == "State" then
			return (dependency :: Types.StateObject<T>)._EXTREMELY_DANGEROUS_usedAsValue :: T
		else
			return nil
		end
	end
	return dependency :: T
end :: (<T>(Types.GraphObject, Types.UsedAs<T>) -> T) & ((Types.GraphObject, Types.GraphObject) -> ())

return depend
