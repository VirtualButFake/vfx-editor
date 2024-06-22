local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local listOption = require("@components/listOption")
local dropdown = require("@components/propertyFields/dropdown")

local instance = Instance.new("Part")

local PROPERTY_NAME = "Shape"

return {
	summary = "Dropdown property field",
	story = storyBase(function(parent)
		local component = listOption({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			OptionName = PROPERTY_NAME,
			Content = {
				dropdown({
					Instance = instance,
					PropertyName = PROPERTY_NAME,
					Value = Value(instance[PROPERTY_NAME]),
					LayoutOrder = 1,
				}),
			},
		})

		component.Parent = parent

		return function()
			component:Destroy()
		end
	end),
}
