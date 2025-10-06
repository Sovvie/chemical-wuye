local RunService = game:GetService("RunService")

local IsStudio = RunService:IsStudio()

local module = {}
local messages = {}

function module.Message(msg)
	table.insert(messages, msg)
	return #messages
end

return setmetatable(module, {
	__index = module, --TODO test if needed
	__call = function(self, depth: number, messageId: number, ...)
		if IsStudio then
			warn(messages[messageId], ...)
			warn(debug.info(depth, "sln"))
		end
	end,
}) :: { Message: (msg: string) -> number } & (depth: number, messageId: number, ...any) -> ()
