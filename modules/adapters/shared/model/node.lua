local InlineInput = _G.InlineInput

function InlineInput:GetInputItemName(config, item, row_item, node_gui)
	if config and config.get_item_name then
		local custom_name = InlineInput:SafeCall(config.get_item_name, item, row_item, node_gui, config)
		if custom_name ~= nil then
			return custom_name
		end
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

function InlineInput:FindInputRow(config, node_gui, row_lookup)
	local item_id = config and (config.item_id or config.id)
	if
		row_lookup
		and config
		and not config.node_match
		and not config.row_match
		and not config.get_item_name
		and (type(item_id) == "string" or type(item_id) == "number")
	then
		local rows_by_name = row_lookup.rows
		if not rows_by_name then
			rows_by_name = {}
			row_lookup.rows = rows_by_name
			row_lookup.next_row = 1
			row_lookup.positions = row_lookup.persistent and {} or nil
		end
		local item_name = tostring(item_id)
		local row_item = rows_by_name[item_name]
		local row_index = row_lookup.next_row
		if not row_item and row_index then
			local rows = node_gui and node_gui.row_items or {}
			while true do
				local candidate = rows[row_index]
				if not candidate then
					row_index = nil
					break
				end
				local name = tostring(self:GetInputItemName(nil, candidate.item, candidate, node_gui) or "")
				if not rows_by_name[name] then
					rows_by_name[name] = candidate
					if row_lookup.positions then
						row_lookup.positions[name] = row_index
					end
				end
				row_index = row_index + 1
				if name == item_name then
					break
				end
			end
			row_lookup.next_row = row_index
			row_item = rows_by_name[item_name]
		end
		if row_item and row_lookup.persistent then
			local position = row_lookup.positions[item_name]
			if
				node_gui.row_items[position] ~= row_item
				or tostring(self:GetInputItemName(nil, row_item.item, row_item, node_gui) or "") ~= item_name
			then
				row_lookup.rows = nil
				return self:FindInputRow(config, node_gui, row_lookup)
			end
		end
		if not row_item or self:IsAlive(row_item.gui_panel) then
			return row_item
		end
	end

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

function InlineInput:IsNode(config, node_gui, row_lookup)
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

		return self:FindInputRow(config, node_gui, row_lookup) ~= nil
	end

	return self:FindInputRow(config, node_gui, row_lookup) ~= nil
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
