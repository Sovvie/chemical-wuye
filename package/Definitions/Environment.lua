local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions
local Utility = RootFolder.Utility

local JECS = require(Core.JECS)
local World = require(Core.World)

local Components = require(Definitions.Components)
local Tags = require(Definitions.Tags)

local Cleanup = require(Utility.Cleanup)

local module = {}

local function ENV(name: string) end

do ENV "JECS Tags"
	World:add(Tags.InScopeOf, JECS.pair(JECS.OnDeleteTarget, JECS.Delete))
	World:add(Tags.ConsumerOf, JECS.pair(JECS.OnDeleteTarget, JECS.Delete))
	World:add(Tags.DeleteBefore, JECS.pair(JECS.OnDeleteTarget, JECS.Delete))

	World:add(Tags.RuntimeOf, JECS.Exclusive)
	World:add(Tags.InScopeOf, JECS.Exclusive)
end

do ENV "ConsumerOf"
	World:set(Tags.ConsumerOf, JECS.OnAdd, function(_, id, _)
		if not JECS.IS_PAIR(id) then return end

		local producer = JECS.pair_second(World, id)

		if not World:has(producer, Tags.HasConsumers) then
			World:add(producer, Tags.HasConsumers)
		end
	end)

	--World:set(Tags.ConsumerOf, JECS.OnRemove, function(entity, id, data)
	--	if not JECS.IS_PAIR(id) then return end

	--	local producer = JECS.pair_second(World, id)

	--	local producersTable = World:get(entity, JECS.pair(Components.TableOf, Tags.Producer)) or {}
	--	local index = table.find(producersTable, producer)
	--	if index then table.remove(producersTable, index) end

	--	World:set(entity, JECS.pair(Components.TableOf, Tags.Producer), producersTable)
	--end)
end

do ENV "State"
	World:set(Components.State, JECS.OnChange, function(entity: JECS.Entity<any>, _, _)
		if World:has(entity, Tags.Dirty) then return end

		World:add(entity, Tags.Dirty)
	end)

	World:set(Components.State, JECS.OnRemove, function(entity: JECS.Entity<any>, _)
		if World:has(entity, Tags.Cleanable) then
			Cleanup(World:get(entity, Components.State))
		end
	end)
end

do ENV "Cache"
	World:set(Components.Cache, JECS.OnRemove, function(entity: JECS.Entity<any>, id)
		Cleanup(World:get(entity, Components.Cache))
	end)
end

return module
