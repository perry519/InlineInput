local InlineInput = _G.InlineInput

local function clear_and_preserve(library, node_gui)
	library:ClearNodeHighlight(node_gui)
	library:PreserveScrollIndicatorsOnce(node_gui)
end

local function finish_input_blocks_parent(library, config, source)
	return source == "enter" or (source == "esc" and not library:ShouldPropagateEscape(config))
end

local function input_block_consumes_for_source(library, source)
	if source == "esc" then
		return library.DEFAULTS.escape_input_back_block_consumes
	end
end

local function disconnect_finished_input(library, input_box, config, node_gui, source, stored_value)
	if not input_box then
		return
	end

	input_box._inline_input_blurring = true

	library:DisconnectInput(input_box, config, node_gui, source, stored_value)

	input_box._inline_input_blurring = nil
end

function InlineInput:RefreshConfig(config, node_gui, value, source)
	if config.refresh == false then
		return
	end

	if type(config.refresh) == "function" then
		InlineInput:SafeCall(config.refresh, value, node_gui, source, config)
		return
	end

	if node_gui and node_gui.refresh_gui and node_gui.node then
		node_gui:refresh_gui(node_gui.node)
	end
end

function InlineInput:HandleInvalidValue(config, node_gui, input_box, value, previous_value, source)
	self:LogDebugEvent(config, "invalid", value, node_gui, source)
	InlineInput:SafeCall(config and config.on_invalid, value, node_gui, source, config)
	self:SetBoxText(input_box, previous_value)
	self:ClearNodeHighlight(node_gui)
	self:PreserveScrollIndicatorsOnce(node_gui)
end

local function refresh_value(library, config, node_gui, stored_value, source, options)
	local scroll_indicator_state = library:CaptureAndPreserveScrollIndicators(node_gui)
	library:RefreshConfig(config, node_gui, stored_value, source)
	local input_box = library:SyncConfig(config, node_gui)
	if options and options.refocus and input_box then
		library:ConnectInput(input_box)
		library:HighlightRow(config, node_gui)
	elseif not options or options.highlight ~= false then
		library:HighlightRow(config, node_gui)
	end
	library:RestoreAndPreserveScrollIndicators(node_gui, scroll_indicator_state)
	return input_box
end

local function focus_change_source(source)
	if source == "mouse" then
		return "outside_click"
	end

	return "focus_change"
end

function InlineInput:ClearNodeHighlight(node_gui)
	if not node_gui then
		return
	end

	for _, row_item in ipairs(node_gui.row_items or {}) do
		if row_item.highlighted then
			if node_gui._fade_row_item then
				InlineInput:SafeCall(function()
					node_gui:_fade_row_item(row_item)
				end)
			elseif row_item.gui_panel and row_item.gui_panel.set_color then
				row_item.highlighted = false
				row_item.color = row_item.row_item_color or node_gui.row_item_color or row_item.color
				row_item.gui_panel:set_color(row_item.color)
			else
				row_item.highlighted = false
			end
		end
	end

	node_gui._highlighted_item = nil
end

function InlineInput:WithMutedComponentEvents(events, callback)
	local menu_component = managers and managers.menu_component

	if type(callback) ~= "function" or not menu_component or type(menu_component.post_event) ~= "function" then
		return callback and callback()
	end

	local muted = {}

	for _, event in ipairs(events or {}) do
		muted[event] = true
	end

	local original_post_event = menu_component.post_event

	menu_component.post_event = function(target, event, ...)
		if muted[event] then
			return
		end

		return original_post_event(target, event, ...)
	end

	local results = { pcall(callback) }
	menu_component.post_event = original_post_event

	if not results[1] then
		error(results[2])
	end

	return results[2], results[3], results[4], results[5]
end

function InlineInput:IsInputBoxFocused(input_box)
	return input_box and input_box.input_focus and input_box:input_focus() == true
end

function InlineInput:SetActiveInputBox(config, node_gui, input_box)
	if not config or not node_gui or not input_box then
		return
	end

	node_gui._inline_input_active_id = config.id
	node_gui._inline_input_active_box = input_box
	input_box._inline_input_active_id = config.id
end

function InlineInput:ClearActiveInputBox(config, node_gui, input_box)
	if not node_gui or not input_box then
		return
	end

	local id = config and config.id or input_box._inline_input_active_id

	if node_gui._inline_input_active_box == input_box or node_gui._inline_input_active_id == id then
		node_gui._inline_input_active_id = nil
		node_gui._inline_input_active_box = nil
	end

	if input_box._inline_input_active_id == id then
		input_box._inline_input_active_id = nil
	end
