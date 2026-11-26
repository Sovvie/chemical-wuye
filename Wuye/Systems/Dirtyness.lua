local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions
local Utility = RootFolder.Utility

local JECS = require(Core.JECS)
local Tags = require(Definitions.Tags)

local World = require(Core.World)
local System = require(Utility.System)

local DirtyQuery = World:query(Tags.Producer)
	:with(Tags.Dirty, Tags.HasConsumers)
	:cached()

local dirtyProducers = table.create(64)

return System.new({
	Priority = System.Update,
	
	Process = function(_dt: number)
		local producerCount = 0

		for producer in DirtyQuery:iter() do
			producerCount += 1
			dirtyProducers[producerCount] = producer
			World:remove(producer, Tags.Dirty)
		end

		for index = 1, producerCount do
			local producer = dirtyProducers[index]
			dirtyProducers[index] = nil
			for consumer in World:each(JECS.pair(Tags.ConsumerOf, producer)) do
				World:add(consumer, Tags.Dirty)
			end
		end
	end
})

