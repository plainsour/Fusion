--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Removes clean up chores that were passed to the scope.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)

local function detach<Chores...>(
	scope: Types.Scope<unknown>,
	...: Chores...
): Chores...
	for i = 1, select("#", ...) do
		local chore = select(i, ...)
		for _, v in type(chore) == "table" and chore or {chore} do
			local index = table.find(scope, v)
			if index then
				table.remove(scope, index)
			end
		end
	end
	return ...
end

return detach