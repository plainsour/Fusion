--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A variant of xpcall() designed for inline usage, letting you define fallback
	values based on caught errors.
]]

local function Safe<Success, Fail>(
	callbacks: {
		try: () -> Success,
		fallback: (err: unknown) -> Fail
	}
): Success | Fail
	local fallbackFailed = false
	local fallbackError: unknown = nil
	local _, value = xpcall(callbacks.try, function(err)
		local ok, result = pcall(callbacks.fallback, err)
		if not ok then
			fallbackFailed = true
			fallbackError = result
			return nil
		end
		return result
	end)
	if fallbackFailed then
		error(fallbackError, 0)
	end
	return value
end

return Safe
