--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores types that are commonly used between For objects.
]]

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)

export type SubObject<S, KI, KO, VI, VO> = {
	maybeScope: Types.Scope<S>?,
	inputKey: KI,
	inputValue: VI,
	roamKeys: boolean,
	roamValues: boolean,
	invalidateInputKey: (SubObject<S, KI, KO, VI, VO>) -> (),
	invalidateInputValue: (SubObject<S, KI, KO, VI, VO>) -> (),
	useOutputPair: (SubObject<S, KI, KO, VI, VO>, Types.Use) -> (KO?, VO?),
	_usedObjects: {Types.GraphObject}?,
	_outputKey: KO?,
	_dirty: boolean?
}

export type Disassembly<S, KI, KO, VI, VO> = Types.GraphObject & {
	_membershipChanged: boolean,
	populate: (Disassembly<S, KI, KO, VI, VO>, Types.Use, output: {[KO]: VO}) -> boolean,
	patch: (Disassembly<S, KI, KO, VI, VO>, dependent: Types.GraphObject, Types.Use, since: number, output: {[KO]: VO}) -> boolean
}

return nil
