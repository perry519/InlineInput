local InlineInput = _G.InlineInput

InlineInput.DEFAULTS.escape_menu_back_block_consumes = InlineInput.DEFAULTS.escape_menu_back_block_consumes or 6
InlineInput.DEFAULTS.menu_input_block_timeout_seconds = InlineInput.DEFAULTS.menu_input_block_timeout_seconds or 0.12
InlineInput.DEFAULTS.escape_input_back_block_consumes = InlineInput.DEFAULTS.escape_input_back_block_consumes
	or InlineInput.DEFAULTS.escape_menu_back_block_consumes
InlineInput.DEFAULTS.input_block_timeout_seconds = InlineInput.DEFAULTS.input_block_timeout_seconds
	or InlineInput.DEFAULTS.menu_input_block_timeout_seconds
InlineInput.DEFAULTS.input_double_click_seconds = InlineInput.DEFAULTS.input_double_click_seconds or 0.30
InlineInput.DEFAULTS.show_brackets = InlineInput.DEFAULTS.show_brackets ~= false

return InlineInput.DEFAULTS
