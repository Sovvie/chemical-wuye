local RunService = game:GetService("RunService")

local RootFolder = script.Parent.Parent
local Systems = RootFolder.Systems:GetChildren()

local module = {}

function module:Start()
	local systemModules = {}
	for _, system: ModuleScript in Systems do
		if not system:IsA("ModuleScript") then return end
		
		table.insert(systemModules, require(system))
	end
	
	local phases = {}
	for _, system in systemModules do
		local priority = system.Priority
		local process = system.Process
		if typeof(process) == "function" then
			process = { process }
		end
		
		if not phases[priority] then phases[priority] = {} end
		table.insert(phases[priority], process)
	end
	
	local systems = {}
	local pointer = 0
	for priority, phase in phases do
		for i, processes in phase do
			pointer += 1
			table.move(processes, 1, #processes, pointer, systems)
		end
	end
	
	RunService.Heartbeat:Connect(function(deltaTime: number)
		for _, process in systems do
			process(deltaTime)
		end
	end)
end

return module
