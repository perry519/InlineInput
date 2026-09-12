local InlineInput = _G.InlineInput
local TextRange = InlineInput.TextRange
local text_length = TextRange.length
local selection_bounds = TextRange.text_selection_bounds
local clamp_index = TextRange.clamp_index
local text_render_width = TextRange.render_width

local CARET_PATCH_VERSION = 10
local CARET_BLINK_INTERVAL = 0.3
local TEXT_VIEWPORT_MARGIN = 2

local function input_unfocused(input_box)
	return input_box and input_box.input_focus and not input_box:input_focus()
end

function InlineInput:IsInputBoxUnfocused(input_box)
	return input_unfocused(input_box)
end

local function set_caret_alpha(caret, alpha)
	if caret and caret.set_alpha then
		caret:set_alpha(alpha)
		return true
	end

	if not caret or not caret.set_color then
		return false
	end

	if caret.color then
		local ok, color = pcall(caret.color, caret)

		if ok and color and color.with_alpha then
			caret:set_color(color:with_alpha(alpha))
			return true
		end
	end

	if Color then
		caret:set_color(Color(alpha, 1, 1, 1))
		return true
	end

	return false
end

local function control_number(control, method, fallback)
	if control and control[method] then
		local ok, value = pcall(control[method], control)

		if ok and type(value) == "number" then
			return value
		end
	end

	return fallback or 0
end

local function positive_number(value, fallback)
	if type(value) == "number" and value > 0 then
		return value
	end

	return fallback or 0
end

local function text_control_height(input_box, text)
	return control_number(text, "h", control_number(input_box and input_box.panel, "h", 24))
end

local function text_world_y(input_box, text)
	if text and text.world_y then
		local ok, value = pcall(text.world_y, text)

		if ok and type(value) == "number" then
			return value
		end
	end

	local panel = input_box and input_box.panel
	return control_number(panel, "world_y", control_number(panel, "y", 0)) + control_number(text, "y", 0)
end

local function text_font_height(input_box, text, fallback)
	local font_size = nil

	if InlineInput.TextFontSize then
		local ok, value = pcall(InlineInput.TextFontSize, InlineInput, input_box)

		if ok then
			font_size = value
		end
	end

	if type(font_size) ~= "number" or font_size <= 0 then
		font_size = control_number(text, "font_size", fallback)
	end

	return positive_number(font_size, fallback)
end

local function fallback_caret_geometry(input_box, text)
	local control_height = text_control_height(input_box, text)
	local height = text_font_height(input_box, text, control_height)

	if control_height > 0 then
		height = math.min(height, control_height)
	end

	local y = text_world_y(input_box, text)

	if control_height > height then
		y = y + (control_height - height) / 2
	end

	return y, height
end

local function selection_index(input_box, text, value)
	local start_index, end_index = selection_bounds(text, value)

	if start_index == end_index then
		return end_index
	end

	local stored_index = input_box and input_box._inline_input_caret_index
	if type(stored_index) == "number" and stored_index >= start_index and stored_index <= end_index then
		return stored_index
	end

	if text and text.selection then
		local ok, selection_start, selection_end = pcall(text.selection, text)

		if ok then
			local index = selection_end

			if type(index) ~= "number" then
				index = selection_start
			end

			if type(index) == "number" then
				return math.max(index, 0)
			end
		end
	end

	return text_length(value)
end

local function caret_world_x(input_box, value)
	local text = input_box and input_box.text

	if not text then
		return nil
	end

	local index = selection_index(input_box, text, value)

	if index <= 0 then
		return control_number(text, "world_x", control_number(text, "x", 0))
	end

	if text.character_rect then
		local ok, x = pcall(text.character_rect, text, index)

		if ok and type(x) == "number" then
			return x
		end
	end

	local text_x = control_number(text, "world_x", control_number(text, "x", 0))
	local width = text_render_width(text)
	local length = text_length(value)

	if not width or length <= 0 then
		return text_x
	end

	return text_x + width * math.min(index, length) / length
