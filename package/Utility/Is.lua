local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions

local World = require(Core.World)
local Components = require(Definitions.Components)
local Tags = require(Definitions.Tags)

local module = {}

function module.Entity(e: number?): boolean
	return e and typeof(e) == "number" and World:contains(e)
end

function module.Object(o: { entity: number }?): boolean
	return o and typeof(o) == "table" and module.Entity(o.entity)
end

function module.Producer(o: { entity: number }?): boolean
	return module.Object(o) and World:has(o.entity, Tags.Producer)
end

function module.Consumer(o: { entity: number }?): boolean
	return module.Object(o) and World:has(o.entity, Tags.Producer)
end

function module.Mapper(o: { entity: number }): boolean
	return module.Object(o) and World:has(o.entity, Tags.Mapper)
end

function module.StateOf(state: { entity: number }, typeIs: string, ...: string): boolean
	if not module.Object(state) then return false end
	
	local stateType = World:get(state.entity, Components.State)
	if not stateType then return false end
	
	return stateType == typeIs or table.find(stateType, {...})
end

function module.TableOf(tbl, typeIs: string, ...: string): boolean
	if typeof(tbl) ~= "table" then return false end
	
	local types = { typeIs, ... }
	for _, v in tbl do
		if table.find(types, typeof(v)) then return false end
	end
	
	return true
end

return module
