local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter

local BOX_SIDE_NAMES = { "left", "right", "top", "bottom" }
local BOX_CHILD_NAMES = {
	"BoxGuiObject0",
	"BoxGuiObject1",
	"BoxGuiObject2",
	"BoxGuiObject3"
}

local set_visible = Adapter.set_visible
local control_value = Adapter.control_value
local append_unique = Adapter.append_unique
local control_name = Adapter.control_name
local child_by_name = Adapter.child_by_name

local function control_layer(control)
	local layer = control_value(control, "layer")

	if type(layer) == "number" then
		return layer
	end

	return control and control._layer or nil
end

local function has_box_sides(control)
	for _, name in ipairs(BOX_SIDE_NAMES) do
		if child_by_name(control, name) then
			return true
		end
	end

	return false
end

local function is_box_border(control)
	local name = control_name(control)

	if type(name) == "string" and string.sub(name, 1, 12) == "BoxGuiObject" then
		return true
	end

	return has_box_sides(control)
end

local function add_box_border_children(candidates, panel)
	if not panel then
		return
	end

	for _, name in ipairs(BOX_CHILD_NAMES) do
		append_unique(candidates, child_by_name(panel, name))
	end

	if panel.children then
		local ok, children = pcall(panel.children, panel)

		if ok and type(children) == "table" then
			for _, child in pairs(children) do
				if is_box_border(child) then
					append_unique(candidates, child)
				end
			end
		end
	end
end

local function add_background_children(candidates, panel)
	if not panel then
		return
	end

	for _, name in ipairs({ "background", "bg", "input_background" }) do
		append_unique(candidates, child_by_name(panel, name))
	end

	if type(panel._rects) == "table" then
		for _, rect in ipairs(panel._rects) do
			if control_layer(rect) == -1 then
				append_unique(candidates, rect)
			end
		end
	end

	if panel.children then
		local ok, children = pcall(panel.children, panel)

		if ok and type(children) == "table" then
			for _, child in pairs(children) do
				if control_layer(child) == -1 and not is_box_border(child) then
					append_unique(candidates, child)
				end
			end
		end
	end
end

function InlineInput:ApplyMaxLength(config, input_box)
	local max_length = self:GetMaxLength(config)

	if not max_length or not input_box then
		return
	end

	input_box._inline_input_max_length = max_length

	if SearchBoxGuiObject and type(SearchBoxGuiObject.MAX_SEARCH_LENGTH) == "number" and max_length > SearchBoxGuiObject.MAX_SEARCH_LENGTH then
		SearchBoxGuiObject.MAX_SEARCH_LENGTH = max_length
	end
end

function InlineInput:SetInputBackgroundColor(input_box, color)
	if not color then
		return false
	end

	local candidates = {}

	if input_box then
		append_unique(candidates, input_box.background)
		append_unique(candidates, input_box._background)
		append_unique(candidates, input_box.background_rect)
		append_unique(candidates, input_box._background_rect)
		append_unique(candidates, input_box.bg)
		append_unique(candidates, input_box._bg)
		append_unique(candidates, input_box._inline_input_background)
		add_background_children(candidates, input_box.panel)
	end

	for _, candidate in ipairs(candidates) do
		if candidate.set_color then
			candidate:set_color(color)
		end
	end

	return #candidates > 0
end

function InlineInput:ApplyInputBackgroundColor(config, input_box)
	return self:SetInputBackgroundColor(input_box, self:InputBackgroundColor(config, input_box))
end

function InlineInput:SetInputBracketsVisible(input_box, visible)
	local candidates = {}

	if input_box then
		append_unique(candidates, input_box.box_gui_object)
		append_unique(candidates, input_box._box_gui_object)
		append_unique(candidates, input_box.border)
		append_unique(candidates, input_box._border)
		append_unique(candidates, input_box.box)
		append_unique(candidates, input_box._box)
		add_box_border_children(candidates, input_box.panel)
	end

	for _, candidate in ipairs(candidates) do
		set_visible(candidate, visible)
	end

	return #candidates > 0
end

function InlineInput:ApplyInputBracketsVisibility(config, input_box)
	return self:SetInputBracketsVisible(input_box, self:ShouldShowBrackets(config))
end

return InlineInput
