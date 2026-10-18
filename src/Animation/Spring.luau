--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A specialised state object for following a goal state smoothly over time,
	using physics to shape the motion.

	https://elttob.uk/Fusion/0.3/api-reference/animation/types/spring/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local timestamp = require(Package.Graph.timestamp)
local depend = require(Package.Graph.depend)
local change = require(Package.Graph.change)
local evaluate = require(Package.Graph.evaluate)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)
-- Animation
local ExternalTime = require(Package.Animation.ExternalTime)
local Stopwatch = require(Package.Animation.Stopwatch)
local packType = require(Package.Animation.packType)
local unpackType = require(Package.Animation.unpackType)
local springCoefficients = require(Package.Animation.springCoefficients)
-- Utility
local nicknames = require(Package.Utility.nicknames)
local isSimilar = require(Package.Utility.isSimilar)

local NOT_REPORTED = table.freeze {}

local EPSILON = 0.00001
local DEFAULT_SPEED = 10
local DEFAULT_DAMPING = 1

type Self<T> = Types.Spring<T> & {
	_activeDamping: number,
	_activeGoal: T,
	_activeLatestP: {number},
	_activeLatestV: {number},
	_activeNumSprings: number,
	_activeSpeed: number,
	_activeStartP: {number},
	_activeStartV: {number},
	_activeTargetP: {number},
	_activeType: string,
	_speed: Types.UsedAs<number>,
	_damping: Types.UsedAs<number>,
	_goal: Types.UsedAs<T>,
	_reportedSpeed: unknown,
	_reportedDamping: unknown,
	_stopwatch: Stopwatch.Stopwatch?
}

local function sanitiseParameter(
	raw: unknown,
	fallback: number,
	lastReported: unknown,
	mistypedID: string,
	invalidID: string
): (number, unknown)
	if typeof(raw) ~= "number" then
		if not isSimilar(raw, lastReported) then
			External.logErrorNonFatal(mistypedID, nil, typeof(raw))
		end
		return fallback, raw
	end
	local raw = raw :: number
	if raw ~= raw or raw < 0 then
		if not isSimilar(raw, lastReported) then
			External.logErrorNonFatal(invalidID, nil, raw)
		end
		return fallback, raw
	end
	return raw, NOT_REPORTED
end

local function hasSimulation(
	self: Self<any>
): boolean
	if self._stopwatch == nil then
		External.logWarn("springConstantGoal")
		return false
	end
	return true
end

local class = {}
class.type = "State"
class.kind = "Spring"
class.timeliness = "eager"

local METATABLE = table.freeze {__index = class}

local TAU = 2 * math.pi

local function unwrapRotation(
	numbers: {number},
	towards: {number}
): ()
	local x, y, z = numbers[4], numbers[5], numbers[6]
	local referenceX, referenceY, referenceZ = towards[4], towards[5], towards[6]
	local angle = math.sqrt(x * x + y * y + z * z)
	local axisX, axisY, axisZ
	if angle > 0 then
		axisX, axisY, axisZ = x / angle, y / angle, z / angle
	else
		local reference = math.sqrt(
			referenceX * referenceX + referenceY * referenceY + referenceZ * referenceZ
		)
		if reference == 0 then
			return
		end
		axisX, axisY, axisZ = referenceX / reference, referenceY / reference, referenceZ / reference
	end
	local along = axisX * (referenceX - x) + axisY * (referenceY - y) + axisZ * (referenceZ - z)
	local turns = math.round(along / TAU)
	if turns ~= 0 then
		numbers[4] = x + axisX * TAU * turns
		numbers[5] = y + axisY * TAU * turns
		numbers[6] = z + axisZ * TAU * turns
	end
end

local function rewrapRotation(
	positions: {number},
	velocities: {number}
): ()
	local x, y, z = positions[4], positions[5], positions[6]
	local angle = math.sqrt(x * x + y * y + z * z)
	if angle <= math.pi then
		return
	end
	local scale = (angle - TAU * math.round(angle / TAU)) / angle
	local axisX, axisY, axisZ = x / angle, y / angle, z / angle
	local velocityX, velocityY, velocityZ = velocities[4], velocities[5], velocities[6]
	local along = velocityX * axisX + velocityY * axisY + velocityZ * axisZ
	positions[4], positions[5], positions[6] = x * scale, y * scale, z * scale
	velocities[4] = along * axisX + (velocityX - along * axisX) * scale
	velocities[5] = along * axisY + (velocityY - along * axisY) * scale
	velocities[6] = along * axisZ + (velocityZ - along * axisZ) * scale
end

local function boundRotation(
	self: Self<any>
): ()
	if self._activeType == "CFrame" then
		rewrapRotation(self._activeLatestP, self._activeLatestV)
		unwrapRotation(self._activeTargetP, self._activeLatestP)
	end
