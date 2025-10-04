local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions
local Utility = RootFolder.Utility

local JECS = require(Core.JECS)
local Tags = require(Definitions.Tags)
local Components = require(Definitions.Components)

local World = require(Core.World)
local System = require(Utility.System)

local DirtyQuery = World:query(Tags.Producer)
	:with(Tags.Dirty, Tags.HasConsumers)
	:cached()

return System.new({
	Priority = System.Update,
	
	Process = function(dt: number)
		for producer in DirtyQuery:iter() do
			World:remove(producer, Tags.Dirty)

			for consumer in World:each(JECS.pair(Tags.ConsumerOf, producer)) do
				World:add(consumer, Tags.Dirty)
			end
		end
	end
})

