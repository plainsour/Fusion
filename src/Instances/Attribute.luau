--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to apply custom
	attributes to instances
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Logging
local parseError = require(Package.Logging.parseError)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local Observer = require(Package.Graph.Observer)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)

local keyCache: {[string]: Types.SpecialKey} = {}

local function setAttribute(
	instance: Instance,
	attributeName: string,
	value: unknown
): ()
	local ok, err = xpcall(instance.SetAttribute, parseError, instance, attributeName, value)
	if not ok then
		External.logErrorNonFatal("attributeSetError", err)
	end
end

local function Attribute(
	attributeName: string
): Types.SpecialKey
	local key = keyCache[attributeName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "Attribute",
			stage = "self",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Instance
			)
				if castToState(value) then
					local value = value :: Types.StateObject<unknown>
					checkLifetime.bOutlivesA(
						scope, applyTo,
						value.scope, value.oldestChore,
						checkLifetime.formatters.boundAttribute, attributeName
					)
					Observer(scope, value :: any):onBind(function()
						setAttribute(applyTo, attributeName, peek(value))
					end)
				else
					setAttribute(applyTo, attributeName, value)
				end
			end
		}
		keyCache[attributeName] = key
	end
	return key
end

return Attribute
