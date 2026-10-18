--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Removes clean up chores that were passed to the scope.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)

local function removeFromScope(
	scope: Types.Scope<unknown>,
	chore: unknown
): boolean
	local index = table.find(scope, chore :: any)
	if index == nil then
		return false
	end
	table.remove(scope, index)
	return true
end

local function detach<Chores...>(
	scope: Types.Scope<unknown>,
	...: Chores...
): Chores...
	for i = 1, select("#", ...) do
		local chore = select(i, ...)
		if not removeFromScope(scope, chore) and type(chore) == "table" then
			for _, item in chore :: {[unknown]: unknown} do
				removeFromScope(scope, item)
			end
		end
	end
	return ...
end

return detach
