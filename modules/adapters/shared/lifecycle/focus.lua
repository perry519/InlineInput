local InlineInput = _G.InlineInput

function InlineInput:SetFocus(id, target, focused, source)
	if self.InstallHooks then
		self:InstallHooks()
	end

	local config = self._registrations[id]

	if not config then
		return false
	end

	local node_gui = self:ResolveInputNodeGui(target)
	local input_box = self:GetInputBox(id, node_gui)

	if focused ~= false and not input_box then
		input_box = self:SyncConfig(config, node_gui)
	end

	if not input_box then
		return false
	end

	source = source or (focused == false and "blur" or "focus")

	if focused == false then
		local was_focused = self:IsInputBoxFocused(input_box)

		self:DisconnectInput(input_box, config, node_gui, source)

		if was_focused then
			self:NotifyFinish(config, node_gui, input_box, self:GetValue(config), source)
		end

		return true, input_box
	end

	if self:ConnectInput(input_box, config, node_gui, source) == false then
		return false, input_box
	end

	self:BindInputBoxCallbacks(config, node_gui, input_box)
	self:HighlightRow(config, node_gui)

	return true, input_box
end

function InlineInput:Focus(id, target, source)
	return self:SetFocus(id, target, true, source)
end

function InlineInput:Open(id, item, source)
	return self:Focus(id, item, source)
end

return InlineInput
