# InlineInput

InlineInput is a reusable PAYDAY 2 BLT helper for text inputs inside mod option menus.

It renders a text field over a BLT menu row and handles focus, typing, caret movement, selection, clipboard shortcuts, Backspace/Delete, Enter, Esc, validation, refreshes, and lifecycle callbacks. Use it when a mod needs a search box, name field, numeric entry, or any other inline text value.

## Requirements

- PAYDAY 2 with BLT or SuperBLT.

## Quick Start

Load the library, register an input, then add a menu row for it:

```lua
local ok, InlineInput = pcall(dofile, ModPath .. "../InlineInput/require.lua")
if not ok or not InlineInput then
	log("[MyMod] InlineInput is not installed")
	return
end

MyMod.search_text = MyMod.search_text or ""

local search_input = InlineInput:RegisterInput({
	id = "my_mod:options_search",
	menu_id = "my_mod_options",
	item_id = "my_mod_options_search",
	placeholder = "SEARCH",
	max_length = 64,

	get_value = function()
		return MyMod.search_text
	end,

	set_value = function(value, node_gui, source)
		MyMod.search_text = value
		MyMod:ApplyOptionsFilter(value)
	end,

	on_submit = function(value)
		MyMod:SaveSettings()
	end,

	on_cancel = function()
		MyMod.search_text = ""
		MyMod:ApplyOptionsFilter("")
	end
})

search_input:add_menu_item(MenuHelper, {
	priority = 1000
})
```

## How It Works

Each registration describes one input field. InlineInput finds the matching menu row, creates a `SearchBoxGuiObject` over that row, and keeps it synced while the menu is visible.

The usual flow is:

1. Register once with a globally unique `id`.
2. Scope the input to a menu with `menu_id`.
3. Add a row with `handle:add_menu_item(...)`, or create your own BLT row whose `id` matches the input `item_id`.
4. Store the value through `get_value` and `set_value`.
5. Use lifecycle callbacks for filtering, saving, cancelling, and cleanup.

Prefer ids prefixed by your mod id, for example `my_mod:search`. This prevents collisions when several mods use InlineInput.

## Registering An Existing Row

Use this when the menu button row already exists, or when your mod needs to create the row itself. InlineInput binds the input to that BLT row by matching the input `item_id` to the row `id`. Your mod still owns creating the row and wiring its callback; InlineInput owns rendering and editing the text field on that row.

The callback should call `handle:focus(item, "mouse")` so clicking or selecting the row enters text-edit mode:

```lua
local name_input = InlineInput:RegisterInput({
	id = "my_mod:profile_name",
	menu_id = "my_mod_options",
	item_id = "my_mod_profile_name",
	placeholder = "PROFILE NAME",
	get_value = function()
		return MyMod.profile_name or ""
	end,
	set_value = function(value)
		MyMod.profile_name = value
	end
})

MenuHelper:AddButton({
	id = "my_mod_profile_name",
	title = " ",
	callback = "my_mod_profile_name_focus",
	menu_id = "my_mod_options",
	localized = false
})

MenuCallbackHandler.my_mod_profile_name_focus = function(_, item)
	return name_input:focus(item, "mouse")
end
```

If you do not need custom row creation, prefer `handle:add_menu_item(...)`; it creates the BLT button row and installs the focus callback for you.

## Attaching To A Custom Host

For dialogs or custom panels owned by another mod, create the host UI yourself and pass concrete row panels to `AttachHostInputs`.

```lua
local attachment = InlineInput:AttachHostInputs({
	adapter_id = "my_dialog",
	node_id = "my_dialog_id",
	owner = dialog_gui,
	ws = ws,
	item_panel = canvas_panel,
	row_items = {
		{ config = input_a, gui_panel = row_panel_a },
		{ config = input_b, gui_panel = row_panel_b }
	},
	focus_id = "input_b",
	focus_on_attach = true,
	refresh = function(node_gui, owner)
		owner:refresh_items()
	end
})
```

`config` can be a `RegisterInput` handle or a raw config table. Raw configs are registered automatically. Every row item must provide `gui_panel`, and `node_id` is required.

Forward host events to the attachment:

```lua
function MyDialogGui:mouse_pressed(button, x, y)
	return self._inline_inputs and self._inline_inputs:mouse_pressed(button, x, y)
end

function MyDialogGui:update(t, dt)
	if self._inline_inputs then
		self._inline_inputs:update(dt)
	end
end

function MyDialogGui:close()
	if self._inline_inputs then
		self._inline_inputs:destroy("dialog_close")
	end
end
```

Useful attachment methods are `sync`, `focus(id, source)`, `blur(id, source)`, `input_box(id)`, `input_focus`, `finish_focused(source)`, `mouse_pressed`, `mouse_moved`, `mouse_released`, `update(dt)`, and `destroy(source)`.

Stock `QuickMenu` and `managers.system_menu:show(...)` dialogs do not expose a stable pre-creation API for injecting custom input panels. If you need native dialog styling, own the dialog class or panel script in your mod, create the row panels there, then attach InlineInput.

## Configuration Reference

