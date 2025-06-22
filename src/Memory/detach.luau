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
        local chore = table.find(scope, select(i, ...))
        if chore then
            table.remove(scope, chore)
        end
    end
    return ...
end

return detach