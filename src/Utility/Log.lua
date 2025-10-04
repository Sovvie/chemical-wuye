local Logger = {}

local STYLES = {
	WARN = { prefix = "WARNING", color = "rgb(255, 200, 0)" },
	ERROR = { prefix = "ERROR", color = "rgb(255, 80, 80)" },
}
local SOURCE_COLOR = "rgb(180, 180, 180)"

local function doLog(level, moduleName, stackLevel, message, ...)
	if select("#", ...) > 0 then
		message = string.format(message, ...)
	end

	local style = STYLES[level]
	if not style then
		return
	end

	local source, line = debug.info(stackLevel, "sl")
	local sourceInfo = string.format("Source: %s:%d", source, line)

	local formattedOutput = string.format(
		'[%s] %s\n  %s\n  %s',
		moduleName,
		style.prefix,
		sourceInfo,
		message
	)

	if level == "ERROR" then
		error(formattedOutput, 0)
	else
		warn(formattedOutput)
	end
end

--[[
	Logs a warning message (yellow).

	@param moduleName string :: The name of the module/system logging the warning.
	@param message string :: The message to log, can be a format string.
	@param ... any :: Variadic arguments for the format string.
--]]
function Logger.warn(moduleName, depth, message, ...)
	doLog("WARN", moduleName, depth, message, ...)
end

--[[
	Logs an error message (red).

	@param moduleName string :: The name of the module/system logging the error.
	@param message string :: The message to log, can be a format string.
	@param ... any :: Variadic arguments for the format string.
--]]
function Logger.error(moduleName, depth, message, ...)
	doLog("ERROR", moduleName, depth, message, ...)
end

return Logger