end

function InlineInput:IsActiveInputBox(config, node_gui, input_box)
	if not config or not input_box then
		return false
	end

	if not node_gui or not node_gui._inline_input_active_id then
		return self:IsInputBoxFocused(input_box)
	end

	return node_gui._inline_input_active_id == config.id
		and node_gui._inline_input_active_box == input_box
		and self:IsInputBoxFocused(input_box)
end

function InlineInput:CallbackValue(config, input_box, value)
	if value ~= nil then
		return value
	end

	local input_value = self:GetInputBoxText(input_box)

	if input_value ~= nil then
		return input_value
	end

	return self:GetValue(config)
end

function InlineInput:IsReadOnly(config)
	return config
		and (
			config.not_editable == true
			or config.read_only == true
			or config.readonly == true
			or config.editable == false
		)
end

function InlineInput:NotifyConfigEvent(config, event, node_gui, input_box, source, value)
	if not config then
		return false
	end
	source = source or event
	value = self:CallbackValue(config, input_box, value)
	self:LogDebugEvent(config, event, value, node_gui, source)
	InlineInput:SafeCall(config["on_" .. event], value, node_gui, source, config, input_box)
	return true
end

function InlineInput:NotifyFocus(config, node_gui, input_box, source, value)
	if not config or not input_box or input_box._inline_input_focus_notified == true then
		return false
	end

	input_box._inline_input_focus_notified = true
	return self:NotifyConfigEvent(config, "focus", node_gui, input_box, source, value)
end

function InlineInput:NotifyBlur(config, node_gui, input_box, source, value)
	if not config or not input_box or input_box._inline_input_focus_notified ~= true then
		return false
	end

	input_box._inline_input_focus_notified = nil
	return self:NotifyConfigEvent(config, "blur", node_gui, input_box, source, value)
end

function InlineInput:NotifyFinish(config, node_gui, input_box, value, source)
	return self:NotifyConfigEvent(config, "finish", node_gui, input_box, source, value)
end

function InlineInput:FinishOtherFocusedInputs(config, node_gui, input_box, source)
	local boxes = node_gui and node_gui[self._node_box_key]

	if not boxes then
		return true
	end

	for id, other_input_box in pairs(boxes) do
		if other_input_box ~= input_box and self:IsInputBoxFocused(other_input_box) then
			local other_config = self._registrations[id]

			if other_config then
				self:FinishInput(other_config, node_gui, other_input_box, focus_change_source(source))
			else
				self:DisconnectInput(other_input_box, nil, node_gui, focus_change_source(source))
			end

			if self:IsInputBoxFocused(other_input_box) then
				return false
			end
		end
	end

	return true
end

function InlineInput:ConnectInput(input_box, config, node_gui, source)
	if not input_box or not input_box.connect_search_input then
		return
	end

	if not self:FinishOtherFocusedInputs(config, node_gui, input_box, source) then
		return false
	end

	local was_focused = self:IsInputBoxFocused(input_box)
	self:SetActiveInputBox(config, node_gui, input_box)
	self:SetInputBoxEditVisible(config, input_box, true)
	local result = true

	if not was_focused then
		result = self:WithMutedComponentEvents({ "menu_enter" }, function()
			return input_box:connect_search_input()
		end)

		self:ShowCaret(input_box)
	end

	if
		config
		and (not was_focused or input_box._inline_input_focus_notified ~= true)
		and self:IsInputBoxFocused(input_box)
	then
		self:NotifyFocus(config, node_gui, input_box, source or "focus")
	end

	return result
end

function InlineInput:DisconnectInput(input_box, config, node_gui, source, value)
	if not input_box or not input_box.disconnect_search_input then
		return
	end

	local was_focused = self:IsInputBoxFocused(input_box)
	local result = self:WithMutedComponentEvents({ "menu_exit" }, function()
		input_box._inline_input_wrapped_disconnect = true
		local disconnect_result = input_box:disconnect_search_input()
		input_box._inline_input_wrapped_disconnect = nil
		return disconnect_result
	end)

	input_box._inline_input_wrapped_disconnect = nil
	local is_focused = self:IsInputBoxFocused(input_box)

	if not is_focused then
		self:ClearInputSelection(input_box)
		self:HideCaret(input_box)
		self:ClearActiveInputBox(config, node_gui, input_box)
		self:SetInputBoxEditVisible(config, input_box, false)
	end

	if was_focused and not is_focused then
		local callback_value = value

		if callback_value == nil and config then
			callback_value = self:GetValue(config)
		end

		self:NotifyBlur(config, node_gui, input_box, source or "blur", callback_value)
	end

	return result
