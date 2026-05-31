local InlineInput = _G.InlineInput

InlineInput._node_box_key = InlineInput._node_box_key or "_inline_input_boxes"

function InlineInput:InputBoxClass()
	if SearchBoxGuiObject then
		return SearchBoxGuiObject
	end

	if require then
		pcall(require, "lib/managers/menu/SearchBoxGuiObject")
		pcall(require, "lib/managers/menu/searchboxguiobject")
	end

	if not SearchBoxGuiObject then
		self:LogOnce("missing_input_box_class", "SearchBoxGuiObject is not available yet")
	end

	return SearchBoxGuiObject
end

function InlineInput:ResolveInputNodeGui(item)
	if item and (item.row_items or item.item_panel or item.node) then
		return item
	end

	local parameters = item and item.parameters and item:parameters()

	if parameters and parameters.gui_node then
		return parameters.gui_node
	end

	if self.ActiveNodeGui then
		return self:ActiveNodeGui()
	end

	return nil
end

function InlineInput:GetInputNodeName(node_gui)
	local node = node_gui and node_gui.node
	local parameters = node and node.parameters and node:parameters()

	if parameters and parameters.name then
		return parameters.name
	end

	return node_gui and node_gui.name
end

function InlineInput:DebugTargetName(target)
	return self:GetInputNodeName(target)
end

InlineInput.MenuInputBoxClass = InlineInput.InputBoxClass
InlineInput.ResolveMenuNodeGui = InlineInput.ResolveInputNodeGui
InlineInput.GetMenuNodeName = InlineInput.GetInputNodeName
InlineInput.ResolveNodeGui = InlineInput.ResolveInputNodeGui
InlineInput.GetNodeName = InlineInput.GetInputNodeName

return InlineInput
