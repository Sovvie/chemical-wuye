local RootFolder = script.Parent.Parent

local Core = RootFolder.Core

local JECS = require(Core.JECS)

local module = {}

function module.AOutLivesB(world: JECS.World, a: JECS.Entity, b: JECS.Entity)
	if not world:exists(a) or not world:exists(b) then return false end
	
	local scopeA = world:parent(a)
	local scopeB = world:parent(b)
	
	if scopeA == scopeB then
		return true
	end
	
	local currentScope = scopeA
	while currentScope do
		if currentScope == scopeB then
			return true
		end
		
		currentScope = world:parent(currentScope)
	end
	
	return false
end

return module
