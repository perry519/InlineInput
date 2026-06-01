local InlineInput = _G.InlineInput

local function input_target(library, target)
	return library:CreateInputTarget(target)
end

local TextRange = InlineInput.TextRange
local text_length = TextRange.length
local slot_text = TextRange.slot_text
local truncate_slots = TextRange.truncate_slots
local character_at_slot = TextRange.character_at_slot
local remove_slots = TextRange.remove_slots
local replace_slots = TextRange.replace_slots

local function selection_range(input_box, value)
	return TextRange.target_selection_range(InlineInput, input_box, value)
end

local WORD_BREAKERS = {
	["("] = true,
	[")"] = true,
	["["] = true,
	["]"] = true,
	["{"] = true,
	["}"] = true,
	["|"] = true,
	["_"] = true,
	["\\"] = true,
	["/"] = true,
	["*"] = true,
	["+"] = true,
	["-"] = true,
	["="] = true,
	["#"] = true,
	["@"] = true,
	["&"] = true,
	["!"] = true,
	["?"] = true,
	[":"] = true,
	[";"] = true,
	[","] = true,
	["."] = true,
	[" "] = true,
	["\t"] = true,
	["\n"] = true
}

local function is_word_breaker(character)
	return WORD_BREAKERS[character] == true
end

local function previous_word_start(value, slot, length)
	length = length or text_length(value)
	slot = math.max(math.min(slot or length, length), 0)

	while slot > 0 and is_word_breaker(character_at_slot(value, slot - 1, length)) do
		slot = slot - 1
	end

	while slot > 0 and not is_word_breaker(character_at_slot(value, slot - 1, length)) do
		slot = slot - 1
	end

	return slot
end

local function next_word_end(value, slot, length)
	length = length or text_length(value)
	slot = math.max(math.min(slot or length, length), 0)

	while slot < length and is_word_breaker(character_at_slot(value, slot, length)) do
		slot = slot + 1
	end

	while slot < length and not is_word_breaker(character_at_slot(value, slot, length)) do
		slot = slot + 1
	end

	while slot < length and is_word_breaker(character_at_slot(value, slot, length)) do
		slot = slot + 1
	end

	return slot
end

function InlineInput:WordSelectionRange(value, index)
	value = tostring(value or "")
	local length = text_length(value)
	index = math.max(math.min(index or 0, length), 0)

	if length <= 0 then
		return nil, nil
	end

	local anchor = nil

	if index > 0 and not is_word_breaker(character_at_slot(value, index - 1, length)) then
		anchor = index - 1
	elseif index < length and not is_word_breaker(character_at_slot(value, index, length)) then
		anchor = index
	end

	if not anchor then
		return nil, nil
	end

	local start_index = anchor
	local end_index = anchor + 1

	while start_index > 0 and not is_word_breaker(character_at_slot(value, start_index - 1, length)) do
		start_index = start_index - 1
	end

	while end_index < length and not is_word_breaker(character_at_slot(value, end_index, length)) do
		end_index = end_index + 1
	end

	return start_index, end_index
end

function InlineInput:SelectWordAtIndex(input_box, index)
	local text = input_box and input_box.text

	if not text or not text.set_selection then
		return false
	end

	local start_index, end_index = self:WordSelectionRange(self:GetInputBoxText(input_box) or "", index)

	if not start_index or not end_index or start_index == end_index then
		return false
	end

	input_box._inline_input_selection_base = nil
	input_box._inline_input_caret_index = end_index
	text:set_selection(start_index, end_index)

	if input_box.update_caret then
		input_box:update_caret()
	end

	self:ResetCaretBlink(input_box)

	return true, start_index, end_index
end

local function set_box_text_at(input_library, input_box, value, selection_index)
	if input_library:IsInputTarget(input_box) then
		input_box:set_value_at(value, selection_index)
		return
	end

	input_library:SetBoxText(input_box, value)

	if input_box and input_box.text and input_box.text.set_selection and type(selection_index) == "number" then
		input_box.text:set_selection(selection_index, selection_index)

		if input_box.update_caret then
			input_box:update_caret()
		end
	end
end

function InlineInput:RemoveCharacterBeforeCaret(input_box, value)
	value = tostring(value or "")

	local start_index, end_index, length = selection_range(input_box, value)

	if start_index ~= end_index then
		return remove_slots(value, start_index, end_index, length)
	end

	if start_index <= 0 then
		return value, start_index, false
	end

	return remove_slots(value, start_index - 1, start_index, length)
end

function InlineInput:RemoveWordBeforeCaret(input_box, value)
	value = tostring(value or "")

	local start_index, end_index, length = selection_range(input_box, value)

	if start_index ~= end_index then
		return remove_slots(value, start_index, end_index, length)
	end

	local word_start = previous_word_start(value, start_index, length)

	return remove_slots(value, word_start, start_index, length)
end

function InlineInput:RemoveCharacterAfterCaret(input_box, value)
	value = tostring(value or "")

	local start_index, end_index, length = selection_range(input_box, value)

	if start_index ~= end_index then
		return remove_slots(value, start_index, end_index, length)
	end

	if end_index >= length then
		return value, end_index, false
	end

	return remove_slots(value, end_index, end_index + 1, length)
end

function InlineInput:RemoveWordAfterCaret(input_box, value)
	value = tostring(value or "")

	local start_index, end_index, length = selection_range(input_box, value)

	if start_index ~= end_index then
		return remove_slots(value, start_index, end_index, length)
	end

	local word_end = next_word_end(value, end_index, length)

	return remove_slots(value, end_index, word_end, length)
