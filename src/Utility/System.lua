local module = {}

module.Update = 1
module.React = 2
module.Render = 3

function module.new(
	config: {
		Priority: number,
		Process: (dt: number) -> () | { (dt: number) -> () },
	}
)
	local system = config
	system.PROCESS_TYPE = typeof(system.Process)


	return system
end

return module
