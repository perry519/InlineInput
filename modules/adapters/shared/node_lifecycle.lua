local InlineInput = _G.InlineInput

function InlineInput:GetNodeBoxes(node_gui)
	if not node_gui then
		return nil
	end

	node_gui[self._node_box_key] = node_gui[self._node_box_key] or {}

	return node_gui[self._node_box_key]
end

function InlineInput:GetInputBox(id, node_gui)
	local boxes = node_gui and node_gui[self._node_box_key]

	return boxes and boxes[id]
end

function InlineInput:SetInputBox(id, node_gui, input_box)
	local boxes = self:GetNodeBoxes(node_gui)

	if boxes then
		boxes[id] = input_box
	end
end

function InlineInput:DestroyConfig(config, node_gui)
	local input_box = self:GetInputBox(config.id, node_gui)

	if input_box then
		self:RestoreInputRowMouseHitbox(input_box._inline_input_row_item)
		input_box._inline_input_destroying = true

		if input_box.destroy then
			self:WithMutedComponentEvents({ "menu_exit" }, function()
				input_box:destroy()
			end)
		else
			self:DisconnectInput(input_box)
		end
	end

	self:SetInputBox(config.id, node_gui, nil)
end

function InlineInput:DestroyNode(node_gui)
	if not node_gui then
		return
	end

	node_gui._inline_input_frame_rows = nil
	local boxes = node_gui[self._node_box_key]

	if not boxes then
		return
	end

	for id in pairs(boxes) do
		local config = self._registrations[id] or { id = id }
		self:DestroyConfig(config, node_gui)
	end
end

function InlineInput:SyncConfig(config, node_gui, row_lookup)
	if not config then
		return nil
	end
	if not row_lookup then
		self:InvalidateNodeRows(node_gui)
	end

	if not self:IsNode(config, node_gui, row_lookup) then
		self:LogOnce(
			"sync_not_node_" .. tostring(config.id),
			"sync skipped for " .. tostring(config.id) .. ": node did not match"
		)
		self:DestroyConfig(config, node_gui)
		return nil
	end

	local row_item = self:FindInputRow(config, node_gui, row_lookup)
	if row_lookup and row_item and (not row_lookup.persistent or config.is_enabled) then
		row_lookup.rows = nil
	end

	if not row_item or not self:IsEnabled(config, node_gui, row_item) then
		self:LogOnce(
			"sync_no_row_" .. tostring(config.id),
			"sync skipped for "
				.. tostring(config.id)
				.. ": row_item="
				.. tostring(row_item ~= nil)
				.. ", enabled="
				.. tostring(row_item and self:IsEnabled(config, node_gui, row_item))
		)
		self:DestroyConfig(config, node_gui)
		return nil
	end

	local input_box = self:GetInputBox(config.id, node_gui) or self:Create(config, node_gui, row_item)

	if input_box then
		if input_box._inline_input_row_item ~= row_item then
			self:RestoreInputRowMouseHitbox(input_box._inline_input_row_item)
		end

		self:PatchInputBoxCaret(input_box)
		self:PatchInputBoxKeys(input_box, config, node_gui)
		self:ApplyMaxLength(config, input_box)
		self:PatchInputRowMouseHitbox(config, row_item)
		input_box._inline_input_row_item = row_item
		self:Position(config, node_gui, row_item)
		self:SetPlaceholderText(config, input_box)

		if not self:IsActiveInputBox(config, node_gui, input_box) then
			self:SetBoxText(input_box, self:GetValue(config))
			self:SetInputBoxEditVisible(config, input_box, false)
		else
			self:SetInputBoxEditVisible(config, input_box, true)
			self:BindInputBoxCallbacks(config, node_gui, input_box)
			self:HighlightRow(config, node_gui)
		end
	end

	return input_box
end

function InlineInput:InvalidateNodeRows(node_gui)
	local row_lookup = node_gui and node_gui._inline_input_frame_rows
	if row_lookup then
		row_lookup.rows = nil
	end
end

function InlineInput:UpdateNode(node_gui)
	if not node_gui then
		return nil
	end
	local rows = node_gui.row_items
	local row_lookup = node_gui._inline_input_frame_rows
	if not row_lookup then
		row_lookup = { persistent = true }
		node_gui._inline_input_frame_rows = row_lookup
	end
	local count = rows and #rows or 0
	if row_lookup.source ~= rows or row_lookup.count ~= count then
		row_lookup.rows = nil
		row_lookup.source, row_lookup.count = rows, count
	end
	return self:SyncNode(node_gui, row_lookup)
end

function InlineInput:SyncNode(node_gui, row_lookup)
	if not node_gui then
		return nil
	end

	local first_input_box = nil
	local registration_order = node_gui._inline_input_config_ids or self._registration_order
	if not row_lookup then
		self:InvalidateNodeRows(node_gui)
		row_lookup = #registration_order > 1 and {} or nil
	end

	for _, id in ipairs(registration_order) do
		local config = self._registrations[id]
		local previous_box = config and self:GetInputBox(config.id, node_gui)
		local input_box = config and self:SyncConfig(config, node_gui, row_lookup)
		if
			row_lookup
			and config
			and (
				(previous_box and (not row_lookup.persistent or not input_box))
				or config.node_match
				or config.row_match
				or config.get_item_name
				or type(config.item_id or config.id) == "function"
			)
		then
			row_lookup.rows = nil
		end

		if not first_input_box then
			first_input_box = input_box
		end
	end

	return first_input_box
end

return InlineInput
