local fusion = require("@packages/fusion")

local studioComponents = require("@packages/studioComponents")
local checkbox = studioComponents.common.checkbox

type props = {
	Value: fusion.Value<boolean>,
	LayoutOrder: number,
}

local function checkboxPropertyField(props: props)
	return checkbox({
		Color = "blue",
		AppearanceOverride = {
			_global = {
				Background = { shadow = 2 },
			},
		},
		State = props.Value,
		LayoutOrder = props.LayoutOrder,
        Margin = 4,
        Icon = {
            Name = "check",
            Size = 12,
        },
        Size = UDim2.new(0, 20, 0, 20),
	})
end

return checkboxPropertyField
