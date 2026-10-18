--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = ReplicatedStorage.Fusion

local External = require(Fusion.External)
local Types = require(Fusion.Types)

local SpecExternal = {}

SpecExternal.policies = {
	allowWebLinks = true
}

type QueuedChore = {
	thread: thread,
	args: {n: number, [number]: any}
}

local queue = {} :: {QueuedChore}

local function queueEntry(
	thread: thread,
	...: any
): QueuedChore
	return {thread = thread, args = table.pack(...)}
end

--[[
	Runs a chore immediately: the chore is resumed next, and the calling thread
	continues straight after it. Must be called from a thread being run by
	`SpecExternal.step`.
]]
function SpecExternal.doChoreImmediate(
	resume: (...any) -> (),
	...: any
)
	table.insert(queue, 1, queueEntry(coroutine.running()))
	table.insert(queue, 1, queueEntry(coroutine.create(resume), ...))
	coroutine.yield()
end

--[[
	Queues a chore to run after everything currently queued.
]]
function SpecExternal.doChoreDeferred(
	resume: (...any) -> (),
	...: any
)
	table.insert(queue, queueEntry(coroutine.create(resume), ...))
end

function SpecExternal.deferSelfForTesting()
	table.insert(queue, queueEntry(coroutine.running()))
	coroutine.yield()
end

--[[
	Errors in a different thread to preserve the flow of execution.
]]
function SpecExternal.logErrorNonFatal(
	errorString: string
): ()
	-- silently discard
end

--[[
	Shows a warning message in the output.
]]
function SpecExternal.logWarn(
	errorString: string
): ()
	-- silently discard
end

local doUpdateSteps = false

--[[
	Enables update steps from `SpecExternal.step`.
]]
function SpecExternal.startScheduler()
	doUpdateSteps = true
end

--[[
	Disables update steps from `SpecExternal.step`.
]]
function SpecExternal.stopScheduler()
	doUpdateSteps = false
end

--[[
	Performs an update step at the given time (if the scheduler is running),
	then runs queued chores until the queue is empty.
]]
function SpecExternal.step(
	currentTime: number
)
	if doUpdateSteps then
		External.performUpdateStep(currentTime)
	end

	while true do
		local nextChore = table.remove(queue, 1)
		if nextChore == nil then
			break
		end
		local args = nextChore.args
		local ok, result = coroutine.resume(nextChore.thread, table.unpack(args, 1, args.n))
		if not ok then
			warn("Error in spec scheduler: " .. tostring(result))
		end
	end
end

local _typecheck: Types.ExternalProvider = SpecExternal

return SpecExternal
