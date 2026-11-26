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
require(Definitions.Environment)

local Heartbeat = require(Core.Heartbeat)
local Throttle = require(Utility.Throttle)
local Debounce = require(Utility.Debounce)
local Cleanup = require(Utility.Cleanup)
local Log = require(Utility.Log)
local Is = require(Utility.Is)
local Benchmark = require(Utility.Benchmark)

export type Handle = {
	entity: JECS.Entity<any>,
	destroy: (self: Handle) -> (),
}

export type Scopable<S> = S & {
	entity: JECS.Entity<nil>,
}

export type State<T> = Handle & {
	entity: JECS.Entity<T>,
	get: (self: State<T>) -> T,
	set: (self: State<T>, value: T) -> (),
	tag: (self: State<T>, name: string, status: boolean?) -> (),
}

export type Computed<T> = State<T>

export type Effect = Handle & {
	entity: JECS.Entity<() -> ()>,
	tag: (self: Effect, name: string, status: boolean?) -> (),
}

export type Watch = Handle & {
	entity: JECS.Entity<() -> ()>,
}

export type Mapper<T> = State<T>
export type Use = <T>(state: State<T>) -> T
export type CleanupFn = <T>(subject: T) -> ()

local PREVIOUS_STATE_PAIR = JECS.pair(Tags.Previous, Components.State)
local PREVIOUS_PRODUCERS_PAIR = JECS.pair(Tags.Previous, Components.Producers)
local ON_CHANGE_CALLBACK_PAIR = JECS.pair(Tags.OnChange, Components.Callback)
local ON_UPDATE_CALLBACK_PAIR = JECS.pair(Tags.OnUpdate, Components.Callback)

local RuntimeTags = {}

local function getRuntimeTag(tagName: string): JECS.Entity
	local existing = RuntimeTags[tagName]
	if existing ~= nil then
		return existing
	end

	local runtimeTag = World:entity()
	RuntimeTags[tagName] = runtimeTag
	return runtimeTag
end

local function ensureCacheTable(scopeEntity: JECS.Entity<any>): { any }
	local cacheTable = World:get(scopeEntity, Components.CacheTable)
	if cacheTable == nil then
		cacheTable = {}
		World:set(scopeEntity, Components.CacheTable, cacheTable)
	end
	return cacheTable
end

local function immediateUpdate(effect: Effect)
	World:remove(effect.entity, Tags.Dirty)
	local callback = World:get(effect.entity, ON_UPDATE_CALLBACK_PAIR) :: (() -> ())?
	if callback then
		callback()
	end
end

local function deleteHandle(source: Scopable<any> | Handle)
	World:delete(source.entity)
end

local function tagHandle(source: Handle, name: string, status: boolean?)
	local runtimeTag = getRuntimeTag(name)
	if status == false then
		World:remove(source.entity, runtimeTag)
	else
		World:add(source.entity, runtimeTag)
	end
end

local function destroyHandle(self: Handle)
	deleteHandle(self)
end

local function addToScope<S, U...>(scope: Scopable<S>, ...: U...): U...
	local cacheTable = ensureCacheTable(scope.entity)
	local length = #cacheTable
	local count = select("#", ...)
	for i = 1, count do
		cacheTable[length + i] = select(i, ...)
	end
	return ...
end

local function removeFromScope<S>(scope: Scopable<S>, ...: any)
	local cacheTable = ensureCacheTable(scope.entity)
	local removeCount = select("#", ...)
	if removeCount == 0 or #cacheTable == 0 then
		return
	end

	for i = #cacheTable, 1, -1 do
		local subject = cacheTable[i]
		for j = 1, removeCount do
			if subject == select(j, ...) then
				Cleanup(table.remove(cacheTable, i))
				break
			end
		end
	end
end

local function cleanScope(scope: Scopable<any>)
	local cacheTable = ensureCacheTable(scope.entity)
	for i = #cacheTable, 1, -1 do
		local subject = cacheTable[i]
		cacheTable[i] = nil
		Cleanup(subject)
	end
end

local function setState<T>(state: State<T>, value: T)
	local entity = state.entity
	local previous = World:get(entity, Components.State)
	if value == previous then
		return
	end

	World:set(entity, PREVIOUS_STATE_PAIR, previous)
	World:set(entity, Components.State, value)
end

local function stateGet<T>(self: State<T>): T
	return World:get(self.entity, Components.State) :: T
end

local function stateSet<T>(self: State<T>, value: T)
	setState(self, value)
end

local function stateTag<T>(self: State<T>, name: string, status: boolean?)
	tagHandle(self, name, status)
end

local function effectTag(self: Effect, name: string, status: boolean?)
	tagHandle(self, name, status)
end

local function newStateHandle<T>(entity: JECS.Entity<T>): State<T>
	return {
		entity = entity,
		get = stateGet,
		set = stateSet,
		tag = stateTag,
		destroy = destroyHandle,
	}
end

local function newWatchHandle(entity: JECS.Entity<any>): Watch
	return {
		entity = entity,
		destroy = destroyHandle,
	}
