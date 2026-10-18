--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Linearly interpolates the given animatable types by a ratio.
	If the types are different or not animatable, then the first value will be
	returned for ratios below 0.5, and the second value for 0.5 and above.
]]

local Package = script.Parent.Parent
local Oklab = require(Package.Colour.Oklab)

local labCache: {[Color3]: Vector3} = setmetatable({}, {__mode = "k"}) :: any

local function labOf(
	colour: Color3
): Vector3
	local lab: Vector3? = labCache[colour]
	if lab ~= nil then
		return lab
	end
	local newLab = Oklab.fromSRGB(colour)
	labCache[colour] = newLab
	return newLab
end

local function lerpType(
	from: unknown,
	to: unknown,
	ratio: number
): unknown
	local typeString = typeof(from)

	if typeof(to) == typeString then
		-- both types must match for interpolation to make sense
		if typeString == "number" then
			local to, from = to :: number, from :: number
			return (to - from) * ratio + from

		elseif typeString == "CFrame" then
			local to, from = to :: CFrame, from :: CFrame
			return from:Lerp(to, ratio)

		elseif typeString == "Color3" then
			local to, from = to :: Color3, from :: Color3
			local fromLab = labOf(from)
			local toLab = labOf(to)
			return Oklab.toSRGB(
				fromLab:Lerp(toLab, ratio),
				false
			)

		elseif typeString == "ColorSequenceKeypoint" then
			local to, from = to :: ColorSequenceKeypoint, from :: ColorSequenceKeypoint
			local fromLab = Oklab.fromSRGB(from.Value)
			local toLab = Oklab.fromSRGB(to.Value)
			return ColorSequenceKeypoint.new(
				(to.Time - from.Time) * ratio + from.Time,
				Oklab.toSRGB(
					fromLab:Lerp(toLab, ratio),
					false
				)
			)

		elseif typeString == "DateTime" then
			local to, from = to :: DateTime, from :: DateTime
			return DateTime.fromUnixTimestampMillis(
				(to.UnixTimestampMillis - from.UnixTimestampMillis) * ratio + from.UnixTimestampMillis
			)

		elseif typeString == "NumberRange" then
			local to, from = to :: NumberRange, from :: NumberRange
			local min = (to.Min - from.Min) * ratio + from.Min
			local max = (to.Max - from.Max) * ratio + from.Max
			return NumberRange.new(math.min(min, max), math.max(min, max))

		elseif typeString == "NumberSequenceKeypoint" then
			local to, from = to :: NumberSequenceKeypoint, from :: NumberSequenceKeypoint
			return NumberSequenceKeypoint.new(
				(to.Time - from.Time) * ratio + from.Time,
				(to.Value - from.Value) * ratio + from.Value,
				(to.Envelope - from.Envelope) * ratio + from.Envelope
			)

		elseif typeString == "PhysicalProperties" then
			local to, from = to :: PhysicalProperties, from :: PhysicalProperties
			return PhysicalProperties.new(
				(to.Density - from.Density) * ratio + from.Density,
				(to.Friction - from.Friction) * ratio + from.Friction,
				(to.Elasticity - from.Elasticity) * ratio + from.Elasticity,
				(to.FrictionWeight - from.FrictionWeight) * ratio + from.FrictionWeight,
				(to.ElasticityWeight - from.ElasticityWeight) * ratio + from.ElasticityWeight
			)

		elseif typeString == "Ray" then
			local to, from = to :: Ray, from :: Ray
			return Ray.new(
				from.Origin:Lerp(to.Origin, ratio),
				from.Direction:Lerp(to.Direction, ratio)
			)

		elseif typeString == "Rect" then
			local to, from = to :: Rect, from :: Rect
			return Rect.new(
				from.Min:Lerp(to.Min, ratio),
				from.Max:Lerp(to.Max, ratio)
			)

		elseif typeString == "Region3" then
			local to, from = to :: Region3, from :: Region3
			-- FUTURE: support rotated Region3s if/when they become constructable
			local position = from.CFrame.Position:Lerp(to.CFrame.Position, ratio)
			local halfSize = from.Size:Lerp(to.Size, ratio) / 2
			return Region3.new(position - halfSize, position + halfSize)

		elseif typeString == "Region3int16" then
			local to, from = to :: Region3int16, from :: Region3int16
			return Region3int16.new(
				Vector3int16.new(
					math.round((to.Min.X - from.Min.X) * ratio + from.Min.X),
					math.round((to.Min.Y - from.Min.Y) * ratio + from.Min.Y),
					math.round((to.Min.Z - from.Min.Z) * ratio + from.Min.Z)
				),
				Vector3int16.new(
					math.round((to.Max.X - from.Max.X) * ratio + from.Max.X),
					math.round((to.Max.Y - from.Max.Y) * ratio + from.Max.Y),
					math.round((to.Max.Z - from.Max.Z) * ratio + from.Max.Z)
				)
			)

		elseif typeString == "UDim" then
			local to, from = to :: UDim, from :: UDim
			return UDim.new(
				(to.Scale - from.Scale) * ratio + from.Scale,
				math.round((to.Offset - from.Offset) * ratio + from.Offset)
			)

		elseif typeString == "UDim2" then
			local to, from = to :: UDim2, from :: UDim2
			return UDim2.new(
				(to.X.Scale - from.X.Scale) * ratio + from.X.Scale,
				math.round((to.X.Offset - from.X.Offset) * ratio + from.X.Offset),
				(to.Y.Scale - from.Y.Scale) * ratio + from.Y.Scale,
				math.round((to.Y.Offset - from.Y.Offset) * ratio + from.Y.Offset)
			)

		elseif typeString == "Vector2" then
			local to, from = to :: Vector2, from :: Vector2
			return from:Lerp(to, ratio)

		elseif typeString == "Vector2int16" then
			local to, from = to :: Vector2int16, from :: Vector2int16
			return Vector2int16.new(
				math.round((to.X - from.X) * ratio + from.X),
				math.round((to.Y - from.Y) * ratio + from.Y)
			)

		elseif typeString == "Vector3" then
			local to, from = to :: Vector3, from :: Vector3
			return from:Lerp(to, ratio)

		elseif typeString == "Vector3int16" then
			local to, from = to :: Vector3int16, from :: Vector3int16
			return Vector3int16.new(
				math.round((to.X - from.X) * ratio + from.X),
				math.round((to.Y - from.Y) * ratio + from.Y),
				math.round((to.Z - from.Z) * ratio + from.Z)
			)
		end
	end

	-- fallback case: the types are different or not animatable
	if ratio < 0.5 then
		return from
	else
		return to
	end
end

return lerpType
