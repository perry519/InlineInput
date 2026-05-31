local InlineInput = _G.InlineInput

function InlineInput:OnFieldRegistered(config)
	if self.InstallHooks then
		self:InstallHooks()
	end

	self:LogInfo(
		"registered "
			.. tostring(config.id)
			.. " menu_id="
			.. tostring(config.menu_id)
			.. " item_id="
			.. tostring(config.item_id or config.id)
	)
end

function InlineInput.Handle:sync(node_gui)
	local library = self:library()

	return library and library:SyncConfig(self, node_gui) or nil
end

function InlineInput.Handle:input_box(node_gui)
	local library = self:library()

	return library and library:GetInputBox(self.id, node_gui) or nil
end

function InlineInput.Handle:set_focus(target, focused, source)
	local library = self:library()

	return library and library:SetFocus(self.id, target, focused, source) or false
end

function InlineInput.Handle:focus(target, source)
	return self:set_focus(target, true, source)
end

function InlineInput.Handle:blur(target, source)
	return self:set_focus(target, false, source)
end

function InlineInput.Handle:input_focus(node_gui)
	local input_box = self:input_box(node_gui)

	return input_box ~= nil and input_box.input_focus and input_box:input_focus() == true
end

function InlineInput.Handle:install_hooks()
	local library = self:library()

	if not library then
		return false
	end

	if not library.InstallHooks then
		return true
	end

	return library:InstallHooks()
end

InlineInput.Handle.box = InlineInput.Handle.input_box
InlineInput.Handle.open = InlineInput.Handle.focus

return InlineInput