end

function InlineInput:PatchInputRowMouseHitbox(config, row_item)
	if not config or not row_item then
		return
	end

	self:RestoreInputRowMouseHitbox(row_item)
end

function InlineInput:RestoreInputRowMouseHitbox(row_item)
	if not row_item then
		return
	end

	if row_item._inline_input_original_row_no_mouse_select_set then
		row_item.no_mouse_select = row_item._inline_input_original_row_no_mouse_select
	end

	if row_item.item and row_item._inline_input_original_item_no_mouse_select_set then
		row_item.item.no_mouse_select = row_item._inline_input_original_item_no_mouse_select
	end

	row_item._inline_input_mouse_hitbox_id = nil
	row_item._inline_input_mouse_hitbox_disabled = nil
	row_item._inline_input_original_row_no_mouse_select = nil
	row_item._inline_input_original_row_no_mouse_select_set = nil
	row_item._inline_input_original_item_no_mouse_select = nil
	row_item._inline_input_original_item_no_mouse_select_set = nil
	row_item._inline_input_mouse_hitbox_patch_failed = nil
end

function InlineInput:HighlightRow(config, node_gui)
	if not config or config.keep_menu_highlight ~= true then
		self:ClearNodeHighlight(node_gui)
		return
	end

	local row_item = self:FindInputRow(config, node_gui)

	if not row_item or not row_item.item or not node_gui or not node_gui.highlight_item then
		return
	end

	InlineInput:SafeCall(function()
		node_gui:highlight_item(row_item.item, true)
	end)
end

function InlineInput:IsInputRowSelected(node_gui, row_item)
	if not node_gui or not row_item then
		return false
	end

	if row_item.highlighted == true then
		return true
	end

	local highlighted_item = node_gui._highlighted_item

	return highlighted_item ~= nil and (highlighted_item == row_item or highlighted_item == row_item.item)
end

function InlineInput:SelectedInactiveInputBox(node_gui)
	if not node_gui then
		return nil, nil, nil
	end

	self:SyncNode(node_gui)

	if self.FocusedInputBox then
		local focused_config, focused_input_box = self:FocusedInputBox(node_gui)

		if focused_config and focused_input_box then
			return nil, nil, nil
		end
	end

	local boxes = node_gui[self._node_box_key]

	for id, input_box in pairs(boxes or {}) do
		local config = self._registrations[id]

		if config and input_box and (not input_box.input_focus or not input_box:input_focus()) then
			local row_item = input_box._inline_input_row_item or self:FindInputRow(config, node_gui)
			local hovered = self._hovered_input_node == node_gui and self._hovered_input_id == id

			if hovered or self:IsInputRowSelected(node_gui, row_item) then
				return config, input_box, row_item
			end
		end
	end

	return nil, nil, nil
end

function InlineInput:ActivateSelectedInputTextKey(node_gui, key, key_name)
	local is_text_key
	is_text_key, key_name = self:IsTextInputKey(key)
	local is_edit_key = self:IsInitialEditKey(key)

	if
		not node_gui
		or not key
		or (
				not is_text_key
				and not is_edit_key
				and not self:IsSharedInputCommand(key)
			)
	then
		return false
	end

	if is_text_key and self:IsControlDown() and not self:IsSharedInputCommand(key) then
		return false
	end

	local config, input_box = self:SelectedInactiveInputBox(node_gui)

	if not config or not input_box then
		return false
	end

	local target = self:CreateInputBoxTarget(config, node_gui, input_box)
	local session = self:CreateInputSession(target)

	if session:activate("keyboard") == false then
		return true
	end

	local handled = self:ApplySharedInputCommand(session, input_box, key, { initial_backspace = true })

	if handled then
		return true
	elseif
		not session:insert_initial_text_character(key, key_name) and input_box.search_key_press
	then
		input_box:search_key_press(nil, key)
	end

	return true
end

function InlineInput:ActivateSelectedInputFromKeyboard(node_gui)
	local key, key_name = self:PressedInputActivationKey()

	return self:ActivateSelectedInputTextKey(node_gui, key, key_name)
end

