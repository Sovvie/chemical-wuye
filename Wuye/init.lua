-- Wuye
-- This is a version of Chemical which is still heavily under-development.
-- Credit: Sovereignty
--        very early version of 0.3.0

local Core = script.Core
local Utility = script.Utility
local Definitions = script.Definitions

local JECS = require(Core.JECS)
local Tags = require(Definitions.Tags)
local Components = require(Definitions.Components)

local World = require(Core.World)
local Lifetime = require(Core.Lifetime)
local Environment = require(Definitions.Environment)

local Heartbeat = require(Core.Heartbeat)
local Throttle = require(Utility.Throttle)
local Debounce = require(Utility.Debounce)
local Cleanup = require(Utility.Cleanup)
local Log = require(Utility.Log)
local Is = require(Utility.Is)

export type Scopable<S> = S & {
	entity: JECS.Entity<nil>,
}

export type State<T> = {
	entity: JECS.Entity<T>,
	get: () -> T,
}

export type Computed<T> = {
	entity: JECS.Entity<T>,
	get: (Computed<T>) -> T
}

export type Effect = {
	entity: JECS.Entity<() -> ()>,
}

export type Watch = {
	entity: JECS.Entity<() -> ()>,
}

export type Mapper<T> = State<T> & {
	changed: (self: Mapper<T>, callback: (new: T, old: T) -> () ) -> ()
}

export type Use = <T>(state: State<T>) -> T

export type Cleanup<T> = <T>(state: T) -> ()

-- ~~~~~~~~~~~~~~~~~~~~~~~
--[[ == ]] --  Constant --


-- ~~~~~~~~~~~~~~~~~~~~~~
--[[ == ]] --  Private --

local CollectionService = game:GetService("CollectionService")
local COLLECTION_TAG = "Entity"
local COLLECTION_IDENTITY_TAG = "ENTITY_"

local function IMMEDIATE_UPDATE(effect: Effect)
	World:remove(effect.entity, Tags.Dirty)
	do
		(World:get(effect.entity, JECS.pair(Tags.OnUpdate, Components.Callback)) :: () -> ())()
	end
end

-- ~~~~~~~~~~~~~~~~~~~~~
--[[ == ]] --  Public --
--[[ == ]] --  | -- Scopable --

local function Add<S, U...>(scope: Scopable<S>, ...: U...): U...
	local currentCacheTable = World:get(scope.entity, Components.CacheTable)
	local length = #currentCacheTable
	for i, item in table.pack(...) do
		currentCacheTable[length + i] = item
	end

	World:set(scope.entity, Components.CacheTable, currentCacheTable)

	return ...
end

local function Remove<S>(scope: Scopable<S>, ...: any)
	local currentCacheTable = World:get(scope.entity, Components.CacheTable)
	local length = #currentCacheTable
	if length <= 0 then return end

	for _, item in { ... } do
		local index = table.find(currentCacheTable, item)
		if index then
			Cleanup(table.remove(currentCacheTable, index))
		end
	end

	World:set(scope.entity, Components.CacheTable, currentCacheTable)
end

local function Delete<S>(source: Scopable<S> | { entity: JECS.Entity<any> })
	World:delete(source.entity)
end

local function Set<T>(state: State<T>, value: T)
	local entity = state.entity
	local previous = World:get(entity, Components.State)

	if value == previous then return end

	World:set(entity, JECS.pair(Tags.Previous, Components.State), previous)
	World:set(entity, Components.State, value)
end

local function Getter<T>(entity: JECS.Entity<T>): () -> T
	local e= entity
	local c = Components.State
	return function(): T
		return World:get(e, c) :: T
	end
end

--TODO remake this
--TODO use collection service and events to handle binding instances to entities.
-- local function Bind(bindable: { entity: JECS.Entity }, parent: Instance | { entity: JECS.Entity })
-- 	local entity = World:entity()
-- 	World:add(entity, JECS.pair(Tags.InScopeOf, bindable.entity))

