local InlineInput = _G.InlineInput

InlineInput.TextRange = InlineInput.TextRange or {}

local TextRange = InlineInput.TextRange
local Utf8Text = InlineInput.Utf8Text
local utf8_sequence_byte_length = Utf8Text.sequence_byte_length

local function text_rect_width(text)
	return select(3, text.text_rect(text))
end

TextRange.sanitize = Utf8Text.sanitize
TextRange.search_normalize = Utf8Text.search_normalize

function TextRange.length(value)
	value = tostring(value or "")

	local value_bytes = string.len(value)
	local index = 1
	local length = 0

	while index <= value_bytes do
		local byte_length = utf8_sequence_byte_length(value, index)
		index = index + math.max(byte_length, 1)
		length = length + 1
	end

	return length
end

function TextRange.clamp_index(index, length)
	length = type(length) == "number" and length or 0
	return math.max(math.min(type(index) == "number" and index or length, length), 0)
end

function TextRange.byte_index_at_slot(value, slot, length)
	value = tostring(value or "")
	length = length or TextRange.length(value)
	slot = TextRange.clamp_index(slot, length)

	if slot <= 0 then
		return 1
	end

	if slot >= length then
		return string.len(value) + 1
	end

	local value_bytes = string.len(value)
	local index = 1
	local current_slot = 0

	while index <= value_bytes and current_slot < slot do
		local byte_length = utf8_sequence_byte_length(value, index)
		index = index + math.max(byte_length, 1)
		current_slot = current_slot + 1
	end

	return index
end

function TextRange.slot_text(value, start_index, end_index, length)
	value = tostring(value or "")
	length = length or TextRange.length(value)
	start_index = TextRange.clamp_index(start_index, length)
	end_index = TextRange.clamp_index(end_index, length)

	if end_index <= start_index then
		return ""
	end

	local start_byte = TextRange.byte_index_at_slot(value, start_index, length)
	local end_byte = TextRange.byte_index_at_slot(value, end_index, length)

	return string.sub(value, start_byte, end_byte - 1)
end

function TextRange.truncate_slots(value, max_length)
	max_length = math.max(type(max_length) == "number" and max_length or TextRange.length(value), 0)
	return TextRange.slot_text(value, 0, max_length, TextRange.length(value))
end

function TextRange.character_at_slot(value, slot, length)
	return TextRange.slot_text(value, slot, slot + 1, length)
end

function TextRange.text_selection_bounds(text, value)
	local length = TextRange.length(value)
	local start_index = length
	local end_index = length

	if text and text.selection then
		local ok, selection_start, selection_end = pcall(text.selection, text)

		if ok then
			if type(selection_start) == "number" then
				start_index = selection_start
			end

			if type(selection_end) == "number" then
				end_index = selection_end
			else
				end_index = start_index
			end
		end
	end

	start_index = TextRange.clamp_index(start_index, length)
	end_index = TextRange.clamp_index(end_index, length)

	if end_index < start_index then
		return end_index, start_index, length
	end

	return start_index, end_index, length
end

function TextRange.target_selection_range(library, input_box, value)
	local length = TextRange.length(value)
	local start_index = length
	local end_index = length
	local text = input_box and input_box.text

	if library:IsInputTarget(input_box) then
		local selection_start, selection_end = input_box:selection()

		if type(selection_start) == "number" then
			start_index = selection_start
		end

		if type(selection_end) == "number" then
			end_index = selection_end
		else
			end_index = start_index
		end
	elseif text and text.selection then
		start_index, end_index = TextRange.text_selection_bounds(text, value)
	end

	start_index = TextRange.clamp_index(start_index, length)
	end_index = TextRange.clamp_index(end_index, length)

	if end_index < start_index then
		return end_index, start_index, length
	end

	return start_index, end_index, length
end

function TextRange.remove_slots(value, start_index, end_index, length)
	length = length or TextRange.length(value)
	start_index = TextRange.clamp_index(start_index, length)
	end_index = TextRange.clamp_index(end_index, length)

	if end_index <= start_index then
		return value, start_index, false
	end

	local start_byte = TextRange.byte_index_at_slot(value, start_index, length)
	local end_byte = TextRange.byte_index_at_slot(value, end_index, length)
	local next_value = string.sub(value, 1, start_byte - 1) .. string.sub(value, end_byte)

	return next_value, start_index, true
end

function TextRange.replace_slots(value, start_index, end_index, replacement, length)
	length = length or TextRange.length(value)
	start_index = TextRange.clamp_index(start_index, length)
	end_index = TextRange.clamp_index(end_index, length)

	if end_index < start_index then
		start_index, end_index = end_index, start_index
	end

	local start_byte = TextRange.byte_index_at_slot(value, start_index, length)
	local end_byte = TextRange.byte_index_at_slot(value, end_index, length)

	return string.sub(value, 1, start_byte - 1) .. tostring(replacement or "") .. string.sub(value, end_byte)
end

function TextRange.render_width(text)
	if text and text.text_rect then
		local ok, width = pcall(text_rect_width, text)

		if ok and type(width) == "number" then
			return width
		end
	end

	return nil
end

InlineInput.TextLength = TextRange.length
InlineInput.ClampTextIndex = TextRange.clamp_index
InlineInput.ByteIndexAtTextSlot = TextRange.byte_index_at_slot
InlineInput.TextSlot = TextRange.slot_text
InlineInput.TruncateTextSlots = TextRange.truncate_slots
InlineInput.TextCharacterAtSlot = TextRange.character_at_slot
InlineInput.TextSelectionBounds = TextRange.text_selection_bounds
InlineInput.TargetSelectionRange = TextRange.target_selection_range
InlineInput.RemoveTextSlots = TextRange.remove_slots
InlineInput.ReplaceTextSlots = TextRange.replace_slots
InlineInput.TextRenderWidth = TextRange.render_width
InlineInput.SanitizeText = TextRange.sanitize
InlineInput.NormalizeSearchText = TextRange.search_normalize

return InlineInput
