--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Prompts a graph object to re-evaluate its own value. If it meaningfully
	changes, then dependents will have to re-evaluate their own values in the
	future.

	https://fluff.blog/2024/04/16/monotonic-painting.html
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local evaluate = require(Package.Graph.evaluate)

-- How long should this function run before it's considered to be in an infinite
-- cycle and error out?
local TERMINATION_TIME = 1

local function byCreation(
	a: Types.GraphObject,
	b: Types.GraphObject
): boolean
	return a.createdAt < b.createdAt
end

local function change(
	target: Types.GraphObject
): ()
	if target.validity == "busy" then
		return External.logError("infiniteLoop")
	end

	local meaningfullyChanged = evaluate(target, true)
	if not meaningfullyChanged then
		return
	end

	local queue: {Types.GraphObject}? = nil
	for dependent in target.dependentSet do
		if dependent.validity == "valid" then
			dependent.validity = "invalid"
			if queue == nil then
				queue = {dependent}
			else
				table.insert(queue, dependent)
			end
		end
	end
	if queue == nil then
		return
	end
	local queue = queue :: {Types.GraphObject}

	local terminateBy = os.clock() + TERMINATION_TIME * External.safetyTimerMultiplier
	local searchFrom = 1
	repeat
		if os.clock() > terminateBy then
			return External.logError("infiniteLoop")
		end
		local searchTo = #queue
		for index = searchFrom, searchTo do
			for dependent in queue[index].dependentSet do
				if dependent.validity == "valid" then
					dependent.validity = "invalid"
					table.insert(queue, dependent)
				end
			end
		end
		searchFrom = searchTo + 1
	until searchFrom > #queue

	local eagerCount = 0
	for _, invalidateTarget in queue do
		if invalidateTarget.timeliness == "eager" then
			eagerCount += 1
			queue[eagerCount] = invalidateTarget
		end
	end
	for index = #queue, eagerCount + 1, -1 do
		queue[index] = nil
	end

	-- If objects are not executed in order of creations, then dynamic graphs
	-- may experience 'glitches' where nested graph objects see intermediate
	-- values before being destroyed.
	-- https://fluff.blog/2024/07/14/glitches-in-dynamic-reactive-graphs.html
	for index = 2, eagerCount do
		if queue[index - 1].createdAt > queue[index].createdAt then
			table.sort(queue, byCreation)
			break
		end
	end

	for _, eagerTarget in queue do
		evaluate(eagerTarget, false)
	end
end

return change
