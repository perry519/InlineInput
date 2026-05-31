local InlineInput = _G.InlineInput

local BACKSPACE_REPEAT_DELAY = 0.25
local BACKSPACE_REPEAT_INTERVAL = 0.01
local CARET_MOVE_REPEAT_DELAY = 0.18
local CARET_MOVE_REPEAT_INTERVAL = 0.025

function InlineInput:StartBackspaceRepeat(config, node_gui)
	self._backspace_repeat_node = node_gui
	self._backspace_repeat_id = config and config.id
	self._backspace_repeat_elapsed = 0
	self._backspace_repeat_interval_elapsed = 0
	self._backspace_repeat_started = false
end

function InlineInput:ClearBackspaceRepeat()
	self._backspace_repeat_node = nil
	self._backspace_repeat_id = nil
	self._backspace_repeat_elapsed = nil
	self._backspace_repeat_interval_elapsed = nil
	self._backspace_repeat_started = nil
end

function InlineInput:StartCaretMoveRepeat(config, node_gui, direction)
	self._caret_move_repeat_node = node_gui
	self._caret_move_repeat_id = config and config.id
	self._caret_move_repeat_direction = direction
	self._caret_move_repeat_elapsed = 0
	self._caret_move_repeat_interval_elapsed = 0
	self._caret_move_repeat_started = false
end

function InlineInput:ClearCaretMoveRepeat()
	self._caret_move_repeat_node = nil
	self._caret_move_repeat_id = nil
	self._caret_move_repeat_direction = nil
	self._caret_move_repeat_elapsed = nil
	self._caret_move_repeat_interval_elapsed = nil
	self._caret_move_repeat_started = nil
end

function InlineInput:UpdateNodeBackspaceRepeat(node_gui, dt)
	if not self:IsBackspaceDown() or self:IsControlDown() then
		self:ClearBackspaceRepeat()
		return
	end

	local config, input_box = nil, nil

	if self.FocusedInputBox then
		config, input_box = self:FocusedInputBox(node_gui)
	end

	if not config or not input_box then
		self:ClearBackspaceRepeat()
		return
	end

	if self:IsReadOnly(config) then
		self:ClearBackspaceRepeat()
		return
	end

	if self._backspace_repeat_node ~= node_gui or self._backspace_repeat_id ~= config.id then
		self:StartBackspaceRepeat(config, node_gui)
		return
	end

	dt = type(dt) == "number" and dt or 0
	self._backspace_repeat_elapsed = (self._backspace_repeat_elapsed or 0) + dt

	if self._backspace_repeat_elapsed < BACKSPACE_REPEAT_DELAY then
		return
	end

	if not self._backspace_repeat_started then
		self._backspace_repeat_started = true
		self._backspace_repeat_interval_elapsed = BACKSPACE_REPEAT_INTERVAL
	else
		self._backspace_repeat_interval_elapsed = (self._backspace_repeat_interval_elapsed or 0) + dt
	end

	while self._backspace_repeat_interval_elapsed >= BACKSPACE_REPEAT_INTERVAL do
		self._backspace_repeat_interval_elapsed = self._backspace_repeat_interval_elapsed - BACKSPACE_REPEAT_INTERVAL

		local target = self:CreateInputBoxTarget(config, node_gui, input_box)

		if not self:ApplyBackspaceChange(target) then
			break
		end
	end
end

function InlineInput:UpdateNodeCaretMoveRepeat(node_gui, dt)
	if self:IsControlDown() then
		self:ClearCaretMoveRepeat()
		return
	end

	local left_down = self:IsLeftDown()
	local right_down = self:IsRightDown()

	if left_down == right_down then
		self:ClearCaretMoveRepeat()
		return
	end

	local direction = left_down and -1 or 1
	local config, input_box = nil, nil

	if self.FocusedInputBox then
		config, input_box = self:FocusedInputBox(node_gui)
	end

	if not config or not input_box then
		self:ClearCaretMoveRepeat()
		return
	end

	if
		self._caret_move_repeat_node ~= node_gui
		or self._caret_move_repeat_id ~= config.id
		or self._caret_move_repeat_direction ~= direction
	then
		self:StartCaretMoveRepeat(config, node_gui, direction)
		return
	end

	dt = type(dt) == "number" and dt or 0
	self._caret_move_repeat_elapsed = (self._caret_move_repeat_elapsed or 0) + dt

	if self._caret_move_repeat_elapsed < CARET_MOVE_REPEAT_DELAY then
		return
	end

	if not self._caret_move_repeat_started then
		self._caret_move_repeat_started = true
		self._caret_move_repeat_interval_elapsed = CARET_MOVE_REPEAT_INTERVAL
	else
		self._caret_move_repeat_interval_elapsed = (self._caret_move_repeat_interval_elapsed or 0) + dt
	end

	while self._caret_move_repeat_interval_elapsed >= CARET_MOVE_REPEAT_INTERVAL do
		self._caret_move_repeat_interval_elapsed = self._caret_move_repeat_interval_elapsed - CARET_MOVE_REPEAT_INTERVAL
		self:MoveCaret(input_box, direction, { extend_selection = self:IsShiftDown() })
	end
end

return InlineInput
