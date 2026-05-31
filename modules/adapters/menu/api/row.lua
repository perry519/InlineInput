local InlineInput = _G.InlineInput

function InlineInput.Handle:install_focus_callback()
	local callback_id = self.callback_id or self.callback or ("inline_input_focus_" .. tostring(self.id))

	if self.callback_id or self.callback then
		return callback_id
	end

	if MenuCallbackHandler then
		MenuCallbackHandler[callback_id] = function(_, item)
			return self:focus(item)
		end
	end

	return callback_id
end

function InlineInput.Handle:add_menu_item(menu_helper, overrides)
	menu_helper = menu_helper or MenuHelper
	overrides = overrides or {}

	if not menu_helper or not menu_helper.AddButton then
		return nil
	end

	local callback_id = self:install_focus_callback()
	local item = menu_helper:AddButton({
		id = overrides.item_id or self.item_id or self.id,
		title = overrides.title or self.title or " ",
		desc = overrides.desc or overrides.description or self.desc or self.description,
		callback = overrides.callback_id or overrides.callback or callback_id,
		menu_id = overrides.menu_id or self.menu_id,
		priority = overrides.priority or self.priority,
		localized = overrides.localized ~= nil and overrides.localized or self.localized == true
	})

	local visible_callback_name = overrides.visible_callback_name or self.visible_callback_name

	if item and visible_callback_name then
		item._visible_callback_name_list = { visible_callback_name }
	end

	return item
end

return InlineInput
