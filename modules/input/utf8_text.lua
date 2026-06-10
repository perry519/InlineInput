local InlineInput = _G.InlineInput

InlineInput.Utf8Text = InlineInput.Utf8Text or {}

local Utf8Text = InlineInput.Utf8Text

function Utf8Text.sequence_byte_length(value, index)
	local first = string.byte(value, index)

	if not first then
		return 0, false
	end

	if first <= 0x7f then
		return 1, true
	end

	if first >= 0xc2 and first <= 0xdf then
		local second = string.byte(value, index + 1)
		return second and second >= 0x80 and second <= 0xbf and 2 or 1,
			second and second >= 0x80 and second <= 0xbf or false
	end

	if first == 0xe0 then
		local second, third = string.byte(value, index + 1), string.byte(value, index + 2)
		local valid = second and third and second >= 0xa0 and second <= 0xbf and third >= 0x80 and third <= 0xbf
		return valid and 3 or 1, valid == true
	end

	if first >= 0xe1 and first <= 0xec then
		local second, third = string.byte(value, index + 1), string.byte(value, index + 2)
		local valid = second and third and second >= 0x80 and second <= 0xbf and third >= 0x80 and third <= 0xbf
		return valid and 3 or 1, valid == true
	end

	if first == 0xed then
		local second, third = string.byte(value, index + 1), string.byte(value, index + 2)
		local valid = second and third and second >= 0x80 and second <= 0x9f and third >= 0x80 and third <= 0xbf
		return valid and 3 or 1, valid == true
	end

	if first >= 0xee and first <= 0xef then
		local second, third = string.byte(value, index + 1), string.byte(value, index + 2)
		local valid = second and third and second >= 0x80 and second <= 0xbf and third >= 0x80 and third <= 0xbf
		return valid and 3 or 1, valid == true
	end

	if first == 0xf0 then
		local second, third, fourth = string.byte(value, index + 1), string.byte(value, index + 2), string.byte(value, index + 3)
		local valid = second
			and third
			and fourth
			and second >= 0x90
			and second <= 0xbf
			and third >= 0x80
			and third <= 0xbf
			and fourth >= 0x80
			and fourth <= 0xbf
		return valid and 4 or 1, valid == true
	end

	if first >= 0xf1 and first <= 0xf3 then
		local second, third, fourth = string.byte(value, index + 1), string.byte(value, index + 2), string.byte(value, index + 3)
		local valid = second
			and third
			and fourth
			and second >= 0x80
			and second <= 0xbf
			and third >= 0x80
			and third <= 0xbf
			and fourth >= 0x80
			and fourth <= 0xbf
		return valid and 4 or 1, valid == true
	end

	if first == 0xf4 then
		local second, third, fourth = string.byte(value, index + 1), string.byte(value, index + 2), string.byte(value, index + 3)
		local valid = second
			and third
			and fourth
			and second >= 0x80
			and second <= 0x8f
			and third >= 0x80
			and third <= 0xbf
			and fourth >= 0x80
			and fourth <= 0xbf
		return valid and 4 or 1, valid == true
	end

	return 1, false
end

