local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter

local call_original = Adapter.call_original
local menu_input_mouse_position = Adapter.menu_input_mouse_position
local is_primary_mouse_button = Adapter.primary_button

local function install_method_hook(target, flag, method, wrapper)
	if target[flag] then
		return false
	end

	target[flag] = true
	local original = target[method]
	target[method] = wrapper(original)

	return true
end

function InlineInput:MenuNodeGuiUsable(node_gui)
	if not node_gui then
		return false
	end

	if node_gui.item_panel ~= nil and not self:IsAlive(node_gui.item_panel) then
		return false
	end

	return true
end

local function sync_after(original)
	return function(node_gui, ...)
		if not InlineInput:MenuNodeGuiUsable(node_gui) then
			return nil
		end

		local result = call_original(original, node_gui, ...)

		if InlineInput:MenuNodeGuiUsable(node_gui) then
			InlineInput:SyncNode(node_gui)
		end

		return result
	end
end

function InlineInput:MenuInputMousePressed(menu_input, ...)
	local args = { ... }
	local button = args[1]
	local x = args[2]
	local y = args[3]

	if #args >= 4 then
		button = args[2]
		x = args[3]
		y = args[4]
	end

	x, y = menu_input_mouse_position(menu_input, x, y)

	local node_gui = self:ActiveMenuNodeGui()

	if not node_gui then
		return false
	end

	return self:MousePressed(node_gui, button, x, y)
end

function InlineInput:MenuInputMouseMoved(menu_input, ...)
	local node_gui = self:ActiveMenuNodeGui()

	if not node_gui or not self:NodeMouseSelectionActive(node_gui) then
		return false
	end

	local args = { ... }
	local button = "0"
	local x = args[1]
	local y = args[2]

	if #args >= 3 then
		x = args[2]
		y = args[3]
	end

	x, y = menu_input_mouse_position(menu_input, x, y)

	return self:MouseMoved(node_gui, button, x, y)
end

function InlineInput:MenuInputMouseReleased(menu_input, ...)
	local node_gui = self:ActiveMenuNodeGui()

	if not node_gui or not self:NodeMouseSelectionActive(node_gui) then
		return false
	end

	local args = { ... }
	local button = args[1]

	if #args >= 4 then
		button = args[2]
	end

	if not is_primary_mouse_button(button) then
		return false
	end

	return self:ClearNodeMouseSelection(node_gui)
end

function InlineInput:MenuInputBack(menu_input, ...)
	if self:ConsumeInputBlock() then
		return true
	end

	local node_gui = self:ActiveMenuNodeGui()
	local config, input_box = self:FocusedInputBox(node_gui)

	if config and input_box then
		self:FinishInput(config, node_gui, input_box, "esc")

		if self:ShouldPropagateEscape(config) and input_box:input_focus() == false then
			return false
		end

		self:ClearInputBlock()
		return true
	end

	return false
end

function InlineInput:MenuInputUpdate(menu_input, ...)
	local node_gui = self:ActiveMenuNodeGui()

	if not node_gui then
		return false
	end

	local args = { ... }
	local activated = self:ActivateSelectedInputFromKeyboard(node_gui)

	self:UpdateNodeBackspaceRepeat(node_gui, args[2])
	self:UpdateNodeCaretMoveRepeat(node_gui, args[2])

	return activated
end

function InlineInput:MenuNodeKeyPress(node_gui, o, key, ...)
	return self:ActivateSelectedInputTextKey(node_gui, key)
end

function InlineInput:MenuComponentInputFocus(menu_component, ...)
	if self:InputBlockActive() then
		return 1
	end

	local config, input_box = self:FocusedInputBox(self:ActiveMenuNodeGui())

	if config and input_box then
		return 1
	end

	return false
end

function InlineInput:InstallMenuComponentHooks()
	if not MenuComponentManager then
		self:LogOnce("menu_component_manager_missing", "MenuComponentManager is not available yet")
		return false
	end

	if
		MenuComponentManager._inline_input_input_focus_hook
		and MenuComponentManager._inline_input_input_focus_hook == MenuComponentManager.input_focus
	then
		return true
	end

	if
		not MenuComponentManager._inline_input_input_focus_hook
		or MenuComponentManager._inline_input_input_focus_hook ~= MenuComponentManager.input_focus
	then
		local original_input_focus = MenuComponentManager.input_focus
		local function inline_input_component_input_focus(self, ...)
			local focus = InlineInput:MenuComponentInputFocus(self, ...)

			if focus then
				return focus
			end

			return call_original(original_input_focus, self, ...)
		end

		MenuComponentManager._inline_input_input_focus_hook = inline_input_component_input_focus
		MenuComponentManager.input_focus = inline_input_component_input_focus
	end

	self:LogOnce("menu_component_manager_hooks_installed", "installed MenuComponentManager hooks")
	return true
end