end

local function newEffectHandle(entity: JECS.Entity<any>): Effect
	return {
		entity = entity,
		tag = effectTag,
		destroy = destroyHandle,
	}
end

local function watch<S, T>(
	scope: Scopable<S>,
	target: State<T>,
	callback: (new: T, old: T) -> ()
): Watch
	if not target or not target.entity then
		error("Wuye.Watch expected a State-like object with an entity.")
	end

	local entity = World:entity()
	World:add(entity, Tags.Consumer)
	World:add(entity, JECS.pair(Tags.RuntimeOf, Tags.React))
	World:add(entity, JECS.pair(Tags.ConsumerOf, target.entity))
	World:set(entity, ON_CHANGE_CALLBACK_PAIR, callback)
	World:add(entity, Tags.Dirty)
	World:add(entity, JECS.pair(Tags.InScopeOf, scope.entity))
	return newWatchHandle(entity)
end

local ScopeMethods = {}

local function buildScope(
	source: { [any]: any }?,
	parentEntity: JECS.Entity<any>?,
	cheap: boolean?
): Scopable<any>
	if source ~= nil and typeof(source) ~= "table" then
		error("Wuye.Scope source must be a table or nil.")
	end

	local scopeEntity = World:entity()
	World:set(scopeEntity, Components.CacheTable, {})
	if cheap ~= true then
		World:add(scopeEntity, Tags.Scope)
	end

	if parentEntity then
		World:add(scopeEntity, JECS.pair(Tags.InScopeOf, parentEntity))
	elseif source and source.entity then
		World:add(scopeEntity, JECS.pair(Tags.InScopeOf, source.entity))
	end

	local scope = {
		entity = scopeEntity,
	}

	if source then
		for key, value in source do
			if key ~= "entity" and scope[key] == nil then
				scope[key] = value
			end
		end
	end

	scope.add = ScopeMethods.add
	scope.remove = ScopeMethods.remove
	scope.delete = ScopeMethods.delete
	scope.clean = ScopeMethods.clean
	scope.Cleanup = ScopeMethods.Cleanup
	scope.set = ScopeMethods.set

	scope.State = ScopeMethods.State
	scope.Computed = ScopeMethods.Computed
	scope.Watch = ScopeMethods.Watch
	scope.Effect = ScopeMethods.Effect
	scope.Render = ScopeMethods.Render
	scope.Map = ScopeMethods.Map
	scope.Select = ScopeMethods.Select
	scope.Scope = ScopeMethods.Scope

	-- Legacy aliases kept for migration.
	scope.Changed = ScopeMethods.Watch
	scope.Mapped = ScopeMethods.Map
	scope.scoped = ScopeMethods.Scope
	scope.Destroy = ScopeMethods.Cleanup

	return scope :: any
end

local function scope<S>(source: S?, cheap: boolean?): Scopable<S>
	return buildScope(source :: any, nil, cheap) :: Scopable<S>
end

local function newState<S, T>(scopeRef: Scopable<S>, initial: T): State<T>
	local entity = World:entity()
	World:add(entity, Tags.Producer)
	World:set(entity, PREVIOUS_STATE_PAIR, initial)
	World:set(entity, Components.State, initial)
	World:add(entity, JECS.pair(Tags.InScopeOf, scopeRef.entity))
	return newStateHandle(entity)
end

local function newEffect<S>(scopeRef: Scopable<S>, callback: (use: Use) -> CleanupFn?): Effect
	local entity = World:entity()
	World:add(entity, Tags.Consumer)
	World:add(entity, JECS.pair(Tags.RuntimeOf, Tags.React))
	World:add(entity, JECS.pair(Tags.InScopeOf, scopeRef.entity))

	local currentProducers = {}
	local previousProducers = {}
	World:set(entity, Components.Producers, currentProducers)
	World:set(entity, PREVIOUS_PRODUCERS_PAIR, previousProducers)

	local function useHook<T>(stateLike: State<T>): T
		if not stateLike or not stateLike.entity then
			error("Wuye.use() expected a State-like object.")
		end

		if not Lifetime.AOutLivesB(World, entity, stateLike.entity) then
			Log.warn(
				"Wuye.Effect",
				4,
				"use() is attempting to depend on a source object whose lifetime will be shorter than the Effect."
			)
			return nil :: any
		end

		currentProducers[stateLike.entity] = true
		return World:get(stateLike.entity, Components.State) :: T
	end

	World:set(entity, ON_UPDATE_CALLBACK_PAIR, function()
		local existingCleanup = World:get(entity, Components.Cleanup) :: (() -> ())?
		if existingCleanup ~= nil then
			existingCleanup()
		end

		for producer in currentProducers do
			currentProducers[producer] = nil
		end

		local nextCleanup = callback(useHook)

		for producer in previousProducers do
			if not currentProducers[producer] then
				World:remove(entity, JECS.pair(Tags.ConsumerOf, producer))
			end
		end

		for producer in currentProducers do
			if not previousProducers[producer] then
				World:add(entity, JECS.pair(Tags.ConsumerOf, producer))
			end
		end

		local swap = previousProducers
		previousProducers = currentProducers
		currentProducers = swap

		World:set(entity, Components.Producers, currentProducers)
		World:set(entity, PREVIOUS_PRODUCERS_PAIR, previousProducers)

		if nextCleanup then
			World:set(entity, Components.Cleanup, nextCleanup)
		else
			World:remove(entity, Components.Cleanup)
		end
	end)

	World:add(entity, Tags.Dirty)
	return newEffectHandle(entity)
