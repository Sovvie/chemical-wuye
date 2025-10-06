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

do ENV "CleanupOnRemove"
	World:set(Tags.CleanableComponent, JECS.OnAdd, function(e: JECS.Entity<any>, _)
		World:set(e, JECS.OnRemove, function(entity: JECS.Entity<any>, _)
			Cleanup(World:get(entity, e))
		end)
	end)
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

do ENV "InScopeOf"
	World:set(Tags.InScopeOf, JECS.OnAdd, function(scopable, id, _)
		if not JECS.IS_PAIR(id) then return end

		local scope = JECS.pair_second(World, id)
		local cacheTable = World:get(scope, Components.CacheTable)
		table.insert(cacheTable, scopable)
	end)

	World:set(Tags.InScopeOf, JECS.OnRemove, function(scopable, id, _)
		if not JECS.IS_PAIR(id) then return end

		local scope = JECS.pair_second(World, id)
		local cacheTable = World:get(scope, Components.CacheTable)
		local index = table.find(cacheTable, scopable)
		if index then
			table.remove(cacheTable, index)
		end
	end)
end

do ENV "State"
	World:set(Components.State, JECS.OnChange, function(entity: JECS.Entity<any>, _, _)
		if World:has(entity, Tags.Dirty) then return end

		World:add(entity, Tags.Dirty)
	end)

	World:add(Components.State, Tags.CleanableComponent)
end


do ENV "Cache"
	World:add(Components.Cache, Tags.CleanableComponent)
	World:add(Components.CacheTable, Tags.CleanableComponent)
end

return module
