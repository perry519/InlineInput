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

	local boxes = node_gui[self._node_box_key]

	if not boxes then
		return
	end

	for id in pairs(boxes) do
		local config = self._registrations[id] or { id = id }
		self:DestroyConfig(config, node_gui)
	end
end

function InlineInput:SyncConfig(config, node_gui)
	if not config then
		return nil
	end

	if not self:IsNode(config, node_gui) then
		self:LogOnce("sync_not_node_" .. tostring(config.id), "sync skipped for " .. tostring(config.id) .. ": node did not match")
		self:DestroyConfig(config, node_gui)
		return nil
	end

	local row_item = self:FindInputRow(config, node_gui)

	if not row_item or not self:IsEnabled(config, node_gui, row_item) then
		self:LogOnce("sync_no_row_" .. tostring(config.id), "sync skipped for " .. tostring(config.id) .. ": row_item=" .. tostring(row_item ~= nil) .. ", enabled=" .. tostring(row_item and self:IsEnabled(config, node_gui, row_item)))
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

function InlineInput:SyncNode(node_gui)
	if not node_gui then
		return nil
	end

	local first_input_box = nil
	local registration_order = node_gui._inline_input_config_ids or self._registration_order

	for _, id in ipairs(registration_order) do
		local config = self._registrations[id]
		local input_box = config and self:SyncConfig(config, node_gui)

		if not first_input_box then
			first_input_box = input_box
		end
	end

	return first_input_box
end

return InlineInput