end

function InlineInput:ApplyTextMutation(target, _arg2, _arg3, next_value, selection_index, source)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return false
	end

	local value = target:value()

	if next_value == value then
		return false
	end

	set_box_text_at(self, target, next_value, selection_index)
	target:commit(next_value, source or "change")

	return true
end

function InlineInput:ApplyTextInputChange(target, _arg2, _arg3, insert_text, source)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return true
	end

	insert_text = tostring(insert_text or "")

	local value = target:value()
	local start_index, end_index, length = selection_range(target, value)
	local max_length = target.max_length and target:max_length() or nil

	if type(max_length) == "number" then
		local selected_length = math.max(end_index - start_index, 0)
		local allowed_length = max_length - (length - selected_length)
		insert_text = allowed_length > 0 and truncate_slots(insert_text, allowed_length) or ""
	end

	local next_value = replace_slots(value, start_index, end_index, insert_text, length)
	next_value = target:normalize(next_value)

	local next_length = text_length(next_value)
	local selection_index = math.min(start_index + text_length(insert_text), next_length)

	set_box_text_at(self, target, next_value, selection_index)
	target:commit(next_value, source or "change")

	return true
end

function InlineInput:ApplyBackspaceChange(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return false
	end

	local value = target:value()
	local next_value, selection_index = self:RemoveCharacterBeforeCaret(target, value)

	return self:ApplyTextMutation(target, nil, nil, next_value, selection_index, "change")
end

function InlineInput:ApplyWordBackspaceChange(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return false
	end

	local value = target:value()
	local next_value, selection_index = self:RemoveWordBeforeCaret(target, value)

	return self:ApplyTextMutation(target, nil, nil, next_value, selection_index, "change")
end

function InlineInput:ApplyDeleteChange(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return false
	end

	local value = target:value()
	local next_value, selection_index = self:RemoveCharacterAfterCaret(target, value)

	return self:ApplyTextMutation(target, nil, nil, next_value, selection_index, "change")
end

function InlineInput:ApplyWordDeleteChange(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	if target:is_read_only() then
		return false
	end

	local value = target:value()
	local next_value, selection_index = self:RemoveWordAfterCaret(target, value)

	return self:ApplyTextMutation(target, nil, nil, next_value, selection_index, "change")
end

function InlineInput:MoveCaretByWord(input_box, direction, extend_selection)
	local target = self:IsInputTarget(input_box) and input_box or nil
	local box = target and target.input_box or input_box
	local value = target and target:value() or self:GetInputBoxText(box) or ""
	local caret_index = self:GetCaretIndex(box, value)
	local length = text_length(value)
	local next_index = direction and direction < 0 and previous_word_start(value, caret_index, length)
		or next_word_end(value, caret_index, length)

	return self:MoveCaretToIndex(box, next_index, extend_selection == true)
end

function InlineInput:SelectedText(input_box, fallback_to_all)
	local target = self:IsInputTarget(input_box) and input_box or nil
	local value = target and target:value() or self:GetInputBoxText(input_box) or ""
	local start_index, end_index, length = selection_range(input_box, value)

	if start_index == end_index then
		return fallback_to_all and value or "", start_index, end_index, length
	end

	return slot_text(value, start_index, end_index, length), start_index, end_index, length
end

function InlineInput:SetClipboardText(value)
	if not Application or type(Application.set_clipboard) ~= "function" then
		return false
	end

	InlineInput:SafeCall(function()
		Application:set_clipboard(tostring(value or ""))
	end)

	return true
end

function InlineInput:GetClipboardText()
	if not Application or type(Application.get_clipboard) ~= "function" then
		return nil
	end

	local value = InlineInput:SafeCall(function()
		return Application:get_clipboard()
	end)

	return type(value) == "string" and value or nil
end

function InlineInput:ApplyClipboardCopy(input_box)
	local selected_text = self:SelectedText(input_box, true)

	self:SetClipboardText(selected_text)

	return true
end

function InlineInput:ApplyClipboardCut(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	local selected_text, start_index, end_index, length = self:SelectedText(target, false)

	if selected_text == "" then
		return true
	end

	self:SetClipboardText(selected_text)

	if target:is_read_only() then
		return true
	end

	local value = target:value()
	local next_value = remove_slots(value, start_index, end_index, length)

	return self:ApplyTextMutation(target, nil, nil, next_value, start_index, "change") or true
end

function InlineInput:ApplyClipboardPaste(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	local value = self:GetClipboardText()

	if value == nil then
		return true
	end

	return self:ApplyTextInputChange(target, nil, nil, value, "change")
end

function InlineInput:ApplySelectAll(input_box)
	local target = self:IsInputTarget(input_box) and input_box or nil
	return self:SelectAllText(target and target.input_box or input_box)
end

function InlineInput:ApplyInitialBackspace(target)
	target = input_target(self, target)

	if not target then
		return false
	end

	if self:IsControlDown() then
		self:ApplyWordBackspaceChange(target)
		if target.clear_backspace_repeat then
			target:clear_backspace_repeat()
		end
	else
		if self:ApplyBackspaceChange(target) then
			if target.start_backspace_repeat then
				target:start_backspace_repeat()
			end
		else
			if target.clear_backspace_repeat then
				target:clear_backspace_repeat()
			end
		end
	end

	return true
end

return InlineInput
