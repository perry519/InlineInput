local InlineInput = _G.InlineInput

local TEXT_INPUT_KEY_NAMES = {}
local TEXT_INPUT_KEY_CHARACTERS = {}
local SHIFT_TEXT_INPUT_KEY_CHARACTERS = {}
local key_idstrings = {}
local CONTROL_INPUT_KEY_NAMES = {
	"a",
	"c",
	"x",
	"v",
	"left",
	"arrow left",
	"left arrow",
	"right",
	"arrow right",
	"right arrow"
}
local EDIT_INPUT_KEY_NAMES = {
	"home",
	"end",
	"page up",
	"pageup",
	"page down",
	"pagedown",
	"delete",
	"del"
}

local function add_text_input_key(name, character, shift_character)
	table.insert(TEXT_INPUT_KEY_NAMES, name)
	TEXT_INPUT_KEY_CHARACTERS[name] = character
	SHIFT_TEXT_INPUT_KEY_CHARACTERS[name] = shift_character or character
end

for code = string.byte("a"), string.byte("z") do
	local character = string.char(code)
	add_text_input_key(character, character, string.upper(character))
end

for code = string.byte("0"), string.byte("9") do
	local character = string.char(code)
	add_text_input_key(character, character)
end

for index = 0, 9 do
	add_text_input_key("num " .. tostring(index), tostring(index))
end

for index, shifted in ipairs({ "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" }) do
	SHIFT_TEXT_INPUT_KEY_CHARACTERS[tostring(index % 10)] = shifted
end

for _, spec in ipairs({
	{ "space", " " },
	{ "minus", "-", "_" },
	{ "equals", "=", "+" },
	{ "left bracket", "[", "{" },
	{ "right bracket", "]", "}" },
	{ "backslash", "\\", "|" },
	{ "semicolon", ";", ":" },
	{ "apostrophe", "'", '"' },
	{ "comma", ",", "<" },
	{ "period", ".", ">" },
	{ "slash", "/", "?" },
	{ "grave", "`", "~" },
	{ "num decimal", "." },
	{ "num divide", "/" },
	{ "num multiply", "*" },
	{ "num minus", "-" },
	{ "num plus", "+" },
	{ "oem 102", "\\", "|" },
	{ "-", "-", "_" },
	{ "=", "=", "+" },
	{ "[", "[", "{" },
	{ "]", "]", "}" },
	{ "\\", "\\", "|" },
	{ ";", ";", ":" },
	{ "'", "'", '"' },
	{ ",", ",", "<" },
	{ ".", ".", ">" },
	{ "/", "/", "?" },
	{ "`", "`", "~" },
}) do
	add_text_input_key(spec[1], spec[2], spec[3])
end

local function key_idstring(name)
	if not Idstring then
		return name
	end

	if key_idstrings[name] == nil then
		local ok, idstring = pcall(function()
			return Idstring(name)
		end)

		key_idstrings[name] = ok and idstring or false
	end

	return key_idstrings[name] ~= false and key_idstrings[name] or name
end

local function active_keyboard()
	return Input and Input.keyboard and Input:keyboard()
end

local function keyboard_state(keyboard, method, name)
	return keyboard
		and keyboard[method]
		and InlineInput:SafeCall(function()
			return keyboard[method](keyboard, key_idstring(name))
		end)
end

local function pressed_key(keyboard, names)
	for _, name in ipairs(names) do
		if keyboard_state(keyboard, "pressed", name) then
			return key_idstring(name), name
		end
	end

	return nil
end

function InlineInput:IsKey(key, name)
	return key == name or key == key_idstring(name)
end

function InlineInput:IsLeftKey(key)
	return self:IsKey(key, "left") or self:IsKey(key, "arrow left") or self:IsKey(key, "left arrow")
end

function InlineInput:IsRightKey(key)
	return self:IsKey(key, "right") or self:IsKey(key, "arrow right") or self:IsKey(key, "right arrow")
end

function InlineInput:IsUpKey(key)
	return self:IsKey(key, "up") or self:IsKey(key, "arrow up") or self:IsKey(key, "up arrow")
end

function InlineInput:IsDownKey(key)
	return self:IsKey(key, "down") or self:IsKey(key, "arrow down") or self:IsKey(key, "down arrow")
end

function InlineInput:IsHomeKey(key)
	return self:IsKey(key, "home")
end

function InlineInput:IsEndKey(key)
	return self:IsKey(key, "end")
end

function InlineInput:IsPageUpKey(key)
	return self:IsKey(key, "page up") or self:IsKey(key, "pageup")
end

function InlineInput:IsPageDownKey(key)
	return self:IsKey(key, "page down") or self:IsKey(key, "pagedown")
end

function InlineInput:IsDeleteKey(key)
	return self:IsKey(key, "delete") or self:IsKey(key, "del")
end

function InlineInput:IsTextInputKey(key)
	for _, name in ipairs(TEXT_INPUT_KEY_NAMES) do
		if self:IsKey(key, name) then
			return true, name
		end
	end

	return false
end

function InlineInput:IsInitialEditKey(key)
	return self:IsKey(key, "backspace")
end

function InlineInput:KeyboardDown(...)
	local keyboard = active_keyboard()

	for _, name in ipairs({ ... }) do
		if keyboard_state(keyboard, "down", name) then
			return true
		end
	end

	return false
end

function InlineInput:IsBackspaceDown()
	return self:KeyboardDown("backspace")
end

function InlineInput:IsLeftDown()
	return self:KeyboardDown("left", "arrow left", "left arrow")
end

function InlineInput:IsRightDown()
	return self:KeyboardDown("right", "arrow right", "right arrow")
end

function InlineInput:IsControlDown()
	return self:KeyboardDown("left ctrl", "right ctrl", "ctrl", "left control", "right control", "control")
end

function InlineInput:IsShiftDown()
	return self:KeyboardDown("left shift", "right shift", "shift")
end

function InlineInput:PressedInputActivationKey()
	local keyboard = active_keyboard()

	if keyboard_state(keyboard, "pressed", "backspace") then
		return key_idstring("backspace"), "backspace"
	end

	local key, key_name
	if self:IsControlDown() then
		key, key_name = pressed_key(keyboard, CONTROL_INPUT_KEY_NAMES)
		if key then
			return key, key_name
		end

		key, key_name = pressed_key(keyboard, EDIT_INPUT_KEY_NAMES)
		if key then
			return key, key_name
		end

		return nil
	end

	key, key_name = pressed_key(keyboard, EDIT_INPUT_KEY_NAMES)
	if key then
		return key, key_name
	end

	for _, name in ipairs(TEXT_INPUT_KEY_NAMES) do
		if keyboard_state(keyboard, "pressed", name) then
			return key_idstring(name), name
		end
	end

	return nil
end

function InlineInput:TextInputCharacter(key, key_name)
	if not key_name then
		local is_text_key
		is_text_key, key_name = self:IsTextInputKey(key)

		if not is_text_key then
			return nil
		end
	end

	if self:KeyboardDown("left shift", "right shift", "shift") then
		return SHIFT_TEXT_INPUT_KEY_CHARACTERS[key_name]
	end

	return TEXT_INPUT_KEY_CHARACTERS[key_name]
end

return InlineInput
