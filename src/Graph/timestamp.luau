--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns the current `os.clock()` time, nudged forward when needed so that
	every call returns a strictly larger value than the last.
]]

local STEP = 1e-9

local lastTimestamp = -math.huge

local function timestamp(): number
	local now = os.clock()
	if now <= lastTimestamp then
		now = lastTimestamp + STEP
	end
	lastTimestamp = now
	return now
end

return timestamp
