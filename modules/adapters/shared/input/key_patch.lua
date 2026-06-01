local InlineInput = _G.InlineInput

local KEY_PATCH_VERSION = 10

function InlineInput:IsMenuNavigationKey(key)
	return self:IsUpKey(key) or self:IsDownKey(key)
end

function InlineInput:PatchInputBoxKeys(input_box, config, node_gui)
	if not input_box then
		return
	end

	if input_box._inline_input_keys_patch_version == KEY_PATCH_VERSION then
		return
	end

	local original_search_key_press = input_box._inline_input_original_search_key_press or input_box.search_key_press
	local original_update_key_down = input_box._inline_input_original_update_key_down or input_box.update_key_down
	input_box._inline_input_original_search_key_press = original_search_key_press
	input_box._inline_input_original_update_key_down = original_update_key_down
	input_box._inline_input_keys_patched = true
	input_box._inline_input_keys_patch_version = KEY_PATCH_VERSION

	function input_box:search_key_press(o, key)
		if not InlineInput:IsActiveInputBox(config, node_gui, self) then
			return false
		end

		local session = InlineInput:CreateInputSession(InlineInput:CreateInputBoxTarget(config, node_gui, self))

		if InlineInput:IsMenuNavigationKey(key) then
			InlineInput:FinishInput(config, node_gui, self, "navigation")
			return false
		elseif InlineInput:IsKey(key, "enter") then
			InlineInput:FinishInput(config, node_gui, self, "enter")
			return true
		elseif InlineInput:IsKey(key, "esc") then
			InlineInput:FinishInput(config, node_gui, self, "esc")
			return not InlineInput:ShouldPropagateEscape(config)
		elseif InlineInput:IsModifierKey(key) then
			return true
		elseif InlineInput:IsKey(key, "insert") then
			local result = session:paste()
			InlineInput:ResetCaretBlink(self)
			return result
		end

		local handled, result = InlineInput:ApplySharedInputCommand(session, self, key, {
			backspace_repeat = {
				config = config,
				node_gui = node_gui
			},
			after_mutation = function()
				InlineInput:PreserveScrollIndicatorsOnce(node_gui)
				InlineInput:BlockNextInput()
				InlineInput:ClearNodeHighlight(node_gui)
			end
		})

		if handled then
			InlineInput:ResetCaretBlink(self)
			return result
		end

		if InlineInput:IsLeftKey(key) then
			InlineInput:MoveCaret(self, -1, { extend_selection = InlineInput:IsShiftDown() })
			InlineInput:StartCaretMoveRepeat(config, node_gui, -1)
			InlineInput:ResetCaretBlink(self)
			return true
		elseif InlineInput:IsRightKey(key) then
			InlineInput:MoveCaret(self, 1, { extend_selection = InlineInput:IsShiftDown() })
			InlineInput:StartCaretMoveRepeat(config, node_gui, 1)
			InlineInput:ResetCaretBlink(self)
			return true
		end

		if original_search_key_press then
			local is_text_key = InlineInput:IsTextInputKey(key)
			local result = original_search_key_press(self, o, key)

			if is_text_key or result then
				InlineInput:ResetCaretBlink(self)
			end

			return result or is_text_key
		end
	end

	if original_update_key_down then
		function input_box:update_key_down(o, key)
			if not InlineInput:IsActiveInputBox(config, node_gui, self) then
				return false
			end

			local session = InlineInput:CreateInputSession(InlineInput:CreateInputBoxTarget(config, node_gui, self))

			if InlineInput:IsControlDown() and (InlineInput:IsKey(key, "a") or InlineInput:IsKey(key, "c") or InlineInput:IsKey(key, "x") or InlineInput:IsKey(key, "v")) then
				return true
			elseif InlineInput:IsModifierKey(key) then
				return true
			elseif InlineInput:IsKey(key, "insert") then
				return true
			elseif InlineInput:IsHomeKey(key) or InlineInput:IsPageUpKey(key) or InlineInput:IsEndKey(key) or InlineInput:IsPageDownKey(key) then
				return true
			elseif InlineInput:IsKey(key, "backspace") or InlineInput:IsDeleteKey(key) then
				InlineInput:ApplySharedInputCommand(session, self, key)
				InlineInput:ResetCaretBlink(self)
				return true
			elseif InlineInput:IsLeftKey(key) or InlineInput:IsRightKey(key) then
				return true
			end

			self._inline_input_in_key_repeat = true
			local result = original_update_key_down(self, o, key)
			self._inline_input_in_key_repeat = nil

			if result then
				InlineInput:ResetCaretBlink(self)
			end

			return result
		end
	end

	function input_box:enter_key_callback(...)
		if not InlineInput:IsActiveInputBox(config, node_gui, self) then
			return false
		end

		InlineInput:FinishInput(config, node_gui, self, "enter")
		return true
	end

	function input_box:esc_key_callback(...)
		if not InlineInput:IsActiveInputBox(config, node_gui, self) then
			return false
		end

		InlineInput:FinishInput(config, node_gui, self, "esc")
		return not InlineInput:ShouldPropagateEscape(config)
	end
end

function InlineInput:BindInputBoxCallbacks(config, node_gui, input_box)
	if not input_box then
		return
	end

	input_box._inline_input_config = config
	input_box._inline_input_node_gui = node_gui
	input_box._enter_callback = function()
		InlineInput:FinishInput(config, node_gui, input_box, "enter")
	end
	input_box._esc_callback = function()
		InlineInput:FinishInput(config, node_gui, input_box, "esc")
		return not InlineInput:ShouldPropagateEscape(config)
	end
end

return InlineInput
