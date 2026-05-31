local InlineInput = _G.InlineInput

function InlineInput:UpdateNodeCaretBlinks(node_gui, dt)
	local boxes = node_gui and node_gui[self._node_box_key]

	for _, input_box in pairs(boxes or {}) do
		if input_box and input_box.input_focus then
			self:UpdateCaretBlink(input_box, dt)
		end
	end
end

function InlineInput:ApplyRepeatedKeyChange(input_box)
	if not input_box or not input_box._inline_input_in_key_repeat then
		return
	end

	local config = input_box._inline_input_config
	local node_gui = input_box._inline_input_node_gui

	if not config or not node_gui then
		return
	end

	if self:IsInputBoxUnfocused(input_box) then
		return
	end

	local value = self:NormalizeText(config, self:GetInputBoxText(input_box) or "")

	if value == self:GetValue(config) then
		return
	end

	self:ApplyValue(config, node_gui, value, "repeat")
end

return InlineInput
