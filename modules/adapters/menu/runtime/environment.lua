local InlineInput = _G.InlineInput

function InlineInput:ActiveMenuNodeGui()
	local menu_manager = managers and managers.menu
	local active_menu = menu_manager and menu_manager.active_menu and menu_manager:active_menu()
	local renderer = active_menu and active_menu.renderer

	if renderer and renderer.active_node_gui then
		return renderer:active_node_gui()
	end

	return nil
end

InlineInput.ActiveNodeGui = InlineInput.ActiveMenuNodeGui

return InlineInput
