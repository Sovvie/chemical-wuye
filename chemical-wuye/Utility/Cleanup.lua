local RootFolder = script.Parent.Parent

local Core = RootFolder.Core
local Definitions = RootFolder.Definitions

local Tags = require(Definitions.Tags)
local World = require(Core.World)

local function cleanup<T>(thing: T, ...)
	local world = World

	local typeOfSubject = typeof(thing)
	if typeOfSubject == "number" then
		if not world:contains(thing) then return end

		world:add(thing, Tags.Cleaning)
		world:delete(thing)
	elseif typeOfSubject == "table" then
		if thing.entity then
			if world:contains(thing.entity) then
				world:add(thing.entity, Tags.Cleaning)
				world:delete(thing.entity)
			end
		else
			local method = thing.disconnect
				or thing.Disconnect
				or thing.destroy
				or thing.Destroy

			if method and method ~= cleanup then
				method(thing, ...)
			end
		end

		if getmetatable(thing) then
			setmetatable(thing, nil)
			table.clear(thing)

			return
		end

		for _, value in thing do
			cleanup(value)
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
