local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter

local set_visible = Adapter.set_visible
local control_value = Adapter.control_value

local function config_number(config, keys)
	for _, key in ipairs(keys) do
		local value = config and config[key]

		if type(value) == "function" then
			value = InlineInput:SafeCall(value, config)
		end

		if type(value) == "number" then
			return value
		end
	end
end

local function input_panel_width(config, available_width)
	if type(available_width) ~= "number" then
		return available_width
	end

	local width = available_width
	local scale = config_number(config, { "input_width_scale", "width_scale" })

	if scale and scale > 0 then
		width = width * scale
	end

	local explicit_width = config_number(config, { "input_width", "field_width" })

	if explicit_width and explicit_width > 0 then
		width = math.min(width, explicit_width)
	end

	return math.max(1, math.floor(width + 0.5))
end

function InlineInput:CreatePassiveText(config, input_box)
	if not input_box or input_box._inline_input_passive_text then
		return input_box._inline_input_passive_text
	end

	local input_panel = input_box.panel

	if not input_panel or not input_panel.text then
		return nil
	end

	local width = input_panel.w and input_panel:w() or input_box._inline_input_panel_width or 256
	local height = input_panel.h and input_panel:h() or 24
	local layer = (config.layer or 200) + 4
	local text = nil

	local ok, created = pcall(function()
		return input_panel:text({
			name = tostring(config.id) .. "_passive_text",
			text = "",
			x = 0,
			y = 0,
			w = width,
			h = height,
			layer = layer,
			font = self:TextFont(input_box),
			font_size = self:TextFontSize(input_box),
			color = self:ResolvedTextColor(config, input_box),
			vertical = "center",
			align = "left"
		})
	end)

	if ok and created then
		text = created
		input_box._inline_input_passive_text = text
	end

	return text
end

function InlineInput:UpdatePassiveText(config, input_box, active)
	local text = self:CreatePassiveText(config, input_box)

	if not text or not text.set_text then
		return
	end

	local value = active and (self:GetInputBoxText(input_box) or "") or self:GetValue(config)
	local is_placeholder = tostring(value or "") == ""

	if is_placeholder then
		value = self:GetPlaceholder(config) or ""
	end

	value = tostring(value or "")

	if text.text then
		local ok, current = pcall(text.text, text)

		if not ok or current ~= value then
			text:set_text(value)
		end
	else
		text:set_text(value)
	end

	local input_panel = input_box and input_box.panel
	local width = input_panel and input_panel.w and input_panel:w() or input_box._inline_input_panel_width
	local height = input_panel and input_panel.h and input_panel:h()

	if text.set_y and control_value(text, "y") ~= 0 then
		text:set_y(0)
	end

	local placeholder_color = nil

	if is_placeholder then
		placeholder_color = active and self:ActivePlaceholderColor(config, input_box)
			or self:ResolvedPlaceholderColor(config, input_box)
	end

	self:StylePassiveText(
		text,
		width,
		active and input_box._inline_input_placeholder_layer or (config.layer or 200) + 4,
		0,
		input_box,
		placeholder_color,
		config
	)

	if height and text.set_h and control_value(text, "h") ~= height then
		text:set_h(height)
	end

	return text
end

function InlineInput:SetInputBoxEditVisible(config, input_box, visible)
	if not input_box then
		return
	end

	input_box._inline_input_edit_visible = visible == true

	if visible then
		set_visible(input_box.text, true)
		self:UpdateInputBoxPlaceholderVisibility(input_box)
		self:UpdateSelectionHighlight(input_box)
		return
	end

	local passive_text = self:UpdatePassiveText(config, input_box)
	set_visible(input_box.text, passive_text == nil)
	set_visible(input_box.placeholder_text, false)
	set_visible(passive_text, true)
	self:ClearSelectionHighlight(input_box)
	self:HideCaret(input_box)
end

