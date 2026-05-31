local InlineInput = _G.InlineInput

local LOG_PREFIX = "[InlineInput] "
local CONSOLE_PREFIX = "[InlineInput] "

InlineInput._log_once = InlineInput._log_once or {}

local function log_level_value(level)
	if type(level) == "number" then
		return level
	end

	local key = type(level) == "string" and string.lower(level) or "debug"
	local levels = LogLevel or {}

	if key == "error" then
		return levels.ERROR or 1
	elseif key == "warn" then
		return levels.WARN or 2
	elseif key == "info" then
		return levels.INFO or 3
	end

	return levels.ALL or 4
end

local function log_level_label(level)
	level = log_level_value(level)

	if level == (LogLevel and LogLevel.ERROR or 1) then
		return "ERROR"
	elseif level == (LogLevel and LogLevel.WARN or 2) then
		return "WARN"
	elseif level == (LogLevel and LogLevel.INFO or 3) then
		return "INFO"
	elseif level == (LogLevel and LogLevel.ALL or 4) then
		return "DEBUG"
	end

	return nil
end

function InlineInput:IsLogLevelEnabled(level)
	if BLTLogs and type(BLTLogs.log_level) == "number" then
		return log_level_value(level) <= BLTLogs.log_level
	end

	return true
end

function InlineInput:FormatLogMessage(message, level)
	local label = log_level_label(level)

	return LOG_PREFIX .. (label and (label .. ": ") or "") .. tostring(message)
end

function InlineInput:LogFile(message, level)
	level = level or "debug"

	if not self:IsLogLevelEnabled(level) then
		return false
	end

	if BLT and type(BLT.Log) == "function" then
		local ok = pcall(BLT.Log, BLT, log_level_value(level), LOG_PREFIX .. tostring(message))

		if ok then
			return true
		end
	end

	if log then
		log(self:FormatLogMessage(message, level))
		return true
	end

	return false
end

function InlineInput:LogConsole(message)
	local text = CONSOLE_PREFIX .. tostring(message)

	if Console then
		local console_log = Console.Log or Console.log

		if console_log then
			local ok = pcall(console_log, Console, text)

			if ok then
				return true
			end
		end
	end

	return false
end

function InlineInput:LogOnce(key, message, level)
	if self._log_once[key] then
		return false
	end

	local logged = self:LogFile(message, level)

	if logged then
		self._log_once[key] = true
	end

	return logged
end

function InlineInput:LogInfo(message)
	self:LogFile(message, "info")
end

return InlineInput
