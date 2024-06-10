local fusion = require("@packages/fusion")

local studioComponents = require("@packages/studioComponents")
local checkbox = studioComponents.common.checkbox

type props = {
	Instance: Instance,
	PropertyName: string,
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
	})
end

return checkboxPropertyField
