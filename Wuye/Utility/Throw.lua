local RunService = game:GetService("RunService")

local IsStudio = RunService:IsStudio()

local module = {}
local messages = {}

function module.Message(msg)
	table.insert(messages, msg)
	return #messages
end

function module.Emit(depth: number, messageId: number, ...)
	if IsStudio then
		warn(messages[messageId], ...)
		warn(debug.info(depth, "sln"))
	end
end

return module
