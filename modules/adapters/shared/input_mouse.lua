local InlineInput = _G.InlineInput

local Adapter = InlineInput.Adapter

local panel_number = Adapter.panel_number
local is_primary_mouse_button = Adapter.primary_button

function InlineInput:InputBoxContainsPoint(input_box, x, y)
	if not input_box or not input_box.panel or type(x) ~= "number" or type(y) ~= "number" then
		return false
	end

	local panel = input_box.panel

	if panel.inside then
		local ok, inside = pcall(panel.inside, panel, x, y)

		if ok and inside ~= nil then
			return inside == true
		end
	end

	local panel_x = panel_number(panel, "world_x", panel_number(panel, "x", 0))
	local panel_y = panel_number(panel, "world_y", panel_number(panel, "y", 0))
	local width = panel_number(panel, "w", 0)
	local height = panel_number(panel, "h", 0)

	return x >= panel_x and y >= panel_y and x <= panel_x + width and y <= panel_y + height
end

function InlineInput:NodeMouseSelectionActive(node_gui)
	local boxes = node_gui and node_gui[self._node_box_key]

	for _, input_box in pairs(boxes or {}) do
		if input_box and input_box._inline_input_mouse_selecting == true then
			return true
		end
	end

	return false
end

function InlineInput:ClearNodeMouseSelection(node_gui)
	local boxes = node_gui and node_gui[self._node_box_key]
	local cleared = false

	for _, input_box in pairs(boxes or {}) do
		if input_box and input_box._inline_input_mouse_selecting == true then
			self:SetMouseSelectionActive(input_box, false)
			cleared = true
		end
	end

	return cleared
end

local function timer_time(timer_manager, timer_name)
	local timer_factory = timer_manager and timer_manager[timer_name]

	if type(timer_factory) ~= "function" then
		return nil
	end

	local ok_timer, timer = pcall(timer_factory, timer_manager)

	if not ok_timer or not timer or type(timer.time) ~= "function" then
		return nil
	end

	local ok_time, time = pcall(timer.time, timer)

	if ok_time and type(time) == "number" then
		return time
	end

	return nil
end

function InlineInput:InputClickTime()
	local wall_time = timer_time(TimerManager, "wall")

	if wall_time then
		return wall_time
	end

	if self.InputBlockTime then
		return self:InputBlockTime()
	end

	return nil
end

function InlineInput:InputClickCount(input_box, x, y)
	if not input_box then
		return 1
	end

	local now = self:InputClickTime()

	if type(now) ~= "number" then
		input_box._inline_input_last_click = nil
		return 1
	end

	local previous = input_box._inline_input_last_click
	local threshold = self.DEFAULTS and self.DEFAULTS.input_double_click_seconds or 0.30
	local elapsed = previous and type(previous.time) == "number" and now - previous.time or nil
	local count = 1

	if elapsed ~= nil and elapsed >= 0 and elapsed <= threshold then
		count = (previous.count or 1) + 1
	end

	input_box._inline_input_last_click = {
		time = now,
		x = x,
		y = y,
		count = count
	}

	return count
end

function InlineInput:MousePressed(node_gui, button, x, y)
	local boxes = node_gui and node_gui[self._node_box_key]

	if not boxes or not next(boxes) then
		self:SyncNode(node_gui)
		boxes = node_gui and node_gui[self._node_box_key]
	end

	local focused_boxes = {}

	for id, input_box in pairs(boxes or {}) do
		if input_box and input_box.input_focus and input_box:input_focus() then
			table.insert(focused_boxes, { id = id, input_box = input_box })
		end
	end

	for id, input_box in pairs(boxes or {}) do
		if self:InputBoxContainsPoint(input_box, x, y) then
			if not is_primary_mouse_button(button) then
				return false
			end

			local config = self._registrations[id]

			if config then
				if self:ConnectInput(input_box, config, node_gui, "mouse") == false then
					return true
				end

				self:BindInputBoxCallbacks(config, node_gui, input_box)
				self:HighlightRow(config, node_gui)
			end

			if self._suppress_next_mouse_move_node == node_gui then
				self._suppress_next_mouse_move_node = nil
			end

			local click_count = self:InputClickCount(input_box, x, y)

			if click_count >= 3 and input_box._inline_input_word_double_clicked == true then
				self:SelectAllText(input_box)
				self:SetMouseSelectionActive(input_box, false)
				input_box._inline_input_word_double_clicked = nil
				return true
			end

			if click_count == 2 and self:SetWordSelectionFromMouse(input_box, x) then
				self:SetMouseSelectionActive(input_box, false)
				input_box._inline_input_word_double_clicked = true
				return true
			end

			input_box._inline_input_word_double_clicked = nil
			local _, selection_index = self:SetCaretFromMouse(input_box, x)
			self:SetMouseSelectionActive(input_box, true, selection_index)
			self:MoveEmptyCaretLeft(input_box)
			return true
		end
	end

	if #focused_boxes > 0 then
		if not is_primary_mouse_button(button) then
			return false
		end

		for _, focused in ipairs(focused_boxes) do
			local input_box = focused.input_box
			local config = self._registrations[focused.id]

			if config and input_box and input_box.input_focus and input_box:input_focus() then
				self:FinishInput(config, node_gui, input_box, "outside_click")
			end
		end

		self._suppress_next_mouse_move_node = node_gui
		return false
	end

	return false
end

function InlineInput:FocusedInputBox(node_gui)
	local boxes = node_gui and node_gui[self._node_box_key]
	local active_id = node_gui and node_gui._inline_input_active_id
	local active_box = active_id and boxes and boxes[active_id]

	if active_box and self:IsActiveInputBox(self._registrations[active_id], node_gui, active_box) then
		return self._registrations[active_id], active_box
	end

	for id, input_box in pairs(boxes or {}) do
		if input_box and self:IsInputBoxFocused(input_box) then
			return self._registrations[id], input_box
		end
	end

	return nil, nil
end

function InlineInput:MouseMoved(node_gui, button, x, y)
	if self._suppress_next_mouse_move_node == node_gui then
		self._suppress_next_mouse_move_node = nil
		self._hovered_input_node = nil
		self._hovered_input_id = nil
		return true, "arrow"
	end

	local boxes = node_gui and node_gui[self._node_box_key]
	if not boxes or not next(boxes) then
		self:SyncNode(node_gui)
		boxes = node_gui and node_gui[self._node_box_key]
	end

	local pointer = "arrow"

	for _, input_box in pairs(boxes or {}) do
		if input_box and input_box._inline_input_mouse_selecting == true then
			if input_box.input_focus and input_box:input_focus() and is_primary_mouse_button(button) then
				self:SetCaretFromMouse(input_box, x, true)
				self:MoveEmptyCaretLeft(input_box)
				return true, "link"
			end

			self:SetMouseSelectionActive(input_box, false)
		end
	end

	for id, input_box in pairs(boxes or {}) do
		if self:InputBoxContainsPoint(input_box, x, y) then
			self._hovered_input_node = node_gui
			self._hovered_input_id = id
			return true, "link"
		end
	end

	if self._hovered_input_node == node_gui then
		self._hovered_input_node = nil
		self._hovered_input_id = nil
	end

	return false, pointer
end

function InlineInput:InputFocus(node_gui)
	local _, input_box = self:FocusedInputBox(node_gui)

	return input_box ~= nil
end

return InlineInput
