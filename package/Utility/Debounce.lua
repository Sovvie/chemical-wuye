local module = {}

--[[
	Creates a new debounce function.

	This function acts as a manual re-entry guard. You call it to "lock" a section
	of code, and then call it again to "unlock" it.

	@returns function(boolean): boolean
--]]
function module.new()
	local isActive = false

	return function(canStart: boolean): boolean
		if canStart then
			if isActive then
				return true
			end

			isActive = true
			return false
		else
			isActive = false
			return false
		end
	end
end

return module