Pass these fields to `InlineInput:RegisterInput(config)`. Color fields may be color values or functions that return a color.

| Field                                                    | Purpose                                                                                                                          |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `id`                                                     | Globally unique registration id. Also used as `item_id` when `item_id` is omitted.                                               |
| `menu_id`                                                | BLT menu node id. Strongly recommended so the input only attaches inside that menu.                                              |
| `item_id`                                                | Row id to attach to. Defaults to `id`.                                                                                           |
| `title`                                                  | Row title used by `handle:add_menu_item`. Use `" "` for a pure input row.                                                        |
| `desc` / `description`                                   | Row description used by `handle:add_menu_item`.                                                                                  |
| `priority`                                               | MenuHelper row priority used by `handle:add_menu_item`.                                                                          |
| `localized`                                              | Passed to MenuHelper when adding the row.                                                                                        |
| `visible_callback_name`                                  | Optional BLT visibility callback name for the generated row.                                                                     |
| `callback_id` / `callback`                               | Optional existing MenuCallbackHandler callback. If omitted, InlineInput creates one.                                             |
| `input_width_scale` / `width_scale`                      | Optional multiplier for the rendered input panel width, for example `0.5` for half width.                                        |
| `input_width` / `field_width`                            | Optional maximum rendered input panel width in pixels.                                                                           |
| `placeholder` / `placeholder_text`                       | Placeholder shown while the value is empty. May be a string or function.                                                         |
| `value`                                                  | Simple stored value when `get_value` and `set_value` are not provided.                                                           |
| `get_value(config)`                                      | Returns the current value. Return `nil` to fall back to `config.value`.                                                          |
| `set_value(value, node_gui, source, config)`             | Stores an accepted value.                                                                                                        |
| `max_length` / `max_input_length`                        | Maximum text length.                                                                                                             |
| `value_type = "number"`                                  | Parses and validates the value as a number.                                                                                      |
| `numeric = true`                                         | Alias for `value_type = "number"`.                                                                                               |
| `min_value` / `max_value`                                | Numeric bounds when numeric parsing is enabled.                                                                                  |
| `validate(value, node_gui, source, config)`              | Custom validation and conversion hook.                                                                                           |
| `commit_only = true`                                     | Do not call `set_value` on each typed change; only apply on finish.                                                              |
| `apply_mode = "commit"`                                  | Same behavior as `commit_only = true`. `"submit"` is also treated as commit-only for live edits.                                 |
| `refresh`                                                | `false` disables refresh, a function overrides refresh, otherwise InlineInput refreshes the active node after committed changes. |
| `show_brackets = false`                                  | Hides the native SearchBoxGuiObject border brackets. `hide_brackets = true` and `remove_brackets = true` are aliases.            |
| `background_color` / `input_background_color`            | Native input background color.                                                                                                   |
| `placeholder_color`                                      | Placeholder color for inactive/passive empty text.                                                                               |
| `active_placeholder_color` / `focused_placeholder_color` | Placeholder color while the input is focused. Falls back to `placeholder_color`.                                                 |
| `text_color` / `input_text_color`                        | Active and inactive value text color. Also used by the focused caret.                                                            |
| `selected_text_color` / `selection_color`                | Text color used by the native selected-text rendering.                                                                           |
| `selection_background_color` / `selection_bg_color`      | Selection highlight background color. `selected_text_highlight_bg_color` is also accepted.                                       |
| `not_editable` / `read_only` / `readonly`                | Prevents text changes while preserving focus, caret movement, selection, and copy.                                               |
| `clear_on_escape = false`                                | Makes Esc blur without clearing.                                                                                                 |
| `escape_behavior` / `esc_behavior`                       | Esc behavior: `"clear"`, `"revert"`, or blur-style values `"blur"`, `"keep"`, `"preserve"`, `"none"`.                            |
| `allow_escape_propagation = true`                        | Allows Esc to continue to the menu after InlineInput handles it. Defaults to false.                                              |
| `debug_events = true`                                    | Writes lifecycle event lines to Console when the Console mod is installed.                                                       |

## Editing Shortcuts

InlineInput supports the usual single-line editing shortcuts while the row has focus:

| Input                            | Behavior                                                              |
| -------------------------------- | --------------------------------------------------------------------- |
| `Enter`                          | Submit and blur.                                                      |
| `Esc`                            | Cancel/blur according to `escape_behavior`.                           |
| `Left` / `Right`                 | Move the caret by one character.                                      |
| `Shift+Left` / `Shift+Right`     | Extend the selection by one character.                                |
| `Ctrl+Left` / `Ctrl+Right`       | Move the caret by one word.                                           |
| `Home` / `Page Up`               | Move the caret to the start.                                          |
| `End` / `Page Down`              | Move the caret to the end.                                            |
| `Ctrl+A`                         | Select all text.                                                      |
| `Ctrl+C`                         | Copy the selection, or all text when nothing is selected.             |
| `Ctrl+X`                         | Cut the selected text.                                                |
| `Ctrl+V`                         | Paste clipboard text at the caret or over the selection.              |
| `Backspace` / `Delete`           | Remove the character before/after the caret, or remove the selection. |
| `Ctrl+Backspace` / `Ctrl+Delete` | Remove the previous/next word.                                        |

