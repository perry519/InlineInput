local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter

local TEXT_PADDING = 12
local text_color_state = setmetatable({}, { __mode = "k" })

local set_visible = Adapter.set_visible
local same_color = Adapter.same_color
local control_value = Adapter.control_value

local function config_value(config, keys, input_box)
	for _, key in ipairs(keys or {}) do
		local value = config and config[key]

		if value ~= nil then
			return type(value) == "function" and InlineInput:SafeCall(value, config, input_box) or value
		end
	end

	for _, key in ipairs(keys or {}) do
		local value = InlineInput.DEFAULTS and InlineInput.DEFAULTS[key]

		if value ~= nil then
			return type(value) == "function" and InlineInput:SafeCall(value, config, input_box) or value
		end
	end
end

function InlineInput:TextColor()
	local screen_colors = tweak_data and tweak_data.screen_colors

	if screen_colors then
		return screen_colors.text or screen_colors.button_stage_2 or screen_colors.button_stage_3
	end

	return Color and Color.white or nil
end

function InlineInput:ResolvedTextColor(config, input_box)
	return config_value(config, { "text_color", "input_text_color" }, input_box)
		or self:TextColor()
end

function InlineInput:InputBackgroundColor(config, input_box)
	return config_value(config, { "background_color", "input_background_color", "bg_color" }, input_box)
end

function InlineInput:PlaceholderColor(config, input_box)
	local color = config_value(config, { "placeholder_color", "inactive_placeholder_color" }, input_box)

	if color then
		return color
	end

	local text_color = self:ResolvedTextColor(config, input_box)

	if text_color and text_color.with_alpha then
		local ok, color = pcall(text_color.with_alpha, text_color, 0.45)

		if ok and color then
			return color
		end
	end

	return Color and Color(0.45, 1, 1, 1) or text_color
end

function InlineInput:ResolvedPlaceholderColor(config, input_box)
	return config_value(config, { "placeholder_color", "inactive_placeholder_color" }, input_box)
		or self:PlaceholderColor(config, input_box)
end

function InlineInput:ActivePlaceholderColor(config, input_box)
	return config_value(config, { "active_placeholder_color", "focused_placeholder_color" }, input_box)
		or self:ResolvedPlaceholderColor(config, input_box)
end

function InlineInput:InputTextPadding()
	return TEXT_PADDING
end

function InlineInput:SelectionColor()
	return Color and Color.white or nil
end

function InlineInput:ResolvedSelectionColor(config, input_box)
	return config_value(config, { "selection_color", "selected_text_color" }, input_box)
		or self:SelectionColor()
end

function InlineInput:SelectionBackgroundColor()
	return Color and Color(0.35, 0.00, 0.85, 1.00) or nil
end

function InlineInput:ResolvedSelectionBackgroundColor(config, input_box)
	return config_value(config, {
		"selection_background_color",
		"selection_bg_color",
		"selection_highlight_color",
		"selection_highlight_bg_color",
		"selected_text_background_color",
		"selected_text_highlight_color",
		"selected_text_highlight_bg_color"
	}, input_box) or self:SelectionBackgroundColor()
end

function InlineInput:ShouldShowBrackets(config)
	if config then
		if config.show_brackets ~= nil then
			return config.show_brackets ~= false
		end

		if config.show_input_brackets ~= nil then
			return config.show_input_brackets ~= false
		end

		if config.hide_brackets ~= nil then
			return config.hide_brackets ~= true
		end

		if config.remove_brackets ~= nil then
			return config.remove_brackets ~= true
		end
	end

	return self.DEFAULTS.show_brackets ~= false
end

function InlineInput:TextFont(input_box)
	local font = control_value(input_box and input_box.text, "font")

	if font then
		return font
	end

	return tweak_data and tweak_data.menu and tweak_data.menu.pd2_medium_font or nil
end

function InlineInput:TextFontSize(input_box)
	local font_size = control_value(input_box and input_box.text, "font_size")

	if type(font_size) == "number" then
		return font_size
	end

	return tweak_data and tweak_data.menu and tweak_data.menu.pd2_medium_font_size or nil
end

function InlineInput:ApplyTextFont(text, input_box)
	if not text then
		return
	end

	local font = self:TextFont(input_box)
	local font_size = self:TextFontSize(input_box)

	if font and text.set_font then
		InlineInput:SafeCall(function()
			text:set_font(font)
		end)
	end

	if font_size and text.set_font_size then
		InlineInput:SafeCall(function()
			text:set_font_size(font_size)
		end)
	end
end

function InlineInput:StyleText(text, width, layer, scroll_x, override_color, config, input_box)
	if not text then
		return
	end

	local padding = self:InputTextPadding()
	local color = override_color or self:ResolvedTextColor(config, input_box)
	local selection_color = self:ResolvedSelectionColor(config, input_box)
	scroll_x = math.max(type(scroll_x) == "number" and scroll_x or 0, 0)

	if text.set_layer and control_value(text, "layer") ~= layer then
		text:set_layer(layer)
	end

	if color and text.set_color and not same_color(text_color_state[text], color) then
		text:set_color(color)
		text_color_state[text] = color
	end

	if selection_color and text.set_selection_color then
		InlineInput:SafeCall(function()
			text:set_selection_color(selection_color)
		end)
	end

	if text.set_align then
		text:set_align("left")
	end

	if text.set_x and control_value(text, "x") ~= padding - scroll_x then
		text:set_x(padding - scroll_x)
	end

	if text.set_w then
		local text_width = math.max(width - padding * 2 + scroll_x, 1)

		if control_value(text, "w") ~= text_width then
			text:set_w(text_width)
		end
	end
end

function InlineInput:StylePassiveText(text, width, layer, x, input_box, override_color, config)
	local padding = self:InputTextPadding()
	width = type(width) == "number" and width or padding * 2 + 1

	self:StyleText(text, width, layer, 0, override_color, config, input_box)
	self:ApplyTextFont(text, input_box)
	x = (type(x) == "number" and x or 0) + padding

	if text and text.set_x and control_value(text, "x") ~= x then
		text:set_x(x)
	end

	if text and text.set_w then
		local text_width = math.max(width - padding * 2, 1)

		if control_value(text, "w") ~= text_width then
			text:set_w(text_width)
		end
	end
end

function InlineInput:UpdateInputBoxPlaceholderVisibility(input_box)
	if input_box and input_box.placeholder_text then
		local active = input_box._inline_input_edit_visible == true
		local empty = self:GetInputBoxText(input_box) == ""
		local passive_text = input_box._inline_input_passive_text

		set_visible(input_box.placeholder_text, false)

		if active and empty then
			self:UpdatePassiveText(input_box._inline_input_config, input_box, true)
			passive_text = input_box._inline_input_passive_text
			set_visible(passive_text, true)
		elseif active then
			set_visible(passive_text, false)
		end
	end
end

function InlineInput:ApplyInputTextScroll(input_box, scroll_x)
	if not input_box or not input_box.text then
		return
	end

	scroll_x = math.max(type(scroll_x) == "number" and scroll_x or 0, 0)
	input_box._inline_input_scroll_x = scroll_x

	local width = input_box._inline_input_panel_width
	local panel = input_box.panel

	if not width and panel and panel.w then
		width = panel:w()
	end

	if not width then
		return
	end

	self:StyleText(input_box.text, width, input_box._inline_input_text_layer, scroll_x, nil, input_box._inline_input_config, input_box)
end

return InlineInput
