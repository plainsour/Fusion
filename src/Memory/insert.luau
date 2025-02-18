--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Inserts clean up chores passed in to the scope.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)

local function insert<Chores...>(
	scope: Types.Scope<unknown>,
	...: Chores...
): Chores...
	for index = 1, select("#", ...) do
		table.insert(scope, select(index, ...))
	end
	return ...
end

return insert