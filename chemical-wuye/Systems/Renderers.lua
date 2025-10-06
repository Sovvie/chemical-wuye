local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions
local Utility = RootFolder.Utility

local JECS = require(Core.JECS)
local Tags = require(Definitions.Tags)
local Components = require(Definitions.Components)

local World = require(Core.World)
local System = require(Utility.System)

local DirtyEffectsQuery = World:query(JECS.pair(Tags.OnUpdate, Components.Callback))
	:with(Tags.Consumer, Tags.Dirty, JECS.pair(Tags.RuntimeOf, Tags.Render))
	:cached()

return System.new({
	Priority = System.Render,
	
	Process = function(dt: number)
		for consumer, callback in DirtyEffectsQuery:iter() do
			World:remove(consumer, Tags.Dirty)

			callback()
		end
	end
})

