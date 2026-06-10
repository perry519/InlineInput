_G.InlineInput = _G.InlineInput or {}

local InlineInput = _G.InlineInput

local function script_dir()
	local source = debug and debug.getinfo and debug.getinfo(1, "S").source or nil

	if type(source) ~= "string" then
		return nil
	end

	if string.sub(source, 1, 1) == "@" then
		source = string.sub(source, 2)
	end

	return string.match(source, "^(.*[/\\])[^/\\]+$")
end

InlineInput.MOD_PATH = script_dir() or InlineInput.MOD_PATH or ModPath or "InlineInput/"

local modules = {
	"modules/core/base.lua",
	"modules/shared/logger.lua",
	"modules/core/defaults.lua",
	"modules/adapters/shared/config/defaults.lua",
	"modules/adapters/shared/control.lua",
	"modules/adapters/shared/mouse.lua",
	"modules/adapters/shared/input_box_chrome.lua",
	"modules/adapters/shared/runtime/input_box_environment.lua",
	"modules/adapters/menu/runtime/environment.lua",
	"modules/adapters/shared/model/node.lua",
	"modules/adapters/shared/model/synthetic_node.lua",
	"modules/adapters/shared/host_attach.lua",
	"modules/core/field_config.lua",
	"modules/input/utf8_text.lua",
	"modules/input/text_range.lua",
	"modules/input/keys.lua",
	"modules/input/caret.lua",
	"modules/input/target.lua",
	"modules/adapters/shared/input/target.lua",
	"modules/adapters/shared/input/caret.lua",
	"modules/input/editing.lua",
	"modules/input/session.lua",
	"modules/input/commands.lua",
	"modules/adapters/shared/input/block.lua",
	"modules/adapters/shared/view/scroll_indicators.lua",
	"modules/adapters/shared/input/controller.lua",
	"modules/adapters/shared/input/repeat.lua",
	"modules/adapters/shared/input/key_patch.lua",
	"modules/adapters/shared/view/style.lua",
	"modules/adapters/shared/view/chrome.lua",
	"modules/adapters/shared/view/selection.lua",
	"modules/adapters/shared/view/renderer.lua",
	"modules/adapters/shared/node_lifecycle.lua",
	"modules/adapters/shared/lifecycle/focus.lua",
	"modules/adapters/shared/input_mouse.lua",
	"modules/api/handle.lua",
	"modules/adapters/shared/api/handle.lua",
	"modules/adapters/shared/api/registration.lua",
	"modules/adapters/menu/lifecycle/hooks.lua",
	"modules/adapters/menu/api/row.lua"
}

for _, module_path in ipairs(modules) do
	dofile(InlineInput.MOD_PATH .. module_path)
end

if InlineInput.InstallHooks then
	InlineInput:InstallHooks()
end

return InlineInput