end

local function position_caret_at_selection(input_box)
	local text = input_box and input_box.text
	local caret = input_box and input_box.caret

	if not text or not caret or not caret.set_world_shape then
		return
	end

	local value = input_box.text and input_box.text.text and input_box.text:text() or ""
	local index = selection_index(input_box, text, value)
	local x = nil
	local y, height = fallback_caret_geometry(input_box, text)

	if index > 0 and text.character_rect then
		local ok, rect_x, rect_y, rect_w, rect_h = pcall(text.character_rect, text, index)
		if ok and type(rect_x) == "number" then
			x = rect_x
			y = type(rect_y) == "number" and rect_y or y
			height = type(rect_h) == "number" and rect_h or height
		end
	end

	if not x then
		x = caret_world_x(input_box, value) or control_number(text, "world_x", control_number(text, "x", 0))
	end

	caret:set_world_shape(x, y + 2, 3, math.max(height - 4, 0))
end

local function character_slot_x(text, index, value_length, render_width)
	if index <= 0 then
		return control_number(text, "world_x", control_number(text, "x", 0))
	end

	if text.character_rect then
		local ok, x = pcall(text.character_rect, text, index)

		if ok and type(x) == "number" then
			return x
		end
	end

	local text_x = control_number(text, "world_x", control_number(text, "x", 0))

	if not render_width or value_length <= 0 then
		return text_x
	end

	return text_x + render_width * math.min(index, value_length) / value_length
end

local function selection_index_at_x(text, value, x)
	local length = text_length(value)

	if length <= 0 then
		return 0
	end

	local render_width = text_render_width(text)
	local best_index = 0
	local best_distance = nil

	for index = 0, length do
		local slot_x = character_slot_x(text, index, length, render_width)
		local distance = math.abs(x - slot_x)

		if not best_distance or distance < best_distance then
			best_index = index
			best_distance = distance
		end
	end

	return best_index
end

local function input_text_padding(library)
	if library.InputTextPadding then
		local padding = library:InputTextPadding()

		if type(padding) == "number" then
			return padding
		end
	end

	return 12
end

function InlineInput:GetInputBoxText(input_box)
	local value = input_box and input_box.text and input_box.text.text and input_box.text:text() or nil

	if type(value) ~= "string" then
		return nil
	end

	local sanitized = TextRange.sanitize(value)

	if sanitized ~= value and input_box.text.set_text then
		input_box.text:set_text(sanitized)

		if input_box.text.set_selection then
			local length = text_length(sanitized)
			input_box._inline_input_caret_index = length
			input_box._inline_input_selection_base = nil
			input_box.text:set_selection(length, length)
		end
	end

	return sanitized
end

function InlineInput:CaretColor(input_box)
	local config = input_box and input_box._inline_input_config

	if self.ResolvedTextColor then
		return self:ResolvedTextColor(config, input_box)
	end

	if self.TextColor then
		return self:TextColor(config, input_box)
	end

	return Color and Color.white or nil
end

function InlineInput:StyleCaret(input_box, layer, force_visible)
	local caret = input_box and input_box.caret

	if not caret then
		return
	end

	if layer and caret.set_layer then
		local ok, current_layer = pcall(caret.layer, caret)

		if not ok or current_layer ~= layer then
			caret:set_layer(layer)
		end
	end

	if force_visible and caret.set_visible then
		caret:set_visible(true)
	end

	if force_visible then
		local color = self:CaretColor(input_box)

		if color and caret.set_color then
			caret:set_color(color)
		end
	end
end

function InlineInput:ResetCaretBlink(input_box)
	if input_unfocused(input_box) then
		return false
	end

	local caret = input_box and input_box.caret

	if not caret then
		return false
	end

	input_box._inline_input_blink_elapsed = 0
	input_box._inline_input_blink_alpha_high = true

	if caret.set_visible then
		caret:set_visible(true)
	end

	set_caret_alpha(caret, 1)

	return true
