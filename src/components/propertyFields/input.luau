local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local input = fusionComponents.common.input

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type props = {
	Value: fusion.Value<string>,
	LayoutOrder: number,
}

local function inputPropertyField(props: props)
	local inputDisplay = Value(tostring(props.Value:get(false)))

	local onPropertyChange = Observer(props.Value):onChange(function()
		inputDisplay:set(tostring(props.Value:get()))
	end)

	return input({
		Variant = "default",
		Color = "gray",
		AppearanceOverride = {
			_global = {
				Background = {
					color = Computed(function()
						return theme.global.isDark:get() and tailwind.neutral[850] or tailwind.white
					end),
					shadow = 1,
				},
			},
			Focus = {
				Stroke = Computed(function()
					return theme.global.isDark:get() and tailwind.blue[400] or tailwind.blue[500]
				end),
			},
		},
		Text = inputDisplay,
		OnFocusLost = function(text)
			props.Value:set(text)
		end,
		Size = UDim2.new(0.75, 0, 0, 20),
		LayoutOrder = props.LayoutOrder,
		[Cleanup] = { onPropertyChange },
	})
end

return inputPropertyField