end

local function Spring<T>(
	scope: Types.Scope<unknown>,
	goal: Types.UsedAs<T>,
	speed: Types.UsedAs<number>?,
	damping: Types.UsedAs<number>?
): Types.Spring<T>
	local createdAt = timestamp()

	local goalState = castToState(goal)
	local stopwatch = nil
	if goalState ~= nil then
		stopwatch = Stopwatch(scope, ExternalTime(scope))
		stopwatch:unpause()
	end

	local speed = if speed == nil then DEFAULT_SPEED else speed
	local damping = if damping == nil then DEFAULT_DAMPING else damping

	local self: Self<T> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_activeDamping = -1,
			_activeGoal = nil,
			_activeLatestP = {},
			_activeLatestV = {},
			_activeNumSprings = 0,
			_activeSpeed = -1,
			_activeStartP = {},
			_activeStartV = {},
			_activeTargetP = {},
			_activeType = "",
			_damping = damping,
			_EXTREMELY_DANGEROUS_usedAsValue = peek(goal),
			_goal = goal,
			_reportedDamping = NOT_REPORTED,
			_reportedSpeed = NOT_REPORTED,
			_speed = speed,
			_stopwatch = stopwatch
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestChore = destroy
	nicknames[self.oldestChore] = "Spring"
	table.insert(scope, destroy)

	if goalState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestChore,
			goalState.scope, goalState.oldestChore,
			checkLifetime.formatters.animationGoal
		)
	end
	local speedState = castToState(speed)
	if speedState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestChore,
			speedState.scope, speedState.oldestChore,
			checkLifetime.formatters.parameter, "speed"
		)
	end
	local dampingState = castToState(damping)
	if dampingState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestChore,
			dampingState.scope, dampingState.oldestChore,
			checkLifetime.formatters.parameter, "damping"
		)
	end

	-- Eagerly evaluated objects need to evaluate themselves so that they're
	-- valid at all times.
	evaluate(self, true)

	return self
end

function class.addVelocity<T>(
	self: Self<T>,
	deltaValue: T
): ()
	if not hasSimulation(self) then
		return
	end
	evaluate(self, false) -- ensure the _active params are up to date
	local deltaType = typeof(deltaValue)
	if deltaType ~= self._activeType then
		External.logError("springTypeMismatch", nil, deltaType, self._activeType)
	end
	boundRotation(self)
	local newStartV = unpackType(deltaValue, deltaType)
	for index, velocity in self._activeLatestV do
		newStartV[index] += velocity
	end
	self._activeStartP = table.clone(self._activeLatestP)
	self._activeStartV = newStartV
	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	stopwatch:zero()
	stopwatch:unpause()
	change(self)
end

function class.setPosition<T>(
	self: Self<T>,
	newValue: T
): ()
	if not hasSimulation(self) then
		return
	end
	evaluate(self, false) -- ensure the _active params are up to date
	local newType = typeof(newValue)
	if newType ~= self._activeType then
		External.logError("springTypeMismatch", nil, newType, self._activeType)
	end
	self._activeStartP = unpackType(newValue, newType)
	if newType == "CFrame" then
		unwrapRotation(self._activeTargetP, self._activeStartP)
	end
	self._activeStartV = table.clone(self._activeLatestV)
	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	stopwatch:zero()
	stopwatch:unpause()
	change(self)
end

function class.setVelocity<T>(
	self: Self<T>,
	newValue: T?
): ()
	if not hasSimulation(self) then
		return
	end
	evaluate(self, false) -- ensure the _active params are up to date
	boundRotation(self)
	if newValue then
		local newType = typeof(newValue)
		if newType ~= self._activeType then
			External.logError("springTypeMismatch", nil, newType, self._activeType)
		end
		self._activeStartV = unpackType(newValue, newType)
	else
		self._activeStartV = table.create(self._activeNumSprings, 0)
	end
	self._activeStartP = table.clone(self._activeLatestP)
	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	stopwatch:zero()
	stopwatch:unpause()
	change(self)
end

