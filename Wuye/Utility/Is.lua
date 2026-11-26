local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions

local World = require(Core.World)
local Components = require(Definitions.Components)
local Tags = require(Definitions.Tags)

local module = {}

function module.Entity(e: any): boolean
	return typeof(e) == "number" and World:contains(e :: any)
end

function module.Object(o: any): boolean
	return typeof(o) == "table" and module.Entity(o.entity)
end

function module.Producer(o: any): boolean
	if not module.Object(o) then
		return false
	end

	return World:has((o :: { entity: any }).entity, Tags.Producer)
end

function module.Consumer(o: any): boolean
	if not module.Object(o) then
		return false
	end

	return World:has((o :: { entity: any }).entity, Tags.Consumer)
end

function module.Mapper(o: any): boolean
	if not module.Object(o) then
		return false
	end

	return World:has((o :: { entity: any }).entity, Tags.Mapper)
end

function module.StateOf(state: any, typeIs: string, ...: string): boolean
	if not module.Object(state) then return false end
	
	local stateValue = World:get((state :: { entity: any }).entity, Components.State)
	if stateValue == nil then return false end
	
	local valueType = typeof(stateValue)
	if valueType == typeIs then
		return true
	end

	local extraCount = select("#", ...)
	for i = 1, extraCount do
		if valueType == select(i, ...) then
			return true
		end
	end

	return false
end

function module.TableOf(tbl, typeIs: string, ...: string): boolean
	if typeof(tbl) ~= "table" then return false end
	
	local extraCount = select("#", ...)
	for _, v in tbl do
		local valueType = typeof(v)
		if valueType ~= typeIs then
			local valid = false
			for i = 1, extraCount do
				if valueType == select(i, ...) then
					valid = true
					break
				end
			end

			if not valid then
				return false
			end
		end
	end
	
	return true
end

return module
