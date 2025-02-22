--!strict
--!nolint LocalUnused
--!nolint LocalShadow

--[[
	Cleans up the chores passed in as the arguments.
	A chore can be any of the following:

	- an Instance - will be destroyed
	- an RBXScriptConnection - will be disconnected
	- a thread - will be handled
	- a function - will be run
	- a table with a `Destroy` or `destroy` function - will be called
	- an array - `cleanup` will be called on each item
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local ExternalDebug = require(Package.ExternalDebug)

local alreadyDestroying: {[Types.Chore]: true} = {}

local function doCleanup(
	chore: Types.Chore
): ()
	if alreadyDestroying[chore] then
		return External.logError("destroyedTwice")
	end
	alreadyDestroying[chore] = true

	-- case 1: Instance
	if typeof(chore) == "Instance" then
		chore:Destroy()

	-- case 2: RBXScriptConnection
	elseif typeof(chore) == "RBXScriptConnection" then
		chore:Disconnect()

	-- case 3: thread
	-- TODO: This was added as a bandaid patch for cleaning up threads in Roblox.
	-- This will not work in other environments and should ideally be updated to handle
	-- coroutines and Roblox threads separately.
	elseif typeof(chore) == "thread" then
		local cancelled
		if coroutine.running() ~= chore then
			cancelled = pcall(function()
				task.cancel(chore)
			end)
		end

		if not cancelled then
			local toCancel = chore
			task.defer(function()
				task.cancel(toCancel)
			end)
		end

	-- case 4: callback
	elseif typeof(chore) == "function" then
		chore()

	elseif typeof(chore) == "table" then
		local chore = (chore :: any) :: {Destroy: (...unknown) -> (...unknown)?, destroy: (...unknown) -> (...unknown)?}

		-- case 5: destroy() function
		if typeof(chore.destroy) == "function" then
			local chore = (chore :: any) :: {destroy: (...unknown) -> (...unknown)}
			chore:destroy()

		-- case 6: Destroy() function
		elseif typeof(chore.Destroy) == "function" then
			local chore = (chore :: any) :: {Destroy: (...unknown) -> (...unknown)}
			chore:Destroy()

		-- case 7: table of chores with an array part
		elseif chore[1] ~= nil then
			local chore = chore :: {Types.Chore}

			-- It is important to iterate backwards through the table, since
			-- objects are added in order of construction.
			for index = #chore, 1, -1 do
				doCleanup(chore[index])
				chore[index] = nil
			end

			ExternalDebug.untrackScope(chore)
		end
	end

	alreadyDestroying[chore] = nil
end

return doCleanup