function InlineInput:InstallMenuInputHooks()
	if not MenuInput then
		self:LogOnce("menu_input_missing", "MenuInput is not available yet")
		self._menu_input_hooks_installed = false
		return false
	end

	self._menu_input_hooks_installed = true

	install_method_hook(MenuInput, "_inline_input_input_hooks_installed", "_input_hijacked", function(original)
		return function(menu_input, ...)
			if InlineInput:ConsumeInputBlock() then
				return true
			end

			return call_original(original, menu_input, ...)
		end
	end)

	install_method_hook(MenuInput, "_inline_input_mouse_pressed_hook_installed", "mouse_pressed", function(original)
		return function(menu_input, ...)
			if InlineInput:MenuInputMousePressed(menu_input, ...) then
				return true
			end

			return call_original(original, menu_input, ...)
		end
	end)

	install_method_hook(MenuInput, "_inline_input_mouse_moved_hook_installed", "mouse_moved", function(original)
		return function(menu_input, ...)
			local used, pointer = InlineInput:MenuInputMouseMoved(menu_input, ...)

			if used then
				return true, pointer or "link"
			end

			if original then
				return original(menu_input, ...)
			end

			return false, "arrow"
		end
	end)

	install_method_hook(MenuInput, "_inline_input_mouse_released_hook_installed", "mouse_released", function(original)
		return function(menu_input, ...)
			if InlineInput:MenuInputMouseReleased(menu_input, ...) then
				return true
			end

			return call_original(original, menu_input, ...)
		end
	end)

	install_method_hook(MenuInput, "_inline_input_back_hook_installed", "back", function(original)
		return function(menu_input, ...)
			if InlineInput:MenuInputBack(menu_input, ...) then
				return
			end

			return call_original(original, menu_input, ...)
		end
	end)

	install_method_hook(MenuInput, "_inline_input_update_hook_installed", "update", function(original)
		return function(menu_input, ...)
			local result = call_original(original, menu_input, ...)
			InlineInput:MenuInputUpdate(menu_input, ...)

			return result
		end
	end)

	self:LogOnce("menu_input_hooks_installed", "installed MenuInput hooks")
	return true
end

function InlineInput:InstallMenuNodeKeyHooks()
	if not MenuNodeGui or MenuNodeGui._inline_input_key_hooks_installed then
		return
	end

	MenuNodeGui._inline_input_key_hooks_installed = true

	for _, method in ipairs({ "key_press", "_key_press" }) do
		local original = MenuNodeGui[method]
		MenuNodeGui[method] = function(node_gui, o, key, ...)
			if InlineInput:MenuNodeKeyPress(node_gui, o, key, ...) then
				return true
			end

			return call_original(original, node_gui, o, key, ...)
		end
	end
end

function InlineInput:InstallHooks()
	self:InstallMenuComponentHooks()
	self:InstallMenuInputHooks()

	if not MenuNodeGui then
		self:LogOnce("menu_node_gui_missing", "MenuNodeGui is not available yet")
		self._hooks_installed = false
		return false
	end

	if MenuNodeGui._inline_input_hooks_installed then
		self:InstallMenuNodeKeyHooks()
		self._hooks_installed = true
		return true
	end

	self._hooks_installed = true
	MenuNodeGui._inline_input_hooks_installed = true

	for _, method in ipairs({ "refresh_gui", "_setup_item_rows", "resolution_changed" }) do
		MenuNodeGui[method] = sync_after(MenuNodeGui[method])
	end

	local original_update = MenuNodeGui.update
	function MenuNodeGui:update(t, dt, ...)
		local result

		if original_update then
			result = original_update(self, t, dt, ...)
		elseif MenuNodeGui.super and MenuNodeGui.super.update then
			result = MenuNodeGui.super.update(self, t, dt, ...)
		end

		if InlineInput:MenuNodeGuiUsable(self) then
			InlineInput:SyncNode(self)
			InlineInput:RestorePreservedScrollIndicators(self)
			InlineInput:UpdateNodeCaretBlinks(self, dt)
		end

		return result
	end

	local original_close = MenuNodeGui.close
	function MenuNodeGui:close(...)
		InlineInput:DestroyNode(self)
		return call_original(original_close, self, ...)
	end

	local original_mouse_pressed = MenuNodeGui.mouse_pressed
	function MenuNodeGui:mouse_pressed(button, x, y)
		if InlineInput:MousePressed(self, button, x, y) then
			return true
		end

		return call_original(original_mouse_pressed, self, button, x, y)
	end

	local original_mouse_moved = MenuNodeGui.mouse_moved
	function MenuNodeGui:mouse_moved(button, x, y)
		local used, pointer = InlineInput:MouseMoved(self, button, x, y)

		if used then
			return used, pointer
		end

		if original_mouse_moved then
			return original_mouse_moved(self, button, x, y)
		end

		return false, pointer
	end

	self:InstallMenuNodeKeyHooks()

	local original_input_focus = MenuNodeGui.input_focus
	function MenuNodeGui:input_focus(...)
		if InlineInput:InputFocus(self) then
			return true
		end

		return call_original(original_input_focus, self, ...)
	end

	self:LogOnce("menu_node_gui_hooks_installed", "installed MenuNodeGui hooks")
	return true
end

return InlineInput
