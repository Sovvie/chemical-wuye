local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions
local Utility = RootFolder.Utility

local JECS = require(Core.JECS)
local Tags = require(Definitions.Tags)
local Components = require(Definitions.Components)

local World = require(Core.World)
local System = require(Utility.System)

local DirtyOnChangeQuery = World:query(JECS.pair(Tags.OnChange, Components.Callback))
	:with(Tags.Consumer, Tags.Dirty, JECS.pair(Tags.RuntimeOf, Tags.React))
	:cached()
local DirtyEffectsQuery = World:query(JECS.pair(Tags.OnUpdate, Components.Callback))
	:with(Tags.Consumer, Tags.Dirty, JECS.pair(Tags.RuntimeOf, Tags.React))
	:cached()

local PREVIOUS_STATE_PAIR = JECS.pair(Tags.Previous, Components.State)

return System.new({
	Priority = System.React,
	
	Process = function(dt: number)
		for consumer, callback in DirtyOnChangeQuery:iter() do
			World:remove(consumer, Tags.Dirty)
			
			local s = os.clock()
			local target = World:target(consumer, Tags.ConsumerOf)

			callback(World:get(target, Components.State), World:get(target, PREVIOUS_STATE_PAIR))
			if World:has(target, Tags.Mapper) then print(os.clock() - s) end
		end

		for consumer, callback in DirtyEffectsQuery:iter() do
			World:remove(consumer, Tags.Dirty)
			
			callback()
		end
	end
})

