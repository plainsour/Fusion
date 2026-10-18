--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Given a `tweenInfo` and `currentTime`, returns a ratio which can be used to
	tween between two values over time.
]]

local TweenService = game:GetService("TweenService")

type TweenFields = {
	delay: number,
	duration: number,
	reverses: boolean,
	repeatCount: number,
	easeStyle: Enum.EasingStyle,
	easeDirection: Enum.EasingDirection
}

local fieldCache: {[TweenInfo]: TweenFields} = setmetatable({}, {__mode = "k"}) :: any

local function getFields(
	tweenInfo: TweenInfo
): TweenFields
	local fields = fieldCache[tweenInfo]
	if fields == nil then
		fields = {
			delay = tweenInfo.DelayTime,
			duration = tweenInfo.Time,
			reverses = tweenInfo.Reverses,
			repeatCount = tweenInfo.RepeatCount,
			easeStyle = tweenInfo.EasingStyle,
			easeDirection = tweenInfo.EasingDirection
		}
		fieldCache[tweenInfo] = fields
	end
	return fields :: TweenFields
end

local function getTweenRatio(
	tweenInfo: TweenInfo,
	currentTime: number
): number
	local fields = getFields(tweenInfo)
	local delay = fields.delay
	local duration = fields.duration
	local reverses = fields.reverses
	local numCycles = 1 + fields.repeatCount
	local easeStyle = fields.easeStyle
	local easeDirection = fields.easeDirection
	local cycleDuration = delay + duration
	if reverses then
		cycleDuration += duration
	end
	-- If currentTime is infinity, then presumably the tween should be over.
	-- This avoids NaN when the duration of an infinitely repeating tween is given.
	if currentTime == math.huge then
		return 1
	end
	if currentTime >= cycleDuration * numCycles and fields.repeatCount > -1 then
		return 1
	end
	local cycleTime = currentTime % cycleDuration
	if cycleTime <= delay then
		return 0
	end
	local tweenProgress = (cycleTime - delay) / duration
	if tweenProgress > 1 then
		tweenProgress = 2 - tweenProgress
	end
	local ratio = TweenService:GetValue(tweenProgress, easeStyle, easeDirection)
	return ratio
end

return getTweenRatio
