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
	-- case 1: Instance
	if typeof(chore) == "Instance" then
		chore:Destroy()

	-- case 2: RBXScriptConnection
	elseif typeof(chore) == "RBXScriptConnection" then
		chore:Disconnect()

	-- case 3: thread
	elseif typeof(chore) == "thread" and typeof(task) ~= "table" then
		if coroutine.running() ~= chore then
			pcall(coroutine.close, chore)
		end

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
				local nextIndex = index - 1
				if item ~= nil then
					local ok, err
					if type(item) == "table" or item ~= item or alreadyDestroying[item] then
						ok, err = pcall(doCleanup, item)
					else
						alreadyDestroying[item] = true
						ok, err = pcall(cleanupChore, item)
						alreadyDestroying[item] = nil
					end
					if not ok and firstError == nil then
						firstError = err
					end
					if not rawequal(chore[index], item) then
						local position = index - 1
						while position > 0 and chore[position] == nil do
							position -= 1
						end
						if position > 0 and rawequal(chore[position], item) then
							chore[position] = nil
							nextIndex = position - 1
						else
							nextIndex = position
						end
					end
				end
				chore[index] = nil
				index = nextIndex
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
	if type(chore) == "table" and next(chore :: any) == nil then
		local chore = chore :: any
		if
			typeof(chore.destroy) ~= "function" and
			typeof(chore.Destroy) ~= "function" and
			typeof(chore.disconnect) ~= "function" and
			typeof(chore.Disconnect) ~= "function"
		then
			ExternalDebug.untrackScope(chore)
			return
		end
	end
	alreadyDestroying[chore] = true

	local ok, err = pcall(cleanupChore, chore)
	alreadyDestroying[chore] = nil
	if not ok then
		error(err, 0)
	end
end

return doCleanup
