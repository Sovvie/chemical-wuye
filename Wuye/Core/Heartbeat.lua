local RunService = game:GetService("RunService")

local RootFolder = script.Parent.Parent
local SystemModules = RootFolder.Systems:GetChildren()
local SystemInfo = require(RootFolder.Utility.System)

local PHASE_ORDER = {
	SystemInfo.Update,
	SystemInfo.React,
	SystemInfo.Render,
}

local module = {}
local started = false

function module:Start()
	if started then
		return
	end

	started = true

	table.sort(SystemModules, function(a, b)
		return a.Name < b.Name
	end)

	local loadedSystems = table.create(#SystemModules)
	local loadedCount = 0
	for _, systemModule: ModuleScript in SystemModules do
		if not systemModule:IsA("ModuleScript") then
			continue
		end

		loadedCount += 1
		loadedSystems[loadedCount] = require(systemModule)
	end

	local phases = {}
	for i = 1, loadedCount do
		local system = loadedSystems[i]
		local priority = system.Priority
		local process = system.Process
		if not phases[priority] then
			phases[priority] = {}
		end

		if typeof(process) == "function" then
			table.insert(phases[priority], process)
		elseif typeof(process) == "table" then
			for index = 1, #process do
				table.insert(phases[priority], process[index])
			end
		end
	end

	local systems = table.create(loadedCount * 2)
	local systemCount = 0
	local usedPriorities = {}
	for i = 1, #PHASE_ORDER do
		local priority = PHASE_ORDER[i]
		usedPriorities[priority] = true
		local phase = phases[priority]
		if phase then
			for index = 1, #phase do
				systemCount += 1
				systems[systemCount] = phase[index]
			end
		end
	end

	local customPriorities = {}
	for priority in phases do
		if not usedPriorities[priority] then
			table.insert(customPriorities, priority)
		end
	end
	table.sort(customPriorities)
	for i = 1, #customPriorities do
		local phase = phases[customPriorities[i]]
		for index = 1, #phase do
			systemCount += 1
			systems[systemCount] = phase[index]
		end
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		for i = 1, systemCount do
			systems[i](deltaTime)
		end
	end)
end

return module
