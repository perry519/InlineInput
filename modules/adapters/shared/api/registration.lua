local InlineInput = _G.InlineInput

function InlineInput:RegisterInput(config)
	local handle = self:Register(config)

	if handle then
		handle.item_id = handle.item_id or handle.id
	end

	return handle
end

function InlineInput:EnsureInput(owner, field_name, config)
	if type(owner) ~= "table" or type(field_name) ~= "string" then
		return nil
	end

	local handle = owner[field_name]

	if handle and handle.available and handle:available() then
		handle:install_hooks()
		return handle
	end

	if type(config) == "function" then
		config = config(owner)
	end

	handle = self:RegisterInput(config)
	owner[field_name] = handle

	if handle then
		handle:install_hooks()
	end

	return handle
end

return InlineInput
