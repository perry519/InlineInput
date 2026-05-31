local InlineInput = _G.InlineInput

InlineInput.Adapter = InlineInput.Adapter or {}

local Adapter = InlineInput.Adapter

Adapter._button_idstrings = Adapter._button_idstrings or {}

function Adapter.button_matches(button, name)
	if button == name then
		return true
	end

	if type(button) == "number" and tostring(button) == name then
		return true
	end

	if Idstring then
		if Adapter._button_idstrings[name] == nil then
			local ok, idstring = pcall(function()
				return Idstring(name)
			end)

			Adapter._button_idstrings[name] = ok and idstring or false
		end

		return Adapter._button_idstrings[name] ~= false and button == Adapter._button_idstrings[name]
	end

	return false
end

function Adapter.primary_button(button)
	return Adapter.button_matches(button, "0")
end

function Adapter.normalize_mouse_args(a, b, c)
	if type(a) == "number" and type(b) == "number" and c == nil then
		return nil, a, b
	end

	if type(b) == "number" and type(c) == "number" then
		return a, b, c
	end

	return a, b, c
end

function Adapter.menu_input_mouse_position(menu_input, x, y)
	if menu_input and menu_input._modified_mouse_pos and type(x) == "number" and type(y) == "number" then
		local ok, modified_x, modified_y = pcall(menu_input._modified_mouse_pos, menu_input, x, y)

		if ok and type(modified_x) == "number" and type(modified_y) == "number" then
			return modified_x, modified_y
		end
	end

	return x, y
end

return InlineInput