function InlineInput:Position(config, node_gui, row_item)
	local input_box = self:GetInputBox(config.id, node_gui)

	if not input_box or not self:IsAlive(input_box.panel) or not self:IsAlive(node_gui.item_panel) then
		return
	end

	local panel = input_box.panel
	local row_panel = row_item and row_item.gui_panel
	local available_width = row_panel and row_panel.w and row_panel:w()
		or node_gui.item_panel.w and node_gui.item_panel:w()
		or panel:w()
	local width = input_panel_width(config, available_width)
	local height = row_panel and row_panel.h and row_panel:h() or panel:h()
	local x = row_panel and row_panel.x and row_panel:x() or panel:x()
	local y = row_panel and row_panel.y and row_panel:y() or panel:y()

	if panel.set_layer and control_value(panel, "layer") ~= (config.layer or 200) then
		panel:set_layer(config.layer or 200)
	end

	if panel.set_x and control_value(panel, "x") ~= x then
		panel:set_x(x)
	end

	if panel.set_y and control_value(panel, "y") ~= y then
		panel:set_y(y)
	end

	if panel.set_w and control_value(panel, "w") ~= width then
		panel:set_w(width)
	end

	if panel.set_h and control_value(panel, "h") ~= height then
		panel:set_h(height)
	end

	local layer = config.layer or 200
	local previous_position = input_box._inline_input_position_state
	local position_changed = not previous_position
		or previous_position.x ~= x
		or previous_position.y ~= y
		or previous_position.width ~= width
		or previous_position.height ~= height
	input_box._inline_input_position_state = {
		x = x,
		y = y,
		width = width,
		height = height,
	}

	input_box._inline_input_panel_width = width
	input_box._inline_input_placeholder_layer = layer + 1
	input_box._inline_input_selection_layer = layer + 1
	input_box._inline_input_text_layer = layer + 2

	input_box._inline_input_config = config
	self:ApplyInputBackgroundColor(config, input_box)
	self:ApplyInputBracketsVisibility(config, input_box)
	self:ApplyInputTextScroll(input_box, input_box._inline_input_scroll_x)
	self:UpdatePassiveText(config, input_box, self:IsActiveInputBox(config, node_gui, input_box))

	self:StyleCaret(input_box, layer + 3)

	if position_changed and input_box.update_caret then
		input_box:update_caret()
	end
end

function InlineInput:Create(config, node_gui, row_item)
	local input_box_class = self:InputBoxClass()

	if not input_box_class or not node_gui or not node_gui.item_panel then
		self:LogOnce("create_missing_" .. tostring(config and config.id), "create skipped for " .. tostring(config and config.id) .. ": input_box_class=" .. tostring(input_box_class ~= nil) .. ", node_gui=" .. tostring(node_gui ~= nil) .. ", item_panel=" .. tostring(node_gui and node_gui.item_panel ~= nil))
		return nil
	end

	local available_width = node_gui.item_panel.w and node_gui.item_panel:w() or 256
	local width = input_panel_width(config, available_width)
	local height = row_item and row_item.gui_panel and row_item.gui_panel.h and row_item.gui_panel:h() or nil
	local input_box = input_box_class:new(node_gui.item_panel, node_gui.ws, self:GetValue(config), {
		w = width,
		h = height,
		layer = config.layer or 200
	})
	input_box._inline_input_config = config

	self:ApplyMaxLength(config, input_box)
	self:PatchInputBoxCaret(input_box)
	self:PatchInputBoxKeys(input_box, config, node_gui)
	self:BindInputBoxCallbacks(config, node_gui, input_box)
	self:SetPlaceholderText(config, input_box)
	self:ApplyInputBackgroundColor(config, input_box)
	self:ApplyInputBracketsVisibility(config, input_box)

	input_box:register_callback(function(_, input_text)
		if not self:IsActiveInputBox(config, node_gui, input_box) then
			return
		end

		if input_text == nil and input_box.text and input_box.text.text then
			input_text = input_box.text:text()
		end

		self:ApplyValue(config, node_gui, input_text, "change")
	end)

	if input_box.register_disconnect_callback then
		input_box:register_disconnect_callback(function(input_text)
			if not input_box._inline_input_wrapped_disconnect
				and not input_box._inline_input_destroying
				and not self:IsActiveInputBox(config, node_gui, input_box) then
				return
			end

			if input_box._inline_input_blurring then
				return
			end

			if input_box._inline_input_destroying and config.apply_on_destroy ~= true then
				return
			end

			local wrapped_disconnect = input_box._inline_input_wrapped_disconnect == true

			if config.apply_on_disconnect ~= false then
				self:ApplyValue(config, node_gui, input_text, "disconnect")
			end

			if not wrapped_disconnect then
				local callback_value = self:GetValue(config)
				local blurred = self:NotifyBlur(config, node_gui, input_box, "disconnect", callback_value)

				if blurred then
					self:NotifyFinish(config, node_gui, input_box, callback_value, "disconnect")
				end
			end
		end)
	end

	self:SetInputBox(config.id, node_gui, input_box)
	self:Position(config, node_gui, row_item)
	self:LogOnce("created_" .. tostring(config.id), "created input_box for " .. tostring(config.id))

	return input_box
end

return InlineInput
