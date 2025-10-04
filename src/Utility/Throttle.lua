

local module = {}

function module.new(duration: number)
	local clock = os.clock
	local timeAtThrottle = clock()
	
	return function()
		local timeAtStep = clock()
		if timeAtStep - timeAtThrottle >= duration then
			timeAtThrottle = timeAtStep
			return true
		end
		
		return false
	end
end

return module
