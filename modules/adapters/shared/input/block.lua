local InlineInput = _G.InlineInput

function InlineInput:InputBlockTime()
	if Application and Application.time then
		local ok, time = pcall(Application.time, Application)

		if ok and type(time) == "number" then
			return time
		end
	end

	return nil
end

function InlineInput:ClearInputBlock()
	self._block_next_menu_input = nil
	self._block_next_menu_input_count = nil
	self._block_next_menu_input_until = nil
end

function InlineInput:InputBlockActive()
	if not self._block_next_menu_input then
		return false
	end

	local until_time = self._block_next_menu_input_until
	local now = until_time and self:InputBlockTime()

	if now and until_time < now then
		self:ClearInputBlock()

		return false
	end

	return true
end

function InlineInput:BlockNextInput(consumes)
	self._block_next_menu_input = true
	self._block_next_menu_input_count = consumes or 1

	local now = self:InputBlockTime()
	self._block_next_menu_input_until = now and now + self.DEFAULTS.input_block_timeout_seconds or nil
end

function InlineInput:ConsumeInputBlock()
	if not self:InputBlockActive() then
		return false
	end

	local count = self._block_next_menu_input_count

	if count then
		count = count - 1

		if count <= 0 then
			self:ClearInputBlock()
		else
			self._block_next_menu_input_count = count
		end
	else
		self:ClearInputBlock()
	end

	return true
end

return InlineInput
