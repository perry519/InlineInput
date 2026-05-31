local InlineInput = _G.InlineInput

function InlineInput:GetInputItemName(config, item, row_item, node_gui)
	local custom_name = InlineInput:SafeCall(config and config.get_item_name, item, row_item, node_gui, config)

	if custom_name ~= nil then
		return custom_name
	end

	if item and item.parameters then
		local parameters = item:parameters()

		if parameters then
			return parameters.name
		end
	end

	if item and item._parameters then
		return item._parameters.name
	end

	return nil
end

function InlineInput:ItemIdMatches(item_id, item_name)
	if type(item_id) == "function" then
		return InlineInput:SafeCall(item_id, item_name) == true
	end

	if type(item_id) == "table" then
		if item_id[item_name] == true then
			return true
		end

		for _, value in pairs(item_id) do
			if value == item_name then
				return true
			end
		end

		return false
	end

	return tostring(item_id or "") == tostring(item_name or "")
end

function InlineInput:RowMatches(config, row_item, node_gui)
	if not config or not row_item then
		return false
	end

	local custom_match = InlineInput:SafeCall(config.row_match, row_item, node_gui, config)

	if custom_match ~= nil then
		return custom_match == true
	end

	local item_id = config.item_id or config.id

	return self:ItemIdMatches(item_id, self:GetInputItemName(config, row_item.item, row_item, node_gui))
end

function InlineInput:FindInputRow(config, node_gui)
	for _, row_item in ipairs(node_gui and node_gui.row_items or {}) do
		if self:RowMatches(config, row_item, node_gui) and self:IsAlive(row_item.gui_panel) then
			return row_item
		end
	end

	return nil
end

function InlineInput:HasRegisteredNodeId(node_id)
	if not node_id then
		return false
	end

	for _, config in pairs(self._registrations or {}) do
		if config.menu_id == node_id then
			return true
		end
	end

	return false
end

function InlineInput:IsNode(config, node_gui)
	if not config or not node_gui then
		return false
	end

	local custom_match = InlineInput:SafeCall(config.node_match, node_gui, config)

	if custom_match ~= nil then
		return custom_match == true
	end

	local node_name = self:GetInputNodeName(node_gui)

	if config.menu_id then
		if node_name == config.menu_id then
			return true
		end

		if self:HasRegisteredNodeId(node_name) then
			return false
		end

		return self:FindInputRow(config, node_gui) ~= nil
	end

	return self:FindInputRow(config, node_gui) ~= nil
end

function InlineInput:IsEnabled(config, node_gui, row_item)
	local enabled = InlineInput:SafeCall(config and config.is_enabled, node_gui, row_item, config)

	if enabled ~= nil then
		return enabled ~= false
	end

	return true
end

InlineInput.GetMenuItemName = InlineInput.GetInputItemName
InlineInput.HasRegisteredMenuId = InlineInput.HasRegisteredNodeId

return InlineInput