end

function InlineInput:ShowCaret(input_box, layer)
	if input_unfocused(input_box) then
		return
	end

	self:StyleCaret(input_box, layer, true)
	self:ResetCaretBlink(input_box)
end

function InlineInput:HideCaret(input_box)
	if not input_box then
		return
	end

	input_box._inline_input_blink_elapsed = nil
	input_box._inline_input_blink_alpha_high = nil
	self:StopNativeCaretBlink(input_box)

	local caret = input_box.caret
	if caret and caret.set_visible then
		caret:set_visible(false)
	end
end

function InlineInput:StopNativeCaretBlink(input_box)
	local caret = input_box and input_box.caret

	if caret and caret.stop then
		InlineInput:SafeCall(function()
			caret:stop()
		end)
	end
end

function InlineInput:UpdateCaretBlink(input_box, dt)
	local caret = input_box and input_box.caret

	if not caret then
		return
	end

	if input_unfocused(input_box) then
		self:HideCaret(input_box)
		return
	end

	if input_box._inline_input_blink_alpha_high == nil then
		self:ResetCaretBlink(input_box)
	end

	local elapsed = (input_box._inline_input_blink_elapsed or 0) + (type(dt) == "number" and dt or 0)

	while elapsed >= CARET_BLINK_INTERVAL do
		elapsed = elapsed - CARET_BLINK_INTERVAL
		input_box._inline_input_blink_alpha_high = not input_box._inline_input_blink_alpha_high
		set_caret_alpha(caret, input_box._inline_input_blink_alpha_high and 1 or 0.05)
	end

	input_box._inline_input_blink_elapsed = elapsed
end

function InlineInput:UpdateTextViewport(input_box)
	local text = input_box and input_box.text

	if not text then
		return false
	end

	local panel = input_box.panel
	local padding = input_text_padding(self)
	local panel_width = input_box._inline_input_panel_width or control_number(panel, "w", 0)
	local visible_width = math.max(panel_width - padding * 2, 1)
	local value = self:GetInputBoxText(input_box) or ""
	local current_scroll = positive_number(input_box._inline_input_scroll_x, 0)

	local function apply_scroll(scroll_x)
		scroll_x = math.max(scroll_x, 0)

		if scroll_x == current_scroll then
			return false
		end

		if self.ApplyInputTextScroll then
			self:ApplyInputTextScroll(input_box, scroll_x)
		else
			input_box._inline_input_scroll_x = scroll_x
		end

		return true
	end

	if value == "" then
		return apply_scroll(0)
	end

	local panel_x = control_number(panel, "world_x", control_number(panel, "x", 0))
	local left = panel_x + padding
	local right = left + visible_width
	local target_scroll = current_scroll
	local caret_x = caret_world_x(input_box, value)

	if caret_x then
		if caret_x > right then
			target_scroll = current_scroll + caret_x - right + TEXT_VIEWPORT_MARGIN
		elseif caret_x < left then
			target_scroll = current_scroll - (left - caret_x) - TEXT_VIEWPORT_MARGIN
		end
	end

	local width = text_render_width(text) or visible_width
	local max_scroll = math.max(width - visible_width, 0)
	target_scroll = math.min(math.max(target_scroll, 0), max_scroll)

	return apply_scroll(target_scroll)
end

function InlineInput:SetCaretFromMouse(input_box, x, extend_selection)
	local text = input_box and input_box.text

	if not text or type(x) ~= "number" or not text.set_selection then
		return false, nil
	end

	local value = self:GetInputBoxText(input_box) or ""
	local index = selection_index_at_x(text, value, x)

	self:SetSelectionToIndex(input_box, index, extend_selection == true)

	return true, index
end

