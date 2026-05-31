local InlineInput = _G.InlineInput

InlineInput.VERSION = 2
InlineInput._registrations = InlineInput._registrations or {}
InlineInput._registration_order = InlineInput._registration_order or {}
InlineInput._log_once = InlineInput._log_once or {}

local function compact_log_value(value)
	value = tostring(value)
	value = string.gsub(value, "\n", "\\n")

	if string.len(value) > 80 then
		return string.sub(value, 1, 77) .. "..."
	end

	return value
end

function InlineInput:DebugEventsEnabled(config)
	return config and (config.debug_events == true or config.debug_lifecycle == true or config.debug == true)
end

local function debug_target_name(library, target)
	if type(library.DebugTargetName) == "function" then
		local ok, name = pcall(library.DebugTargetName, library, target)

		if ok and name ~= nil then
			return name
		end
	end

	return target
end

function InlineInput:LogDebugEvent(config, event, value, target, source)
	if not self:DebugEventsEnabled(config) then
		return
	end

	self:LogConsole(
		"event=" .. tostring(event)
			.. " id=" .. tostring(config and config.id)
			.. " source=" .. tostring(source)
			.. " value=\"" .. compact_log_value(value) .. "\""
			.. " node=" .. tostring(debug_target_name(self, target)),
		"debug"
	)
end

function InlineInput:SafeCall(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end

	local ok, result, result2, result3 = pcall(callback, ...)

	if ok then
		return result, result2, result3
	end

	self:LogInfo(result)
	return nil
end

function InlineInput:IsAlive(panel)
	return panel and (not alive or alive(panel))
end

return InlineInput