Up and Down remain menu navigation keys: pressing either finishes the current input with source `"navigation"` and lets the menu move focus.

## Validation

Return `false` or `nil` from `validate` to reject the value and restore the previous visible text.

Return `true` to accept the text as-is:

```lua
validate = function(value)
	return string.len(value) >= 3
end
```

Return `true, stored_value, display_value` to store one value and show another:

```lua
validate = function(value)
	local number = tonumber(value)
	if not number then
		return false
	end

	number = math.floor(number)
	return true, number, tostring(number)
end
```

For simple numeric fields, prefer the built-in parser:

```lua
InlineInput:RegisterInput({
	id = "my_mod:spawn_limit",
	menu_id = "my_mod_options",
	placeholder = "SPAWN LIMIT",
	value_type = "number",
	min_value = 0,
	max_value = 999,
	get_value = function()
		return MyMod.spawn_limit or 0
	end,
	set_value = function(value)
		MyMod.spawn_limit = tonumber(value) or 0
	end
})
```

## Callbacks

All callbacks are optional. InlineInput calls them with `pcall`, so callback errors are logged instead of breaking the menu.

| Callback        | Signature                                      | When it runs                                                                |
| --------------- | ---------------------------------------------- | --------------------------------------------------------------------------- |
| `on_focus`      | `(value, node_gui, source, config, input_box)` | Once when the input gains focus.                                            |
| `on_blur`       | `(value, node_gui, source, config, input_box)` | Once when the focused input loses focus.                                    |
| `on_finish`     | `(value, node_gui, source, config, input_box)` | After a valid finish path such as Enter, Esc, outside click, or navigation. |
| `on_change`     | `(value, node_gui, source, config)`            | After an accepted live value change. Not called again for the same value.   |
| `on_submit`     | `(value, node_gui, source, config)`            | After Enter accepts and stores the value.                                   |
| `on_cancel`     | `(value, node_gui, source, config)`            | After Esc applies its configured behavior and stores the resulting value.   |
| `on_disconnect` | `(value, node_gui, source, config)`            | When the underlying input box disconnects and applies its current value.    |
| `on_invalid`    | `(value, node_gui, source, config)`            | When validation rejects a value.                                            |

Common `source` values are `"change"`, `"repeat"`, `"enter"`, `"esc"`, `"disconnect"`, `"outside_click"`, `"navigation"`, `"focus"`, and `"blur"`.

Use `on_submit` when you specifically care about Enter. Use `on_finish` when you need cleanup after any completed input session.

## Handle Methods

`RegisterInput` returns the registration table with helper methods:

| Method                                        | Purpose                                                   |
| --------------------------------------------- | --------------------------------------------------------- |
| `handle:add_menu_item(MenuHelper, overrides)` | Adds a blank button row wired to focus the input.         |
| `handle:focus(target, source)`                | Focuses the input for the active row or node.             |
| `handle:blur(target, source)`                 | Blurs the input.                                          |
| `handle:set_focus(target, focused, source)`   | Shared focus/blur helper.                                 |
| `handle:sync(node_gui)`                       | Ensures the input box exists and is synced for a node.    |
| `handle:input_box(node_gui)`                  | Returns the active input box for that node.               |
| `handle:input_focus(node_gui)`                | Returns true when that input box has focus.               |
| `handle:install_hooks()`                      | Installs InlineInput hooks if they are not installed yet. |
| `handle:available()`                          | Returns true while the registration is still active.      |
| `handle:unregister()`                         | Removes the registration.                                 |

`handle:box(node_gui)` is an alias for `handle:input_box(node_gui)`, and `handle:open(target, source)` is an alias for `handle:focus(target, source)`.

## Debugging Events

Set `debug_events = true` on a registration to print event traces to the Console mod:

```lua
InlineInput:RegisterInput({
	id = "my_mod:debug_search",
	menu_id = "my_mod_options",
	placeholder = "DEBUG SEARCH",
	debug_events = true,
	get_value = function()
		return MyMod.debug_search or ""
	end,
	set_value = function(value)
		MyMod.debug_search = value
	end
})
```

Example Console output:

```text
[InlineInput] event=focus id=my_mod:debug_search source=mouse value="" node=my_mod_options
[InlineInput] event=change id=my_mod:debug_search source=change value="abc" node=my_mod_options
[InlineInput] event=submit id=my_mod:debug_search source=enter value="abc" node=my_mod_options
[InlineInput] event=blur id=my_mod:debug_search source=enter value="abc" node=my_mod_options
[InlineInput] event=finish id=my_mod:debug_search source=enter value="abc" node=my_mod_options
```

If Console is not installed, debug event logging is a no-op. The input still works.

## Reuse Rules

- Register each input once during menu setup.
- Use a globally unique `id`.
- Use `menu_id` unless the row id is guaranteed to be unique across all menus.
- Keep `get_value` and `set_value` small. Do expensive filtering or saving in callbacks where possible.
- Use `commit_only = true` for values that should not update while the user is typing.