function class._evaluate<T>(
	self: Self<T>
): boolean
	local goal = castToState(self._goal)

	-- Allow non-state goals to pass through transparently.
	if goal == nil then
		self._EXTREMELY_DANGEROUS_usedAsValue = self._goal :: T
		return false
	end

	local nextFrameGoal = depend(self, goal)

	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	local elapsed = depend(self, stopwatch)

	-- Protect against NaN goals.
	if nextFrameGoal ~= nextFrameGoal then
		External.logWarn("springNanGoal")
		return false
	end

	local nextFrameGoalType = typeof(nextFrameGoal)
	local discontinuous = nextFrameGoalType ~= self._activeType

	local newValue: T

	if discontinuous then
		-- Propagate changes in type instantly throughout the whole reactive
		-- graph, even if simulation is logically one frame behind, because it
		-- makes the whole graph behave more consistently.
		newValue = nextFrameGoal
	else
		-- Calculate spring motion.
		-- IMPORTANT: use the parameters from last frame, not this frame. We're
		-- integrating the motion that happened over the last frame, after all.
		-- The stopwatch will have captured the length of time needed correctly.
		local posPos, posVel, velPos, velVel = springCoefficients(
			elapsed,
			self._activeDamping,
			self._activeSpeed
		)
		local isMoving = false
		for index = 1, self._activeNumSprings do
			local startP = self._activeStartP[index]
			local targetP = self._activeTargetP[index]
			local startV = self._activeStartV[index]
			local startD = startP - targetP
			local latestD = startD * posPos + startV * posVel
			local latestV = startD * velPos + startV * velVel
			if latestD ~= latestD or latestV ~= latestV then
				External.logWarn("springNanMotion")
				latestD, latestV = 0, 0
			end
			if math.abs(latestD) < EPSILON then
				latestD = 0
			end
			if math.abs(latestV) < EPSILON then
				latestV = 0
			end
			if math.abs(latestD) > EPSILON or math.abs(latestV) > EPSILON then
				isMoving = true
			end
			local latestP = latestD + targetP
			self._activeLatestP[index] = latestP
			self._activeLatestV[index] = latestV
		end

		-- Sleep and snap to goal if the motion has decayed to a negligible amount.
		if not isMoving and stopwatch:isPlaying() then
			self._activeLatestP = table.clone(self._activeTargetP)
			self._activeLatestV = table.create(self._activeNumSprings, 0)

			self._activeStartP = table.clone(self._activeTargetP)
			self._activeStartV = table.create(self._activeNumSprings, 0)

			stopwatch:pause()
			stopwatch:zero()
		end
		if self._activeNumSprings == 0 then
			newValue = nextFrameGoal
		else
			-- Pack springs into final value.
			newValue = packType(self._activeLatestP, self._activeType) :: any
		end
	end

	-- Reconfigure spring when any of its parameters are changed.
	-- This should happen after integrating the last frame's motion.
	-- NOTE: don't need to add a dependency on these objects! they do not cause
	-- a spring to wake from sleep, so the stopwatch dependency is sufficient.
	local nextFrameSpeed, nextFrameDamping
	nextFrameSpeed, self._reportedSpeed = sanitiseParameter(
		peek(self._speed),
		if self._activeSpeed >= 0 then self._activeSpeed else DEFAULT_SPEED,
		self._reportedSpeed,
		"mistypedSpringSpeed",
		"invalidSpringSpeed"
	)
	nextFrameDamping, self._reportedDamping = sanitiseParameter(
		peek(self._damping),
		if self._activeDamping >= 0 then self._activeDamping else DEFAULT_DAMPING,
		self._reportedDamping,
		"mistypedSpringDamping",
		"invalidSpringDamping"
	)
	if
		discontinuous or
		nextFrameGoal ~= self._activeGoal or
		nextFrameSpeed ~= self._activeSpeed or
		nextFrameDamping ~= self._activeDamping
	then
		self._activeTargetP = unpackType(nextFrameGoal, nextFrameGoalType)
		if not discontinuous and nextFrameGoalType == "CFrame" then
			rewrapRotation(self._activeLatestP, self._activeLatestV)
			unwrapRotation(self._activeTargetP, self._activeLatestP)
		end
		self._activeNumSprings = #self._activeTargetP
		if discontinuous then
			self._activeStartP = table.clone(self._activeTargetP)
			self._activeLatestP = table.clone(self._activeTargetP)
			self._activeStartV = table.create(self._activeNumSprings, 0)
			self._activeLatestV = table.create(self._activeNumSprings, 0)
		elseif
			#self._activeStartP == self._activeNumSprings and
			#self._activeStartV == self._activeNumSprings
		then
			table.move(self._activeLatestP, 1, self._activeNumSprings, 1, self._activeStartP)
			table.move(self._activeLatestV, 1, self._activeNumSprings, 1, self._activeStartV)
		else
			self._activeStartP = table.clone(self._activeLatestP)
			self._activeStartV = table.clone(self._activeLatestV)
		end
		self._activeType = nextFrameGoalType
		self._activeGoal = nextFrameGoal
		self._activeDamping = nextFrameDamping
		self._activeSpeed = nextFrameSpeed
		stopwatch:zero()
		stopwatch:unpause()
	end

	-- Push update and check for similarity.
	-- Don't need to use the similarity test here because this code doesn't
	-- deal with tables, and NaN is already guarded against, so the similarity
	-- test doesn't actually add any new safety here.
	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	self._EXTREMELY_DANGEROUS_usedAsValue = newValue
	return oldValue ~= newValue
end

table.freeze(class)
return Spring :: Types.SpringConstructor
