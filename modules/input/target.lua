local InlineInput = _G.InlineInput

function InlineInput:IsInputTarget(value)
	return type(value) == "table" and value._inline_input_target == true
end

function InlineInput:CreateInputTarget(target)
	if self:IsInputTarget(target) then
		return target
	end

	return nil
end

return InlineInput
