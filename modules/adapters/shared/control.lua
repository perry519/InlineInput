local InlineInput = _G.InlineInput

InlineInput.Adapter = InlineInput.Adapter or {}

local Adapter = InlineInput.Adapter

Adapter._visible_state = Adapter._visible_state or setmetatable({}, { __mode = "k" })

function Adapter.current_visible(control)
	if not control then
		return nil
	end

	if type(control.visible) == "function" then
		local ok, visible = pcall(control.visible, control)

		if ok and type(visible) == "boolean" then
			return visible
		end
	elseif type(control.visible) == "boolean" then
		return control.visible
	end

	return Adapter._visible_state[control]
end

function Adapter.set_visible(control, visible)
	if control and control.set_visible then
		visible = visible == true

		if Adapter.current_visible(control) == visible then
			return
		end

		InlineInput:SafeCall(function()
			control:set_visible(visible)
		end)

		Adapter._visible_state[control] = visible
	end
end

function Adapter.control_value(control, method)
	if control and control[method] then
		local ok, value = pcall(control[method], control)

		if ok then
			return value
		end
	end

	return nil
end

function Adapter.control_number(control, method, fallback)
	local value = Adapter.control_value(control, method)

	if type(value) == "number" then
		return value
	end

	return fallback or 0
end

Adapter.panel_number = Adapter.control_number

function Adapter.set_control_number(control, method, value)
	if control and control[method] and type(value) == "number" then
		InlineInput:SafeCall(function()
			control[method](control, value)
		end)
	end
end

Adapter.set_panel_number = Adapter.set_control_number

function Adapter.child_by_name(control, name)
	if control and control.child then
		local ok, child = pcall(control.child, control, name)

		if ok then
			return child
		end
	end
end

Adapter.panel_child = Adapter.child_by_name

function Adapter.children(control)
	if control and control.children then
		local ok, children = pcall(control.children, control)

		if ok and type(children) == "table" then
			return children
		end
	end

	return {}
end

Adapter.panel_children = Adapter.children

function Adapter.control_name(control)
	local name = Adapter.control_value(control, "name")

	if name ~= nil then
		return tostring(name)
	end

	return control and control._name or nil
end

function Adapter.append_unique(candidates, candidate)
	if not candidate then
		return
	end

	for _, existing in ipairs(candidates) do
		if existing == candidate then
			return
		end
	end

	table.insert(candidates, candidate)
end

function Adapter.color_value(color, key)
	if not color then
		return nil
	end

	local value = color[key]

	if type(value) == "function" then
		local ok, result = pcall(value, color)

		if ok then
			return result
		end
	end

	return value
end

function Adapter.same_color(left, right)
	if left == right then
		return true
	end

	if not left or not right then
		return false
	end

	local compared = false

	for _, key in ipairs({ "alpha", "red", "green", "blue" }) do
		local left_value = Adapter.color_value(left, key)
		local right_value = Adapter.color_value(right, key)

		if left_value ~= nil or right_value ~= nil then
			compared = true

			if left_value ~= right_value then
				return false
			end
		end
	end

	return compared
end

function Adapter.screen_color(name, fallback)
	local colors = tweak_data and tweak_data.screen_colors
	return colors and colors[name] or fallback
end

function Adapter.menu_font()
	return tweak_data and tweak_data.menu and tweak_data.menu.pd2_medium_font or nil
end

function Adapter.menu_font_size(fallback)
	local font_size = tweak_data and tweak_data.menu and tweak_data.menu.pd2_medium_font_size

	if type(font_size) == "number" then
		return font_size
	end

	return fallback
end

function Adapter.set_shape(control, x, y, w, h)
	if not control then
		return
	end

	if control.set_shape then
		InlineInput:SafeCall(function()
			control:set_shape(x, y, w, h)
		end)
		return
	end

	if control.set_x then
		control:set_x(x)
	end

	if control.set_y then
		control:set_y(y)
	end

	if control.set_w then
		control:set_w(w)
	end

	if control.set_h then
		control:set_h(h)
	end
end

function Adapter.call_original(original, instance, ...)
	if original then
		return original(instance, ...)
	end
end

return InlineInput