-- 	if typeof(parent) == "Instance" then
-- 		World:set(bindable.entity, JECS.pair(Components.Cache, entity), parent.Destroying:Connect(function()
-- 			if not World:exists(bindable.entity) then return end

-- 			World:delete(bindable.entity)
-- 		end))
-- 	else
-- 		World:add(bindable.entity, JECS.pair(Tags.DeleteBefore, parent.entity))
-- 	end

-- 	return { entity = entity }
-- end

local function Changed<S, T>(source: Scopable<S>, target: State<T>, callback: (new: T, old: T) -> ()): Effect
	local entity = World:entity()
	World:add(entity, Tags.Consumer)
	World:add(entity, JECS.pair(Tags.RuntimeOf, Tags.React))
	World:add(entity, JECS.pair(Tags.ConsumerOf, target.entity))

	World:set(entity, JECS.pair(Tags.OnChange, Components.Callback), callback)
	World:add(entity, Tags.Dirty)

	World:add(entity, JECS.pair(Tags.InScopeOf, source.entity))

	return { entity = entity }
end

--TODO Scoped entity/metatable recycling.
--TODO Handshake entity recycling.
--TODO doesnt have typechecking safety checks
local function Scoped<S>(source: S, cheap: boolean?): Scopable<S>
	if typeof(source) ~= "table" then return error("Scoped's source must be at least of type table, preferably dict.") end

	local entity = World:entity()
	
	local sourceEntity = (source :: any)["entity"]
	if sourceEntity then
		World:add(entity, JECS.pair(Tags.InScopeOf, sourceEntity))
	end
	
	if cheap then
		return { entity = entity } :: Scopable<any>
	else
		World:add(entity, Tags.Scope)
		World:set(entity, Components.CacheTable, {})
		local sourceMetatable = getmetatable(source :: any)
		return setmetatable({ entity = entity }, sourceMetatable and { __index = sourceMetatable }  or { __index = source }) :: any
	end
end

--[[ == ]] --  | -- Constructors --

local function State<S, T>(scope: Scopable<Wuye>, initial: T): State<T>
	local entity = World:entity()
	World:add(entity, Tags.Producer)
	
	World:set(entity, JECS.pair(Tags.Previous, Components.State), initial)
	World:set(entity, Components.State, initial)

	World:add(entity, JECS.pair(Tags.InScopeOf, scope.entity))

	return {
		entity = entity,

		get = Getter(entity)
	}
end

--TODO Cleanup Hook and OnEvent Hook
--TODO Add Animation event Effect which runs on a different faster RunService.
local function Effect<S>(scope: Scopable<Wuye>, callback: (use: Use) -> Cleanup<nil>): Effect
	local entity = World:entity()
	World:add(entity, Tags.Consumer)
	World:add(entity, JECS.pair(Tags.RuntimeOf, Tags.React))
	World:add(entity, JECS.pair(Tags.InScopeOf, scope.entity))

	World:set(entity, JECS.pair(Tags.Previous, Components.Producers), {})
	World:set(entity, Components.Producers, {})

	local useHook = function<T>(usable: State<T>): T
		if Lifetime.AOutLivesB(World, entity, usable.entity) then
			local state = World:get(usable.entity, Components.State)

			local producersTable = World:get(entity, Components.Producers) or {}
			producersTable[usable.entity] = true

			return state
		else
			Log.warn(
				"Chemical.Effect",
				4,
				"use() is attempting to depend on a source object whose lifetime will be shorter than the Effect."
			)
			return nil :: any
		end
	end

	local effect = callback
	World:set(entity, JECS.pair(Tags.OnUpdate, Components.Callback), function()
		if World:has(entity, Components.Cleanup) then
			(World:get(entity, Components.Cleanup) :: () -> ())()
		end

		table.clear(World:get(entity, Components.Producers) :: {})

		local newCleanup = effect(useHook)

		local producersTable = World:get(entity, Components.Producers)
		local lastProducersTable = World:get(entity, JECS.pair(Tags.Previous, Components.Producers))

		for producer, _ in lastProducersTable do
			if not producersTable[producer] then
				World:remove(entity, JECS.pair(Tags.ConsumerOf, producer))
			end
		end

		for producer, _ in producersTable do
			if not lastProducersTable[producer] then
				World:add(entity, JECS.pair(Tags.ConsumerOf, producer))
			end
		end

		World:set(entity, JECS.pair(Tags.Previous, Components.Producers), producersTable)

		if newCleanup then World:set(entity, Components.Cleanup, newCleanup)
        else World:remove(entity, Components.Cleanup)
		end
	end)

	World:add(entity, Tags.Dirty)

	World:add(entity, JECS.pair(Tags.InScopeOf, scope.entity))

	return {
		entity = entity
	}
