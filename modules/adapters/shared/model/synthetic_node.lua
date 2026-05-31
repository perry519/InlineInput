local InlineInput = _G.InlineInput

local function make_item(name)
	return {
		_parameters = {
			name = name
		},
		parameters = function(self)
			return self._parameters
		end
	}
end

local function make_row_item(row, default_item_id, default_panel)
	row = row or {}
	local config = row.config

	return {
		config = config,
		item = row.item or make_item(row.item_id or row.id or (config and (config.item_id or config.id)) or default_item_id),
		gui_panel = row.gui_panel or row.panel or default_panel
	}
end

local function synthetic_row_items(options, config, item_id, row_panel)
	local rows = options.row_items or options.rows

	if type(rows) == "table" and #rows > 0 then
		local result = {}

		for index, row in ipairs(rows) do
			local row_config = row and row.config or nil
			local fallback_id = row and (row.item_id or row.id) or nil
			fallback_id = fallback_id or (row_config and (row_config.item_id or row_config.id))
			result[index] = make_row_item(row, fallback_id or item_id, row_panel)
		end

		return result
	end

	return {
		make_row_item(nil, item_id, row_panel)
	}
end

local function synthetic_config_ids(options, config)
	local ids = {}

	for _, id in ipairs(options.config_ids or {}) do
		if id ~= nil then
			ids[#ids + 1] = tostring(id)
		end
	end

	if #ids == 0 then
		for _, input_config in ipairs(options.configs or {}) do
			if input_config and input_config.id ~= nil then
				ids[#ids + 1] = tostring(input_config.id)
			end
		end
	end

	if #ids == 0 and config and config.id ~= nil then
		ids[1] = tostring(config.id)
	end

	return ids
end

local function set_adapter_markers(node, adapter_id, node_id, owner)
	if type(adapter_id) ~= "string" or adapter_id == "" then
		return
	end

	node["_inline_input_" .. adapter_id .. "_node"] = true
	node["_inline_input_" .. adapter_id .. "_id"] = node_id

	if owner ~= nil then
		node["_inline_input_" .. adapter_id .. "_gui"] = owner
	end
end

function InlineInput:CreateSyntheticInputNode(options)
	options = options or {}

	local config = options.config or {}
	local node_id = options.node_id or config.menu_id or config.id
	local item_id = options.item_id or config.item_id or config.id
	local owner = options.owner
	local row_panel = options.row_panel or options.item_panel

	local node = {
		_inline_input_synthetic_node = true,
		_inline_input_synthetic_adapter = options.adapter_id,
		_inline_input_synthetic_id = node_id,
		_inline_input_synthetic_owner = owner,
		_inline_input_config_ids = synthetic_config_ids(options, config),
		configs = options.configs,
		name = node_id,
		item_panel = options.item_panel,
		ws = options.ws,
		node = {
			parameters = function()
				return { name = node_id }
			end
		},
		row_items = synthetic_row_items(options, config, item_id, row_panel),
		refresh_gui = function(self)
			if options.refresh then
				return options.refresh(self, owner)
			end

			if owner and owner.refresh_items then
				return owner:refresh_items()
			end
		end,
		highlight_item = options.highlight_item or function() end
	}

	set_adapter_markers(node, options.adapter_id, node_id, owner)

	return node
end

function InlineInput:SyntheticInputNodeMatches(node_gui, adapter_id, node_id)
	if not node_gui or node_id == nil then
		return false
	end

	local expected_id = tostring(node_id or "")

	if node_gui._inline_input_synthetic_node == true then
		local adapter_matches = adapter_id == nil or node_gui._inline_input_synthetic_adapter == adapter_id
		if adapter_matches and tostring(node_gui._inline_input_synthetic_id or "") == expected_id then
			return true
		end
	end

	if type(adapter_id) == "string" and adapter_id ~= "" then
		local marker = "_inline_input_" .. adapter_id .. "_node"
		local id_field = "_inline_input_" .. adapter_id .. "_id"
		return node_gui[marker] == true and tostring(node_gui[id_field] or "") == expected_id
	end

	return false
end

return InlineInput
