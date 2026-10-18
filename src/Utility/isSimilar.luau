--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Implements the 'similarity test' used to determine whether two values have
	a meaningful difference.

	https://elttob.uk/Fusion/0.3/tutorials/best-practices/optimisation/#similarity
]]

local function components(
	value: any,
	valueType: string
): {number}?
	if valueType == "Vector2" then
		return {value.X, value.Y}
	elseif valueType == "Vector3" then
		return {value.X, value.Y, value.Z}
	elseif valueType == "CFrame" then
		return {value:GetComponents()}
	elseif valueType == "Color3" then
		return {value.R, value.G, value.B}
	elseif valueType == "UDim" then
		return {value.Scale, value.Offset}
	elseif valueType == "UDim2" then
		return {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}
	elseif valueType == "Rect" then
		return {value.Min.X, value.Min.Y, value.Max.X, value.Max.Y}
	elseif valueType == "NumberRange" then
		return {value.Min, value.Max}
	else
		return nil
	end
end

local function isSimilarWithNaN(
	a: unknown,
	b: unknown,
	valueType: string
): boolean
	if valueType == "number" then
		return true
	end
	local componentsA = components(a, valueType)
	local componentsB = components(b, valueType)
	if componentsA == nil or componentsB == nil then
		return true
	end
	for index, componentA in componentsA do
		local componentB = componentsB[index]
		if componentA ~= componentB and (componentA == componentA or componentB == componentB) then
			return false
		end
	end
	return true
end

local function isSimilar(
	a: unknown,
	b: unknown
): boolean
	local typeA = typeof(a)
	local isTable = typeA == "table"
	local isUserdata = typeA == "userdata"
	return
		if not (isTable or isUserdata) then
			a == b or (
				a ~= a and b ~= b and
				typeA == typeof(b) and
				isSimilarWithNaN(a, b, typeA)
			)
		elseif typeA == typeof(b) and (isUserdata or table.isfrozen(a :: any) or getmetatable(a :: any) ~= nil) then
			a == b
		else
			false
end

return isSimilar