function Utf8Text.sanitize(value)
	value = tostring(value or "")

	local value_bytes = string.len(value)
	local index = 1
	local clean_parts = nil

	while index <= value_bytes do
		local byte_length, valid = Utf8Text.sequence_byte_length(value, index)

		if valid then
			if clean_parts then
				clean_parts[#clean_parts + 1] = string.sub(value, index, index + byte_length - 1)
			end
		elseif not clean_parts then
			clean_parts = {
				string.sub(value, 1, index - 1)
			}
		end

		index = index + math.max(byte_length, 1)
	end

	return clean_parts and table.concat(clean_parts) or value
end

local function codepoint_at(value, index)
	local first = string.byte(value, index)

	if not first then
		return nil, 0, false
	end

	if first <= 0x7f then
		return first, 1, true
	elseif first >= 0xc2 and first <= 0xdf then
		local second = string.byte(value, index + 1)

		if second and second >= 0x80 and second <= 0xbf then
			return (first - 0xc0) * 0x40 + (second - 0x80), 2, true
		end
	elseif first >= 0xe0 and first <= 0xef then
		local second, third = string.byte(value, index + 1), string.byte(value, index + 2)
		local second_ok = second
			and second >= 0x80
			and second <= 0xbf
			and not (first == 0xe0 and second < 0xa0)
			and not (first == 0xed and second > 0x9f)

		if second_ok and third and third >= 0x80 and third <= 0xbf then
			return (first - 0xe0) * 0x1000 + (second - 0x80) * 0x40 + (third - 0x80), 3, true
		end
	elseif first >= 0xf0 and first <= 0xf4 then
		local second, third, fourth = string.byte(value, index + 1), string.byte(value, index + 2), string.byte(value, index + 3)
		local second_ok = second
			and second >= 0x80
			and second <= 0xbf
			and not (first == 0xf0 and second < 0x90)
			and not (first == 0xf4 and second > 0x8f)

		if second_ok and third and third >= 0x80 and third <= 0xbf and fourth and fourth >= 0x80 and fourth <= 0xbf then
			return (first - 0xf0) * 0x40000 + (second - 0x80) * 0x1000 + (third - 0x80) * 0x40 + (fourth - 0x80), 4, true
		end
	end

	return first, 1, false
end

local function encode_codepoint(codepoint)
	if codepoint <= 0x7f then
		return string.char(codepoint)
	elseif codepoint <= 0x7ff then
		return string.char(
			0xc0 + math.floor(codepoint / 0x40),
			0x80 + (codepoint % 0x40)
		)
	elseif codepoint <= 0xffff then
		return string.char(
			0xe0 + math.floor(codepoint / 0x1000),
			0x80 + (math.floor(codepoint / 0x40) % 0x40),
			0x80 + (codepoint % 0x40)
		)
	end

	return string.char(
		0xf0 + math.floor(codepoint / 0x40000),
		0x80 + (math.floor(codepoint / 0x1000) % 0x40),
		0x80 + (math.floor(codepoint / 0x40) % 0x40),
		0x80 + (codepoint % 0x40)
	)
end

local CASE_FOLD_OVERRIDES = {
	[0x0130] = 0x0069,
	[0x0178] = 0x00ff,
	[0x0386] = 0x03ac,
	[0x0388] = 0x03ad,
	[0x0389] = 0x03ae,
	[0x038a] = 0x03af,
	[0x038c] = 0x03cc,
	[0x038e] = 0x03cd,
	[0x038f] = 0x03ce,
	[0x1e9e] = 0x00df
}

local function lower_codepoint(codepoint)
	local override = CASE_FOLD_OVERRIDES[codepoint]

	if override then
		return override
	elseif codepoint >= 0x41 and codepoint <= 0x5a then
		return codepoint + 0x20
	elseif codepoint >= 0xc0 and codepoint <= 0xd6 then
		return codepoint + 0x20
	elseif codepoint >= 0xd8 and codepoint <= 0xde then
		return codepoint + 0x20
	elseif codepoint >= 0x0100 and codepoint <= 0x012e and codepoint % 2 == 0 then
		return codepoint + 1
	elseif codepoint >= 0x0132 and codepoint <= 0x0136 and codepoint % 2 == 0 then
		return codepoint + 1
	elseif codepoint >= 0x0139 and codepoint <= 0x0148 and codepoint % 2 == 1 then
		return codepoint + 1
	elseif codepoint >= 0x014a and codepoint <= 0x0176 and codepoint % 2 == 0 then
		return codepoint + 1
	elseif codepoint >= 0x0179 and codepoint <= 0x017d and codepoint % 2 == 1 then
		return codepoint + 1
	elseif codepoint >= 0x0391 and codepoint <= 0x03a1 then
		return codepoint + 0x20
	elseif codepoint >= 0x03a3 and codepoint <= 0x03ab then
		return codepoint + 0x20
	elseif codepoint >= 0x410 and codepoint <= 0x42f then
		return codepoint + 0x20
	elseif codepoint >= 0x400 and codepoint <= 0x40f then
		return codepoint + 0x50
	elseif codepoint >= 0xff21 and codepoint <= 0xff3a then
		return codepoint + 0x20
	end

	return codepoint
end

local function case_fold(value)
	value = tostring(value or "")

	local parts = {}
	local index = 1
	local value_bytes = string.len(value)
	local changed = false

	while index <= value_bytes do
		local codepoint, byte_length, valid = codepoint_at(value, index)
		local next_index = index + math.max(byte_length, 1)

		if valid then
			local lowered = lower_codepoint(codepoint)
			parts[#parts + 1] = encode_codepoint(lowered)
			changed = changed or lowered ~= codepoint
		else
			parts[#parts + 1] = string.sub(value, index, next_index - 1)
		end

		index = next_index
	end

	return changed and table.concat(parts) or value
end

function Utf8Text.search_normalize(value)
	return case_fold(Utf8Text.sanitize(value))
end

return Utf8Text