function InlineInput:SetWordSelectionFromMouse(input_box, x)
	local text = input_box and input_box.text

	if not text or type(x) ~= "number" then
		return false, nil, nil
	end

	local value = self:GetInputBoxText(input_box) or ""
	local index = selection_index_at_x(text, value, x)

	if not self.SelectWordAtIndex then
		return false, nil, nil
	end

	return self:SelectWordAtIndex(input_box, index)
end

function InlineInput:GetCaretIndex(input_box, value)
	local text = input_box and input_box.text

	if not text then
		return 0
	end

	value = value or self:GetInputBoxText(input_box) or ""

	return selection_index(input_box, text, value)
end

function InlineInput:SetSelectionToIndex(input_box, index, extend_selection)
	local text = input_box and input_box.text

	if not text or not text.set_selection then
		return false
	end

	local value = self:GetInputBoxText(input_box) or ""
	local length = text_length(value)
	index = clamp_index(index, length)
	local current_start, current_end = selection_bounds(text, value)
	local next_start = index
	local next_end = index

	if extend_selection then
		local base_index = input_box._inline_input_selection_base

		if type(base_index) ~= "number" then
			local caret_index = self:GetCaretIndex(input_box, value)
			if current_start ~= current_end and caret_index == current_start then
				base_index = current_end
			elseif current_start ~= current_end then
				base_index = current_start
			else
				base_index = caret_index
			end
		end

		base_index = clamp_index(base_index, length)
		input_box._inline_input_selection_base = base_index
		input_box._inline_input_caret_index = index
		next_start = math.min(base_index, index)
		next_end = math.max(base_index, index)
	else
		input_box._inline_input_selection_base = nil
		input_box._inline_input_caret_index = index
	end

	if current_start == next_start and current_end == next_end then
		self:ResetCaretBlink(input_box)
		return true
	end

	text:set_selection(next_start, next_end)

	if input_box.update_caret then
		input_box:update_caret()
	end

	self:ResetCaretBlink(input_box)

	return true
end

function InlineInput:SetCaretToTextEdge(input_box, edge, extend_selection)
	local value = self:GetInputBoxText(input_box) or ""
	local index = edge == "start" and 0 or text_length(value)

	return self:SetSelectionToIndex(input_box, index, extend_selection)
end

function InlineInput:SelectAllText(input_box)
	local value = self:GetInputBoxText(input_box) or ""
	local length = text_length(value)

	input_box._inline_input_selection_base = 0
	return self:SetSelectionToIndex(input_box, length, true)
end

function InlineInput:ClearInputSelection(input_box)
	local text = input_box and input_box.text
	if not text or not text.set_selection then
		return false
	end

	local index = self:GetCaretIndex(input_box, self:GetInputBoxText(input_box) or "")
	input_box._inline_input_selection_base = nil
	input_box._inline_input_mouse_selecting = nil
	input_box._inline_input_caret_index = index
	text:set_selection(index, index)

	if self.UpdateSelectionHighlight then
		self:UpdateSelectionHighlight(input_box)
	end

	self:ResetCaretBlink(input_box)

	return true
end

function InlineInput:MoveCaretToIndex(input_box, index, extend_selection)
	return self:SetSelectionToIndex(input_box, index, extend_selection)
end

function InlineInput:SetMouseSelectionActive(input_box, active, base_index)
	if not input_box then
		return
	end

	input_box._inline_input_mouse_selecting = active == true

	if active ~= true then
		input_box._inline_input_selection_base = nil
		return
	end

	if type(base_index) == "number" then
		input_box._inline_input_selection_base = base_index
	end
end

function InlineInput:MoveCaret(input_box, direction, options)
	local text = input_box and input_box.text

	if not text or not text.set_selection then
		return false
	end

	options = options or {}
	direction = direction and direction < 0 and -1 or 1

	local value = self:GetInputBoxText(input_box) or ""
	local start_index, end_index, length = selection_bounds(text, value)
	local index = self:GetCaretIndex(input_box, value)

	if start_index ~= end_index and not options.extend_selection then
		index = direction < 0 and start_index or end_index
	else
		index = clamp_index(index + direction, length)
	end

	return self:SetSelectionToIndex(input_box, index, options.extend_selection == true)
