local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter
local TextRange = InlineInput.TextRange

local set_visible = Adapter.set_visible
local control_number = Adapter.control_number
local set_shape = Adapter.set_shape
local text_render_width = TextRange.render_width

local function character_x(text, index, value_length)
	if text.character_rect then
		local ok, x, y, w, h = pcall(text.character_rect, text, index)

		if ok and type(x) == "number" then
			return x, y, w, h
		end
	end

	local text_x = control_number(text, "world_x", control_number(text, "x", 0))
	local width = text_render_width(text)

	if not width or value_length <= 0 then
		return text_x, control_number(text, "world_y", control_number(text, "y", 0)), 0, control_number(text, "h", 24)
	end

	return text_x + width * math.min(math.max(index or 0, 0), value_length) / value_length,
		control_number(text, "world_y", control_number(text, "y", 0)),
		0,
		control_number(text, "h", 24)
end

function InlineInput:SelectionHighlight(input_box)
	if not input_box or not input_box.panel then
		return nil
	end

	if input_box._inline_input_selection_highlight then
		return input_box._inline_input_selection_highlight
	end

	if not input_box.panel.rect then
		return nil
	end

	local config = input_box._inline_input_config
	local color = self:ResolvedSelectionBackgroundColor(config, input_box)
	local layer = input_box._inline_input_selection_layer
		or (input_box._inline_input_text_layer and input_box._inline_input_text_layer - 1)
		or 201
	local highlight = InlineInput:SafeCall(function()
		return input_box.panel:rect({
			x = 0,
			y = 0,
			w = 1,
			h = 1,
			layer = layer,
			color = color,
			visible = false
		})
	end)

	input_box._inline_input_selection_highlight = highlight
	return highlight
end

function InlineInput:ClearSelectionHighlight(input_box)
	local highlight = input_box and input_box._inline_input_selection_highlight

	if highlight then
		set_visible(highlight, false)
	end
end

function InlineInput:UpdateSelectionHighlight(input_box)
	local text = input_box and input_box.text
	local panel = input_box and input_box.panel

	if not text or not panel or not text.selection then
		self:ClearSelectionHighlight(input_box)
		return
	end

	if self.IsInputBoxUnfocused and self:IsInputBoxUnfocused(input_box) then
		self:ClearSelectionHighlight(input_box)
		return
	end

	local value = self:GetInputBoxText(input_box) or ""
	local start_index, end_index, length = TextRange.text_selection_bounds(text, value)

	if length <= 0 then
		self:ClearSelectionHighlight(input_box)
		return
	end

	start_index = math.max(math.min(start_index, length), 0)
	end_index = math.max(math.min(end_index, length), 0)

	if start_index == end_index then
		self:ClearSelectionHighlight(input_box)
		return
	end

	local start_x, start_y, _, start_h = character_x(text, start_index, length)
	local end_x = character_x(text, end_index, length)
	local panel_x = control_number(panel, "world_x", control_number(panel, "x", 0))
	local panel_y = control_number(panel, "world_y", control_number(panel, "y", 0))
	local padding = self:InputTextPadding()
	local left = panel_x + padding
	local right = panel_x + math.max(control_number(panel, "w", 0) - padding, padding)

	start_x = math.max(start_x or left, left)
	end_x = math.min(end_x or right, right)

	if end_x <= start_x then
		self:ClearSelectionHighlight(input_box)
		return
	end

	local highlight = self:SelectionHighlight(input_box)

	if not highlight then
		return
	end

	local config = input_box._inline_input_config
	local color = self:ResolvedSelectionBackgroundColor(config, input_box)
	local layer = input_box._inline_input_selection_layer
		or (input_box._inline_input_text_layer and input_box._inline_input_text_layer - 1)

	if color and highlight.set_color then
		highlight:set_color(color)
	end

	if layer and highlight.set_layer then
		highlight:set_layer(layer)
	end

	set_shape(highlight, start_x - panel_x, (start_y or panel_y) - panel_y, end_x - start_x, start_h or control_number(text, "h", control_number(panel, "h", 24)))
	set_visible(highlight, true)
end

return InlineInput