function InlineInput:FinishInput(config, node_gui, input_box, source)
	if self:IsInputTarget(config) then
		local target = config
		source = source or node_gui
		config = target.config
		node_gui = target.node_gui
		input_box = target.input_box
	end

	local old_value = self:GetValue(config)
	local value = self:GetInputBoxText(input_box) or old_value
	local escape_behavior = self:EscapeBehavior(config)

	value = self:NormalizeText(config, value)

	if source == "esc" then
		if escape_behavior == "clear" then
			value = ""
		elseif escape_behavior == "revert" then
			value = old_value
		end
	end

	local blocks_parent_input = finish_input_blocks_parent(self, config, source)
	local valid, display_value, stored_value = self:ValidateValue(config, value, node_gui, source)

	if not valid then
		local scroll_indicator_state = self:CaptureAndPreserveScrollIndicators(node_gui)

		if blocks_parent_input then
			self:BlockNextInput(input_block_consumes_for_source(self, source))
		end

		self:HandleInvalidValue(config, node_gui, input_box, value, old_value, source)

		self:RestoreAndPreserveScrollIndicators(node_gui, scroll_indicator_state)

		return
	end

	self:SetBoxText(input_box, display_value)

	local changed = display_value ~= old_value
	local scroll_indicator_state = nil

	if blocks_parent_input then
		scroll_indicator_state = self:CaptureAndPreserveScrollIndicators(node_gui)
	end

	self:SetValue(config, stored_value, node_gui, source)

	if source == "enter" then
		self:LogDebugEvent(config, "submit", stored_value, node_gui, source)
		InlineInput:SafeCall(config.on_submit, stored_value, node_gui, source, config)
	elseif source == "esc" then
		self:LogDebugEvent(config, "cancel", stored_value, node_gui, source)
		InlineInput:SafeCall(config.on_cancel, stored_value, node_gui, source, config)
	end

	if blocks_parent_input then
		self:BlockNextInput(input_block_consumes_for_source(self, source))
	end

	self:ClearNodeHighlight(node_gui)
	disconnect_finished_input(self, input_box, config, node_gui, source, stored_value)

	self:NotifyFinish(config, node_gui, input_box, stored_value, source)

	if scroll_indicator_state then
		self:RestoreAndPreserveScrollIndicators(node_gui, scroll_indicator_state)
	end

	if not changed then
		clear_and_preserve(self, node_gui)
		return
	end

	refresh_value(self, config, node_gui, stored_value, source)
end

function InlineInput:ApplyValue(config, node_gui, value, source)
	if self:IsInputTarget(config) then
		local target = config
		source = value
		value = node_gui
		config = target.config
		node_gui = target.node_gui
	end

	local input_box = self:GetInputBox(config.id, node_gui)
	local was_focused = input_box and input_box.input_focus and input_box:input_focus() == true
	local old_value = self:GetValue(config)

	if self:IsReadOnly(config) and (source == "change" or source == "repeat") then
		if input_box then
			self:SetBoxText(input_box, old_value)
		end

		clear_and_preserve(self, node_gui)
		return
	end

	value = self:NormalizeText(config, value)

	if input_box then
		self:SetBoxText(input_box, value)
	end

	if not self:ShouldApplyValue(config, source) then
		clear_and_preserve(self, node_gui)
		return
	end

	local valid, display_value, stored_value = self:ValidateValue(config, value, node_gui, source)

	if not valid then
		self:HandleInvalidValue(config, node_gui, input_box, value, old_value, source)
		return
	end

	if input_box then
		self:SetBoxText(input_box, display_value)
	end

	if display_value == old_value and source ~= "disconnect" then
		clear_and_preserve(self, node_gui)
		return
	end

	self:SetValue(config, stored_value, node_gui, source)

	if source == "disconnect" then
		self:LogDebugEvent(config, "disconnect", stored_value, node_gui, source)
		InlineInput:SafeCall(config.on_disconnect, stored_value, node_gui, source, config)
	else
		self:LogDebugEvent(config, "change", stored_value, node_gui, source)
		InlineInput:SafeCall(config.on_change, stored_value, node_gui, source, config)
	end

	if display_value == old_value then
		clear_and_preserve(self, node_gui)
		return
	end

	refresh_value(self, config, node_gui, stored_value, source, { refocus = was_focused, highlight = was_focused })
end

InlineInput.ClearMenuHighlight = InlineInput.ClearNodeHighlight
InlineInput.RefreshMenuConfig = InlineInput.RefreshConfig
InlineInput.HandleInvalidMenuValue = InlineInput.HandleInvalidValue
InlineInput.WithMutedMenuComponentEvents = InlineInput.WithMutedComponentEvents
InlineInput.Refresh = InlineInput.RefreshConfig

return InlineInput
