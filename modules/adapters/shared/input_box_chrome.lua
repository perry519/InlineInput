local InlineInput = _G.InlineInput

local Adapter = InlineInput.Adapter

local BOX_CHILD_NAMES = {
	"BoxGuiObject0",
	"BoxGuiObject1",
	"BoxGuiObject2",
	"BoxGuiObject3"
}

function Adapter.set_text_vertical_center(text, height)
	if not text then
		return
	end

	if text.set_vertical then
		InlineInput:SafeCall(function()
			text:set_vertical("center")
		end)
	end

	if text.set_y then
		text:set_y(0)
	end

	if text.set_h then
		text:set_h(height)
	end
end

function Adapter.reflow_box_corners(side_panel, vertical, length)
	local children = Adapter.panel_children(side_panel)
	local first = children[1]
	local second = children[2]

	if first then
		Adapter.set_panel_number(first, "set_x", 0)
		Adapter.set_panel_number(first, "set_y", 0)
	end

	if second then
		if vertical then
			Adapter.set_panel_number(second, "set_bottom", length)
		else
			Adapter.set_panel_number(second, "set_right", length)
		end
	end
end

function Adapter.reflow_box_panel(box_panel, width, height)
	if not box_panel then
		return
	end

	Adapter.set_panel_number(box_panel, "set_w", width)
	Adapter.set_panel_number(box_panel, "set_h", height)

	local left = Adapter.panel_child(box_panel, "left")
	local right = Adapter.panel_child(box_panel, "right")
	local top = Adapter.panel_child(box_panel, "top")
	local bottom = Adapter.panel_child(box_panel, "bottom")

	if left then
		Adapter.set_panel_number(left, "set_w", 2)
		Adapter.set_panel_number(left, "set_h", height)
		Adapter.set_panel_number(left, "set_x", 0)
		Adapter.reflow_box_corners(left, true, height)
	end

	if right then
		Adapter.set_panel_number(right, "set_w", 2)
		Adapter.set_panel_number(right, "set_h", height)
		Adapter.set_panel_number(right, "set_right", width)
		Adapter.set_panel_number(right, "set_x", width - Adapter.panel_number(right, "w", 2))
		Adapter.reflow_box_corners(right, true, height)
	end

	if top then
		Adapter.set_panel_number(top, "set_w", width)
		Adapter.set_panel_number(top, "set_h", 2)
		Adapter.set_panel_number(top, "set_y", 0)
		Adapter.reflow_box_corners(top, false, width)
	end

	if bottom then
		Adapter.set_panel_number(bottom, "set_w", width)
		Adapter.set_panel_number(bottom, "set_h", 2)
		Adapter.set_panel_number(bottom, "set_bottom", height)
		Adapter.set_panel_number(bottom, "set_y", height - Adapter.panel_number(bottom, "h", 2))
		Adapter.reflow_box_corners(bottom, false, width)
	end
end

function Adapter.reflow_input_chrome(input_box, width, height)
	local panel = input_box and input_box.panel

	if not panel then
		return
	end

	for _, name in ipairs(BOX_CHILD_NAMES) do
		Adapter.reflow_box_panel(Adapter.panel_child(panel, name), width, height)
	end

	for _, child in ipairs(Adapter.panel_children(panel)) do
		local name = Adapter.control_name(child)

		if type(name) == "string" and string.sub(name, 1, 12) == "BoxGuiObject" then
			Adapter.reflow_box_panel(child, width, height)
		end
	end
end

return InlineInput
