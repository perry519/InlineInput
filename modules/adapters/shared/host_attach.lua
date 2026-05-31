local InlineInput = _G.InlineInput
local Adapter = InlineInput.Adapter

local normalize_mouse_args = Adapter.normalize_mouse_args
local primary_button = Adapter.primary_button

local Attachment = {}
Attachment.__index = Attachment

local function host_match_key(adapter_id, node_id)
	return tostring(adapter_id or "host") .. ":" .. tostring(node_id or "")
end

local function is_registered_config(library, config)
	return type(config) == "table"
		and config.id ~= nil
		and library._registrations
		and library._registrations[tostring(config.id)] == config
end

local function ensure_host_node_match(library, config, adapter_id, node_id)
	if type(config) ~= "table" then
		return
	end

	local key = host_match_key(adapter_id, node_id)
	config._inline_input_host_matches = config._inline_input_host_matches or {}
	config._inline_input_host_matches[key] = {
		adapter_id = adapter_id,
		node_id = node_id
	}

	if config._inline_input_host_node_match_installed then
		return
	end

	config._inline_input_host_original_node_match = rawget(config, "node_match")
	config._inline_input_host_original_node_match_set = true
	config._inline_input_host_node_match_installed = true

	config.node_match = function(node_gui, field_config)
		local matches = rawget(field_config, "_inline_input_host_matches")

		for _, match in pairs(matches or {}) do
			if library:SyntheticInputNodeMatches(node_gui, match.adapter_id, match.node_id) then
				return true
			end
		end

		local original = rawget(field_config, "_inline_input_host_original_node_match")

		if original then
			return library:SafeCall(original, node_gui, field_config)
		end

		return nil
	end
end

local function clear_host_node_match(config, adapter_id, node_id)
	if type(config) ~= "table" or not config._inline_input_host_matches then
		return
	end

	config._inline_input_host_matches[host_match_key(adapter_id, node_id)] = nil

	if next(config._inline_input_host_matches) ~= nil then
		return
	end

	config._inline_input_host_matches = nil

	if config._inline_input_host_original_node_match_set then
		config.node_match = config._inline_input_host_original_node_match
	else
		config.node_match = nil
	end

	config._inline_input_host_original_node_match = nil
	config._inline_input_host_original_node_match_set = nil
	config._inline_input_host_node_match_installed = nil
end

local function normalize_host_config(library, config, node_id)
	if type(config) ~= "table" then
		return nil
	end

	if not is_registered_config(library, config) then
		config.menu_id = config.menu_id or node_id
		config.item_id = config.item_id or config.id
		return library:RegisterInput(config)
	end

	config.item_id = config.item_id or config.id
	return config
end

local function attachment_config(attachment, id)
	if type(id) == "table" and attachment._config_set[id] then
		return id
	end

	if id == nil then
		local config = attachment._library and attachment._library.FocusedInputBox
			and attachment._library:FocusedInputBox(attachment.node_gui)
		if config and attachment._config_set[config] then
			return config
		end

		return nil
	end

	local key = tostring(id)
	return attachment._configs_by_id[key] or attachment._configs_by_item_id[key]
end

local function focus_config_for_options(attachment, options)
	if options.focus_id ~= nil then
		return attachment_config(attachment, options.focus_id)
	end

	if options.focus_index ~= nil then
		local index = tonumber(options.focus_index)
		if index then
			return attachment.configs[math.floor(index)]
		end
	end

	return attachment.configs[1]
end

function Attachment:sync()
	if self._destroyed or not self.node_gui then
		return nil
	end

	local first_input_box = nil

	for _, config in ipairs(self.configs or {}) do
		local input_box = self._library:SyncConfig(config, self.node_gui)

		if not first_input_box then
			first_input_box = input_box
		end
	end

	return first_input_box
end

function Attachment:focus(id, source)
	local config = attachment_config(self, id)

	if not config or self._destroyed then
		return false
	end

	return self._library:SetFocus(config.id, self.node_gui, true, source or "host")
end

function Attachment:blur(id, source)
	local config = attachment_config(self, id)

	if not config or self._destroyed then
		return false
	end

	return self._library:SetFocus(config.id, self.node_gui, false, source or "host_blur")
end

function Attachment:input_box(id)
	local config = attachment_config(self, id)

	if not config or self._destroyed then
		return nil
	end

	return self._library:GetInputBox(config.id, self.node_gui)
end

function Attachment:input_focus()
	if self._destroyed then
		return false
	end

	return self._library:InputFocus(self.node_gui)
end

function Attachment:finish_focused(source)
	if self._destroyed then
		return false
	end

	local config, input_box = self._library:FocusedInputBox(self.node_gui)

	if not config or not input_box or not self._config_set[config] then
		return false
	end

	self._library:FinishInput(config, self.node_gui, input_box, source or "host")
	return true
end

function Attachment:release_after_submit(source)
	if self._destroyed then
		return false
	end

	local released = self:finish_focused(source or "host_submit")

	if self._library.ClearInputBlock then
		self._library:ClearInputBlock()
		released = true
	end

	return released
end

function Attachment:mouse_pressed(button, x, y)
	if self._destroyed then
		return false
	end

	button, x, y = normalize_mouse_args(button, x, y)
	return self._library:MousePressed(self.node_gui, button, x, y)
