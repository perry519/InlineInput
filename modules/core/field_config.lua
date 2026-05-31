local InlineInput = _G.InlineInput

local function config_value(config, key)
	local value = config and config[key]
	return type(value) == "function" and InlineInput:SafeCall(value, config) or value
end

function InlineInput:GetValue(config)
	local value = InlineInput:SafeCall(config and config.get_value, config)

	if value == nil then
		value = config and config.value
	end

	return tostring(value or "")
end

function InlineInput:GetMaxLength(config)
	local max_length = config and (config.max_length or config.max_input_length)
	if type(max_length) == "number" then
		max_length = math.floor(max_length)
		return max_length >= 0 and max_length or nil
	end
end

function InlineInput:NormalizeText(config, value)
	value = tostring(value or "")

	local max_length = self:GetMaxLength(config)

	if max_length and string.len(value) > max_length then
		value = string.sub(value, 1, max_length)
	end

	return value
end

function InlineInput:GetPlaceholder(config)
	local value = config_value(config, "placeholder_text")
	if value == nil then
		value = config_value(config, "placeholder")
	end
	return value ~= nil and tostring(value) or nil
end

function InlineInput:ValidateParsedValue(config, value)
	local parser = config and (config.value_type or config.parse or config.parser)

	if config and config.numeric == true then
		parser = "number"
	end

	if parser ~= "number" then
		return true, value, value
	end

	local number = tonumber(value)
	if
		number == nil
		or (type(config.min_value) == "number" and number < config.min_value)
		or (type(config.max_value) == "number" and number > config.max_value)
	then
		return false, value, nil
	end

	return true, tostring(number), number
end

function InlineInput:SetValue(config, value, context, source)
	if value == nil then
		value = ""
	end

	if type(config.set_value) == "function" then
		InlineInput:SafeCall(config.set_value, value, context, source, config)
	else
		config.value = value
	end
end

function InlineInput:ValidateValue(config, value, context, source)
	value = self:NormalizeText(config, value)

	if type(config and config.validate) ~= "function" then
		return self:ValidateParsedValue(config, value)
	end

	local result, stored_value, display_value = InlineInput:SafeCall(config.validate, value, context, source, config)

	if result == false or result == nil then
		return false, value, nil
	end

	if result == true then
		if stored_value == nil then
			stored_value = value
		end
	else
		stored_value = result
	end

	if display_value == nil then
		display_value = stored_value
	end

	return true, tostring(display_value or ""), stored_value
end

function InlineInput:ShouldApplyValue(config, source)
	if source == "change" or source == "repeat" then
		local mode = config and (config.apply_mode or config.apply)
		return not (config and config.commit_only == true) and mode ~= "commit" and mode ~= "submit"
	end

	return true
end

function InlineInput:EscapeBehavior(config)
	if config and config.clear_on_escape == false then
		return "blur"
	end

	local behavior = config and (config.esc_behavior or config.escape_behavior) or "clear"

	if behavior == "keep" or behavior == "preserve" or behavior == "none" then
		return "blur"
	elseif behavior == "reset" then
		return "clear"
	end

	return behavior
end

function InlineInput:ShouldPropagateEscape(config)
	if config and config.allow_escape_propagation ~= nil then
		return config.allow_escape_propagation == true
	end

	return self.DEFAULTS.allow_escape_propagation == true
end

return InlineInput
