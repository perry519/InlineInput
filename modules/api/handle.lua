local InlineInput = _G.InlineInput

InlineInput.Handle = InlineInput.Handle or {}
InlineInput.Handle.__index = InlineInput.Handle

function InlineInput.Handle:library()
	return rawget(self, "_inline_input_library") or _G.InlineInput
end

function InlineInput.Handle:value()
	local library = self:library()

	return library and library:GetValue(self) or nil
end

function InlineInput.Handle:set_value(value, source)
	local library = self:library()

	if not library then
		return false
	end

	library:SetValue(self, value, nil, source)
	return true
end

function InlineInput.Handle:available()
	local library = self:library()

	return library ~= nil and library._registrations ~= nil and library._registrations[self.id] == self
end

function InlineInput.Handle:unregister()
	local library = self:library()

	if not library then
		return false
	end

	library:Unregister(self.id)
	return true
end

function InlineInput:Register(config)
	if type(config) ~= "table" then
		return nil
	end

	local id = tostring(config.id or config.item_id or (#self._registration_order + 1))
	config.id = id

	if not self._registrations[id] then
		table.insert(self._registration_order, id)
	end

	config._inline_input_library = self
	self._registrations[id] = config
	setmetatable(config, self.Handle)

	if type(self.OnFieldRegistered) == "function" then
		self:OnFieldRegistered(config)
	else
		self:LogInfo("registered " .. tostring(id))
	end

	return config
end

function InlineInput:Unregister(id)
	self._registrations[id] = nil
end

return InlineInput