end

function InlineInput:SetBoxText(input_box, value)
	if not input_box or not input_box.text or not input_box.text.set_text then
		return
	end

	value = tostring(value or "")

	if input_box.text.text and input_box.text:text() == value then
		if self.UpdateInputBoxPlaceholderVisibility then
			self:UpdateInputBoxPlaceholderVisibility(input_box)
		end

		return
	end

	input_box.text:set_text(value)

	if self.UpdateInputBoxPlaceholderVisibility then
		self:UpdateInputBoxPlaceholderVisibility(input_box)
	end

	if input_box.text.set_selection then
		local length = text_length(value)
		input_box._inline_input_caret_index = length
		input_box._inline_input_selection_base = nil
		input_box.text:set_selection(length, length)
	end

	if input_box.update_caret then
		input_box:update_caret()
	end

	self:ResetCaretBlink(input_box)
end

function InlineInput:SetPlaceholderText(config, input_box)
	local placeholder = self:GetPlaceholder(config)

	if
		placeholder == nil
		or not input_box
		or not input_box.placeholder_text
		or not input_box.placeholder_text.set_text
	then
		return
	end

	if input_box.placeholder_text.text then
		local ok, current = pcall(input_box.placeholder_text.text, input_box.placeholder_text)

		if ok and current == placeholder then
			return
		end
	end

	input_box.placeholder_text:set_text(placeholder)
end

function InlineInput:MoveEmptyCaretLeft(input_box)
	local text = input_box and input_box.text
	local caret = input_box and input_box.caret
	if not text or not caret or not caret.set_world_shape then
		return
	end

	if input_unfocused(input_box) then
		return
	end

	if text.text and text:text() ~= "" then
		return
	end

	local panel = input_box.panel
	local panel_x = control_number(panel, "world_x", control_number(panel, "x", 0))
	local padding = control_number(text, "x", 12)
	local y, height = fallback_caret_geometry(input_box, text)

	caret:set_world_shape(panel_x + padding, y + 2, 3, math.max(height - 4, 0))
end

function InlineInput:PatchInputBoxCaret(input_box)
	if not input_box or not input_box.update_caret then
		return
	end

	if input_box._inline_input_caret_patch_version == CARET_PATCH_VERSION then
		return
	end

	local original_update_caret = input_box._inline_input_original_update_caret or input_box.update_caret
	input_box._inline_input_original_update_caret = original_update_caret

	if input_box.set_blinking then
		input_box._inline_input_original_set_blinking = input_box._inline_input_original_set_blinking
			or input_box.set_blinking

		function input_box:set_blinking(blinking)
			InlineInput:StopNativeCaretBlink(self)
			self._blinking = blinking
		end
	end

	input_box._inline_input_caret_patched = true
	input_box._inline_input_caret_patch_version = CARET_PATCH_VERSION
	self:StopNativeCaretBlink(input_box)

	function input_box:update_caret(...)
		local result = original_update_caret(self, ...)
		if InlineInput:UpdateTextViewport(self) then
			original_update_caret(self, ...)
		end
		position_caret_at_selection(self)
		InlineInput:MoveEmptyCaretLeft(self)
		if InlineInput.ApplyRepeatedKeyChange then
			InlineInput:ApplyRepeatedKeyChange(self)
		end

		if InlineInput.UpdateSelectionHighlight then
			InlineInput:UpdateSelectionHighlight(self)
		end

		if InlineInput.UpdateInputBoxPlaceholderVisibility then
			InlineInput:UpdateInputBoxPlaceholderVisibility(self)
		end

		return result
	end
end

return InlineInput
