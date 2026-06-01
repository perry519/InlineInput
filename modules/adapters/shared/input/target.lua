local InlineInput = _G.InlineInput

InlineInput.InputBoxTarget = InlineInput.InputBoxTarget or {}
InlineInput.InputBoxTarget.__index = InlineInput.InputBoxTarget

function InlineInput:CreateInputBoxTarget(config, node_gui, input_box)
	return setmetatable({
		_inline_input_target = true,
		library = self,
		config = config,
		node_gui = node_gui,
		input_box = input_box
	}, self.InputBoxTarget)
end

function InlineInput.InputBoxTarget:value()
	return self.library:GetInputBoxText(self.input_box) or ""
end

function InlineInput.InputBoxTarget:set_value(value)
	return self.library:SetBoxText(self.input_box, value)
end

function InlineInput.InputBoxTarget:selection()
	local text = self.input_box and self.input_box.text

	if text and text.selection then
		local ok, selection_start, selection_end = pcall(text.selection, text)

		if ok then
			return selection_start, selection_end
		end
	end

	return nil, nil
end

function InlineInput.InputBoxTarget:set_selection(start_index, end_index)
	local text = self.input_box and self.input_box.text

	if text and text.set_selection and type(start_index) == "number" then
		text:set_selection(start_index, type(end_index) == "number" and end_index or start_index)
		self.library:ResetCaretBlink(self.input_box)
	end
end

function InlineInput.InputBoxTarget:update_caret()
	if self.input_box and self.input_box.update_caret then
		self.input_box:update_caret()
	end
end

function InlineInput.InputBoxTarget:set_value_at(value, selection_index)
	self:set_value(value)

	if type(selection_index) == "number" then
		self:set_selection(selection_index, selection_index)
		self:update_caret()
	end
end

function InlineInput.InputBoxTarget:is_read_only()
	return self.library:IsReadOnly(self.config)
end

function InlineInput.InputBoxTarget:normalize(value)
	return self.library:NormalizeText(self.config, value)
end

function InlineInput.InputBoxTarget:max_length()
	local max_length = self.library:GetMaxLength(self.config)

	if type(max_length) == "number" then
		return max_length
	end

	max_length = self.input_box and self.input_box._inline_input_max_length

	if type(max_length) == "number" then
		max_length = math.floor(max_length)
		return max_length >= 0 and max_length or nil
	end

	if SearchBoxGuiObject and type(SearchBoxGuiObject.MAX_SEARCH_LENGTH) == "number" then
		max_length = math.floor(SearchBoxGuiObject.MAX_SEARCH_LENGTH)
		return max_length >= 0 and max_length or nil
	end
end

function InlineInput.InputBoxTarget:commit(value, source)
	return self.library:ApplyValue(self.config, self.node_gui, value, source)
end

function InlineInput.InputBoxTarget:connect(source)
	return self.library:ConnectInput(self.input_box, self.config, self.node_gui, source)
end

function InlineInput.InputBoxTarget:activate(source)
	if self:connect(source) == false then
		return false
	end

	self:bind_callbacks()
	self:highlight()
	self.library:MoveEmptyCaretLeft(self.input_box)

	return true
end

function InlineInput.InputBoxTarget:disconnect(source, value)
	return self.library:DisconnectInput(self.input_box, self.config, self.node_gui, source, value)
end

function InlineInput.InputBoxTarget:bind_callbacks()
	return self.library:BindInputBoxCallbacks(self.config, self.node_gui, self.input_box)
end

function InlineInput.InputBoxTarget:highlight()
	return self.library:HighlightRow(self.config, self.node_gui)
end

function InlineInput.InputBoxTarget:start_backspace_repeat()
	return self.library:StartBackspaceRepeat(self.config, self.node_gui)
end

function InlineInput.InputBoxTarget:clear_backspace_repeat()
	return self.library:ClearBackspaceRepeat()
end

InlineInput.MenuInputTarget = InlineInput.InputBoxTarget
InlineInput.CreateMenuInputTarget = InlineInput.CreateInputBoxTarget

return InlineInput
