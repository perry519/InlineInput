local InlineInput = _G.InlineInput

function InlineInput:CaptureScrollIndicators(node_gui)
	local arrows = node_gui and node_gui._list_arrows

	if not arrows then
		return nil
	end

	local states = {}

	for _, arrow in pairs({ arrows.up, arrows.down }) do
		if arrow then
			local state = {
				arrow = arrow
			}

			if arrow.color then
				state.color = InlineInput:SafeCall(function()
					return arrow:color()
				end)
			end

			if type(arrow.alpha) == "function" then
				state.alpha = InlineInput:SafeCall(function()
					return arrow:alpha()
				end)
			elseif arrow.alpha ~= nil then
				state.alpha = arrow.alpha
			end

			if type(arrow.visible) == "function" then
				state.visible = InlineInput:SafeCall(function()
					return arrow:visible()
				end)
			elseif arrow.visible ~= nil then
				state.visible = arrow.visible
			end

			table.insert(states, state)
		end
	end

	return states
end

function InlineInput:RestoreScrollIndicators(states)
	for _, state in ipairs(states or {}) do
		local arrow = state.arrow

		if arrow then
			if state.color ~= nil and arrow.set_color then
				InlineInput:SafeCall(function()
					arrow:set_color(state.color)
				end)
			end

			if state.alpha ~= nil and arrow.set_alpha then
				InlineInput:SafeCall(function()
					arrow:set_alpha(state.alpha)
				end)
			end

			if state.visible ~= nil and arrow.set_visible then
				InlineInput:SafeCall(function()
					arrow:set_visible(state.visible)
				end)
			end
		end
	end
end

function InlineInput:PreserveScrollIndicatorsOnce(node_gui, states)
	self._preserve_scroll_indicator_node = node_gui
	self._preserve_scroll_indicator_state = states or self:CaptureScrollIndicators(node_gui)
end

function InlineInput:CaptureAndPreserveScrollIndicators(node_gui)
	local states = self:CaptureScrollIndicators(node_gui)
	self:PreserveScrollIndicatorsOnce(node_gui, states)
	return states
end

function InlineInput:RestoreAndPreserveScrollIndicators(node_gui, states)
	self:RestoreScrollIndicators(states)
	self:PreserveScrollIndicatorsOnce(node_gui, states)
end

function InlineInput:RestorePreservedScrollIndicators(node_gui)
	if self._preserve_scroll_indicator_node ~= node_gui then
		return false
	end

	local states = self._preserve_scroll_indicator_state

	self._preserve_scroll_indicator_node = nil
	self._preserve_scroll_indicator_state = nil
	self:RestoreScrollIndicators(states)

	return true
end

return InlineInput
