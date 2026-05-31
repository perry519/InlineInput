local InlineInput = _G.InlineInput

InlineInput.InputSession = InlineInput.InputSession or {}
InlineInput.InputSession.__index = InlineInput.InputSession

function InlineInput:CreateInputSession(target, options)
	target = self:CreateInputTarget(target)

	return setmetatable({
		library = self,
		target = target,
		options = options or {}
	}, self.InputSession)
end

function InlineInput.InputSession:activate(source)
	if self.target and self.target.activate then
		return self.target:activate(source)
	end

	if self.target and self.target.connect then
		return self.target:connect(source)
	end
end

function InlineInput.InputSession:deactivate(source, value)
	return self.target:disconnect(source, value)
end

function InlineInput.InputSession:commit(source)
	return self.target:commit(self.target:value(), source)
end

function InlineInput.InputSession:insert_text(value, source)
	return self.library:ApplyTextInputChange(self.target, nil, nil, value, source or "change")
end

function InlineInput.InputSession:insert_initial_text_character(key, key_name)
	local character = self.library:TextInputCharacter(key, key_name)

	if not character then
		return false
	end

	return self:insert_text(character, "change")
end

function InlineInput.InputSession:initial_backspace()
	return self.library:ApplyInitialBackspace(self.target)
end

function InlineInput.InputSession:backspace()
	return self.library:ApplyBackspaceChange(self.target)
end

function InlineInput.InputSession:word_backspace()
	return self.library:ApplyWordBackspaceChange(self.target)
end

function InlineInput.InputSession:delete()
	return self.library:ApplyDeleteChange(self.target)
end

function InlineInput.InputSession:word_delete()
	return self.library:ApplyWordDeleteChange(self.target)
end

function InlineInput.InputSession:move_word(direction, extend_selection)
	return self.library:MoveCaretByWord(self.target, direction, extend_selection)
end

function InlineInput.InputSession:copy()
	return self.library:ApplyClipboardCopy(self.target)
end

function InlineInput.InputSession:cut()
	return self.library:ApplyClipboardCut(self.target)
end

function InlineInput.InputSession:paste()
	return self.library:ApplyClipboardPaste(self.target)
end

function InlineInput.InputSession:select_all()
	return self.library:ApplySelectAll(self.target)
end

return InlineInput
