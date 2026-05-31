local InlineInput = _G.InlineInput

function InlineInput:IsModifierKey(key)
	return self:IsKey(key, "left ctrl")
		or self:IsKey(key, "right ctrl")
		or self:IsKey(key, "ctrl")
		or self:IsKey(key, "left control")
		or self:IsKey(key, "right control")
		or self:IsKey(key, "control")
		or self:IsKey(key, "left shift")
		or self:IsKey(key, "right shift")
		or self:IsKey(key, "shift")
end

function InlineInput:IsSharedInputCommand(key)
	if self:IsKey(key, "backspace")
		or self:IsHomeKey(key)
		or self:IsEndKey(key)
		or self:IsPageUpKey(key)
		or self:IsPageDownKey(key)
		or self:IsDeleteKey(key)
	then
		return true
	end

	if not self:IsControlDown() then
		return false
	end

	return self:IsKey(key, "a")
		or self:IsKey(key, "c")
		or self:IsKey(key, "x")
		or self:IsKey(key, "v")
		or self:IsLeftKey(key)
		or self:IsRightKey(key)
end

local function run_after_mutation(options)
	if options and type(options.after_mutation) == "function" then
		options.after_mutation()
	end
end

local function update_backspace_repeat(library, options, changed)
	if not options or not options.backspace_repeat then
		return
	end

	if changed then
		library:StartBackspaceRepeat(options.backspace_repeat.config, options.backspace_repeat.node_gui)
	else
		library:ClearBackspaceRepeat()
	end
end

function InlineInput:ApplySharedInputCommand(session, input_box, key, options)
	options = options or {}

	if self:IsControlDown() then
		if self:IsKey(key, "a") then
			return true, session:select_all()
		elseif self:IsKey(key, "c") then
			return true, session:copy()
		elseif self:IsKey(key, "x") then
			return true, session:cut()
		elseif self:IsKey(key, "v") then
			return true, session:paste()
		elseif self:IsLeftKey(key) then
			return true, session:move_word(-1, self:IsShiftDown())
		elseif self:IsRightKey(key) then
			return true, session:move_word(1, self:IsShiftDown())
		end
	end

	if self:IsKey(key, "backspace") then
		if self:IsControlDown() then
			session:word_backspace()
		elseif options.initial_backspace then
			session:initial_backspace()
			else
				update_backspace_repeat(self, options, session:backspace())
		end

		run_after_mutation(options)
		return true, true
	elseif self:IsHomeKey(key) or self:IsPageUpKey(key) then
		return true, self:SetCaretToTextEdge(input_box, "start", self:IsShiftDown())
	elseif self:IsEndKey(key) or self:IsPageDownKey(key) then
		return true, self:SetCaretToTextEdge(input_box, "end", self:IsShiftDown())
	elseif self:IsDeleteKey(key) then
		if self:IsControlDown() then
			session:word_delete()
		else
			session:delete()
		end

		run_after_mutation(options)
		return true, true
	end

	return false
end

return InlineInput
