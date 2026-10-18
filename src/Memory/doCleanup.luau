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
	- a table with a `destroy`, `Destroy`, `disconnect` or `Disconnect` function
	  will be called
	- an array - `doCleanup` will be called on each item, in reverse order
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local ExternalDebug = require(Package.ExternalDebug)

local alreadyDestroying: {[Types.Chore]: true} = {}

local doCleanup: (Types.Chore) -> ()

local function cleanupChore(
	chore: Types.Chore
): ()
	local choreType = typeof(chore)
	-- case 1: Instance
	if choreType == "Instance" then
		chore:Destroy()

	-- case 2: RBXScriptConnection
	elseif choreType == "RBXScriptConnection" then
		chore:Disconnect()

	-- case 3: thread
	elseif choreType == "thread" and typeof(task) ~= "table" then
		if coroutine.running() ~= chore then
			pcall(coroutine.close, chore)
		end

	elseif choreType == "thread" then
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
	elseif choreType == "function" then
		chore()

	elseif choreType == "table" then
		local chore = (chore :: any) :: {
			destroy: (...unknown) -> (...unknown)?,
			Destroy: (...unknown) -> (...unknown)?,
			disconnect: (...unknown) -> (...unknown)?,
			Disconnect: (...unknown) -> (...unknown)?,
		}

		-- case 5: destroy() function
		if typeof(chore.destroy) == "function" then
			local chore = (chore :: any) :: {destroy: (...unknown) -> (...unknown)}
			chore:destroy()

		-- case 6: Destroy() function
		elseif typeof(chore.Destroy) == "function" then
			local chore = (chore :: any) :: {Destroy: (...unknown) -> (...unknown)}
			chore:Destroy()

		-- case 7: disconnect() function
		elseif typeof(chore.disconnect) == "function" then
			local chore = (chore :: any) :: {disconnect: (...unknown) -> (...unknown)}
			chore:disconnect()

		-- case 8: Disconnect() function
		elseif typeof(chore.Disconnect) == "function" then
			local chore = (chore :: any) :: {Disconnect: (...unknown) -> (...unknown)}
			chore:Disconnect()

		-- case 9: table of chores (including empty scopes)
		else
			local chore = chore :: {Types.Chore}

			-- It is important to iterate backwards through the table, since
			-- objects are added in order of construction.
			local firstError: unknown = nil
			local index = #chore
			while index > 0 do
				local item = chore[index]
				chore[index] = nil
				if item ~= nil then
					local ok, err = pcall(doCleanup, item)
					if not ok and firstError == nil then
						firstError = err
					end
				end
				index = math.min(index - 1, #chore)
			end

			ExternalDebug.untrackScope(chore)

			if firstError ~= nil then
				error(firstError, 0)
			end
		end
	end
end

function doCleanup(
	chore: Types.Chore
): ()
	if alreadyDestroying[chore] then
		return External.logError("destroyedTwice")
	end
	alreadyDestroying[chore] = true

	local ok, err = pcall(cleanupChore, chore)
	alreadyDestroying[chore] = nil
	if not ok then
		error(err, 0)
	end
end

return doCleanup