end

local function newRender<S>(scopeRef: Scopable<S>, callback: (use: Use) -> CleanupFn?): Effect
	local effect = newEffect(scopeRef, callback)
	World:add(effect.entity, JECS.pair(Tags.RuntimeOf, Tags.Render))
	return effect
end

local function newComputed<S, T>(scopeRef: Scopable<S>, callback: (use: Use) -> T): Computed<T>
	local state = newState(scopeRef, (nil :: any) :: T)
	World:add(state.entity, Tags.Memoized)

	local effect = newEffect(scopeRef, function(use)
		setState(state, callback(use))
		return nil
	end)

	World:add(effect.entity, JECS.pair(Tags.DeleteBefore, state.entity))
	immediateUpdate(effect)
	return state
end

local function mapState<S, K, V, R>(
	scopeRef: Scopable<S>,
	state: State<{ [K]: V }>,
	transform: (key: K, value: V) -> R,
	cleanupFn: CleanupFn?
): Mapper<{ [K]: R }>
	local mapped = newState(scopeRef, {})
	World:add(mapped.entity, Tags.Mapper)
	World:add(mapped.entity, JECS.pair(Tags.DeleteBefore, state.entity))

	local cleanupValue = cleanupFn or Cleanup
	local scratchCleanup = {}
	local bufferA = {}
	local bufferB = {}
	local writeBuffer = bufferA

	local watcher = watch(scopeRef, state, function(newTable, oldTable)
		local currentTable = World:get(mapped.entity, Components.State) or {}
		local futureTable = writeBuffer
		for key in futureTable do
			futureTable[key] = nil
		end

		for key, value in newTable do
			if currentTable[key] ~= nil and oldTable and value == oldTable[key] then
				futureTable[key] = currentTable[key]
			else
				futureTable[key] = transform(key, value)
			end
		end

		local cleanupCount = 0
		if oldTable then
			for key, oldValue in oldTable do
				local newValue = newTable[key]
				if newValue == nil or newValue ~= oldValue then
					cleanupCount += 1
					scratchCleanup[cleanupCount] = currentTable[key]
				end
			end
		end

		for i = 1, cleanupCount do
			cleanupValue(scratchCleanup[i])
			scratchCleanup[i] = nil
		end

		setState(mapped, futureTable)
		writeBuffer = if writeBuffer == bufferA then bufferB else bufferA
	end)

	World:add(watcher.entity, JECS.pair(Tags.DeleteBefore, mapped.entity))
	return mapped
end

local function selectState<S, T, K>(scopeRef: Scopable<S>, state: State<T>, key: K): Computed<any>
	return newComputed(scopeRef, function(use)
		local value = use(state)
		if value == nil then
			return nil
		end
		return (value :: any)[key]
	end)
end

function ScopeMethods:add(...)
	return addToScope(self, ...)
end

function ScopeMethods:remove(...)
	removeFromScope(self, ...)
end

function ScopeMethods:delete(target)
	deleteHandle(target or self)
end

function ScopeMethods:clean()
	cleanScope(self)
end

function ScopeMethods:Cleanup(subject)
	Cleanup(subject)
end

function ScopeMethods:set(stateLike, value)
	setState(stateLike, value)
end

function ScopeMethods:State(initial)
	return newState(self, initial)
end

function ScopeMethods:Computed(callback)
	return newComputed(self, callback)
end

function ScopeMethods:Watch(target, callback)
	return watch(self, target, callback)
end

function ScopeMethods:Effect(callback)
	return newEffect(self, callback)
end

function ScopeMethods:Render(callback)
	return newRender(self, callback)
end

function ScopeMethods:Map(target, callback, cleanupFn)
	return mapState(self, target, callback, cleanupFn)
end

function ScopeMethods:Select(target, key)
	return selectState(self, target, key)
end

function ScopeMethods:Scope(source, cheap)
	return buildScope(source, self.entity, cheap)
end

Heartbeat:Start()

local Wuye = {
	set = setState,
	add = addToScope,
	remove = removeFromScope,
	delete = deleteHandle,
	clean = cleanScope,

	Scope = scope,
	State = newState,
	Computed = newComputed,
	Watch = watch,
	Effect = newEffect,
	Render = newRender,
	Map = mapState,
	Select = selectState,
	Destroy = Cleanup,

	Throttle = Throttle,
	Debounce = Debounce,
	Is = Is,
	Benchmark = Benchmark,
}

export type Wuye = typeof(Wuye)

return Wuye