end

function Attachment:mouse_moved(button, x, y)
	if self._destroyed then
		return false, "arrow"
	end

	button, x, y = normalize_mouse_args(button, x, y)
	return self._library:MouseMoved(self.node_gui, button, x, y)
end

function Attachment:mouse_released(button, x, y)
	if self._destroyed then
		return false
	end

	button = normalize_mouse_args(button, x, y)

	if not primary_button(button) then
		return false
	end

	return self._library:ClearNodeMouseSelection(self.node_gui)
end

function Attachment:update(dt)
	if self._destroyed then
		return nil
	end

	local input_box = self:sync()

	if self._library.RestorePreservedScrollIndicators then
		self._library:RestorePreservedScrollIndicators(self.node_gui)
	end

	if self._library.UpdateNodeBackspaceRepeat then
		self._library:UpdateNodeBackspaceRepeat(self.node_gui, dt)
	end

	if self._library.UpdateNodeCaretMoveRepeat then
		self._library:UpdateNodeCaretMoveRepeat(self.node_gui, dt)
	end

	if self._library.UpdateNodeCaretBlinks then
		self._library:UpdateNodeCaretBlinks(self.node_gui, dt)
	end

	return input_box
end

function Attachment:destroy(source)
	if self._destroyed then
		return true
	end

	source = source or "host_destroy"
	self:finish_focused(source)

	if self.node_gui then
		self._library:ClearNodeMouseSelection(self.node_gui)
		self._library:DestroyNode(self.node_gui)

		self.node_gui[self._library._node_box_key] = nil
		self.node_gui.row_items = {}
		self.node_gui.configs = nil
		self.node_gui._inline_input_config_ids = nil
		self.node_gui.item_panel = nil
		self.node_gui.ws = nil
		self.node_gui.node = nil
		self.node_gui._inline_input_synthetic_node = nil
		self.node_gui._inline_input_synthetic_adapter = nil
		self.node_gui._inline_input_synthetic_id = nil
		self.node_gui._inline_input_synthetic_owner = nil
		self.node_gui["_inline_input_" .. tostring(self.adapter_id) .. "_node"] = nil
		self.node_gui["_inline_input_" .. tostring(self.adapter_id) .. "_id"] = nil
		self.node_gui["_inline_input_" .. tostring(self.adapter_id) .. "_gui"] = nil
	end

	for _, config in ipairs(self.configs or {}) do
		clear_host_node_match(config, self.adapter_id, self.node_id)
	end

	self._destroyed = true
	return true
end

function InlineInput:AttachHostInputs(options)
	options = options or {}

	local node_id = options.node_id
	if node_id == nil or tostring(node_id) == "" then
		self:LogOnce("host_attach_missing_node_id", "host input attach skipped: node_id is required")
		return nil
	end

	local source_rows = options.row_items or options.rows
	if type(source_rows) ~= "table" or #source_rows == 0 then
		self:LogOnce("host_attach_missing_rows", "host input attach skipped: row_items are required")
		return nil
	end

	local adapter_id = options.adapter_id or "host"
	local configs = {}
	local config_ids = {}
	local rows = {}

	for index, row in ipairs(source_rows) do
		if type(row) ~= "table" or not row.gui_panel then
			self:LogOnce("host_attach_missing_row_panel_" .. tostring(node_id), "host input attach skipped: every row item needs gui_panel")
			return nil
		end

		if type(row.config) ~= "table" then
			self:LogOnce("host_attach_missing_config_" .. tostring(node_id), "host input attach skipped: every row item needs config")
			return nil
		end
	end

	for index, row in ipairs(source_rows) do
		local config = normalize_host_config(self, row.config, node_id)

		if not config then
			self:LogOnce("host_attach_missing_config_" .. tostring(node_id), "host input attach skipped: every row item needs config")
			return nil
		end

		ensure_host_node_match(self, config, adapter_id, node_id)

		configs[index] = config
		config_ids[index] = config.id
		rows[index] = {
			config = config,
			item = row.item,
			item_id = row.item_id or row.id or config.item_id or config.id,
			gui_panel = row.gui_panel
		}
	end

	local node_gui = self:CreateSyntheticInputNode({
		adapter_id = adapter_id,
		node_id = node_id,
		owner = options.owner,
		ws = options.ws,
		item_panel = options.item_panel,
		row_items = rows,
		configs = configs,
		config_ids = config_ids,
		refresh = options.refresh,
		highlight_item = options.highlight_item
	})

	local attachment = setmetatable({
		_library = self,
		_destroyed = false,
		_configs_by_id = {},
		_configs_by_item_id = {},
		_config_set = {},
		adapter_id = adapter_id,
		node_id = node_id,
		node_gui = node_gui,
		configs = configs
	}, Attachment)

	for _, config in ipairs(configs) do
		attachment._config_set[config] = true
		attachment._configs_by_id[tostring(config.id)] = config
		attachment._configs_by_item_id[tostring(config.item_id or config.id)] = config
	end

	attachment:sync()

	if options.focus_on_attach ~= false then
		local focus_config = focus_config_for_options(attachment, options)
		if focus_config then
			attachment:focus(focus_config.id, "host_attach")
		end
	end

	return attachment
end

InlineInput.HostAttachment = Attachment

return InlineInput
