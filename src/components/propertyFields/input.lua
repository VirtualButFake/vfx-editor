local fusion = require("@packages/fusion")

local studioComponents = require("@packages/studioComponents")
local input = studioComponents.common.input

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<string>,
	LayoutOrder: number,
}

local function inputPropertyField(props: props)
	return input({
		Variant = "default",
		Color = "gray",
		AppearanceOverride = {
			_global = {
				Background = { color = theme.global.isDark:get() and tailwind.neutral[850] or tailwind.white, shadow = 1 },
			},
			Focus = {
				Stroke = theme.global.isDark:get() and tailwind.blue[400] or tailwind.blue[500],
			},
		},
		Text = props.Value:get(),
		OnFocusLost = function(text)
			props.Value:set(text)
		end,
		Size = UDim2.new(0.75, 0, 0, 20),
		LayoutOrder = props.LayoutOrder,
	})
end

return inputPropertyField