end

local function Render<S>(scope: Scopable<Wuye>, callback: (use: Use) -> Cleanup<nil>): Effect
	local effect = Effect(scope, callback)
	World:add(effect.entity, JECS.pair(Tags.RuntimeOf, Tags.Render))

	return effect
end

local function Computed<T>(scope: Scopable<Wuye>, callback: (use: Use) -> (T)): Computed<T>
	local state = State(scope, (nil :: any) :: T)
	World:add(state.entity, Tags.Memoized)

	local effect = Effect(scope, function(use)
		local newState = callback(use)

		Set(state, newState)
	end)
	World:add(effect.entity, JECS.pair(Tags.DeleteBefore, state.entity))

	IMMEDIATE_UPDATE(effect)

	return state
end

-- local function Resolvable<T, U...>(scope: Scopable<Wuye>, event: RBXScriptSignal<U...>, value: (U...) -> (T), placeholder: T): State<T>
-- 	local state = State(scope, placeholder)
-- 	local e

-- 	local function fired(...: U...)
-- 		World:delete(e)
-- 		Cleanup(
-- 			World:get(state.entity, Components.State)
-- 		)

-- 		Set(state, value(...))
-- 	end

-- 	e = Add(state, Cache(event:Connect(fired)))

-- 	return state
-- end

--TODO Compare Lifetimes of State and self
local function Mapped<S, K, V, R>(
	scope: Scopable<Wuye>,
	state: State<{ [K]: V }>,
	callback: (key: K, value: V) -> R,
	cleanup: Cleanup<R>?
): Mapper<{ [K]: R }>
	local object = State(scope, {})
	World:add(object.entity, Tags.Mapper)
	World:add(object.entity, JECS.pair(Tags.DeleteBefore, state.entity))

	local clean = cleanup or Cleanup
	local changed = Changed(scope, state, function(new, old)
		local newTable = new
		local oldTable =  old
		local currentTable = World:get(object.entity, Components.State)


		local futureTable = {}
		for key, value in newTable do
			if currentTable[key] and value == oldTable[key] then
				futureTable[key] = currentTable[key]
			else
				futureTable[key] = callback(key, value)
			end
		end

		local cleanupTable = {}
		for key, _ in oldTable do
			if not newTable[key] or newTable[key] ~= oldTable[key] then
				table.insert(cleanupTable, currentTable[key])
			end
		end

		for _, value in cleanupTable do
			clean(value)
		end

		World:set(object.entity, Components.State, futureTable)
	end)

	World:add(changed.entity, JECS.pair(Tags.DeleteBefore, object.entity))

	return object
end

local function Select<S, T, K>(scope: Scopable<Wuye>, state: State<{ [K]: T} | T>, key: K): Computed<K>
	local selected = Computed(scope, function(use)
		local tbl = use(state)
		return if tbl then tbl[key] else nil
	end)

	return selected
end

-- ~~~~~~~~~~~~~~~~~~~~~

do
	Heartbeat:Start()
end

local Wuye =  {
	set = Set,
	add = Add,
	remove = Remove,
	delete = Delete,
	scoped = Scoped,
	cleanup = Cleanup,
	
	State = State,
	
	Computed = Computed,
	Changed = Changed,
	Effect = Effect,
	Render = Render,
	Mapped = Mapped,

	Select = Select,

	Throttle = Throttle,
	Debounce = Debounce,
}

export type Wuye = typeof(Wuye)

return Wuye