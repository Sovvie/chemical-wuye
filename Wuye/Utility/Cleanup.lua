local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions

local Components = require(Definitions.Components)
local Tags = require(Definitions.Tags)
local World = require(Core.World)

local function cleanup(thing: any, ...)
	local world = World

	local typeOfSubject = typeof(thing)
	if typeOfSubject == "number" then
		if not world:contains(thing) then return end

		world:add(thing, Tags.Cleaning)
		world:delete(thing)
	elseif typeOfSubject == "table" then
		local entity = thing.entity
		if entity then
			if World:has(entity, Tags.Scope) then
				local things = World:get(entity, Components.CacheTable)
				for _, thing2 in things do
					cleanup(thing2)
				end

				return
			elseif world:contains(entity) then
				world:add(entity, Tags.Cleaning)
				world:delete(entity)
			end
		else
			local method = thing.disconnect
				or thing.Disconnect
				or thing.destroy
				or thing.Destroy

			if method and method ~= cleanup then
				method(thing)
			end

			if getmetatable(thing) then
				setmetatable(thing, nil)
				table.clear(thing)

				return
			end

			for _, value in thing do
				cleanup(value)
			end
		end
	elseif typeOfSubject == "Instance" then
		thing:Destroy()
	elseif typeOfSubject == "RBXScriptConnection" then
		thing:Disconnect()
	elseif typeOfSubject == "function" then
		thing(...)
	elseif typeOfSubject == "thread" then
		task.cancel(thing)
	end
end

return cleanup
