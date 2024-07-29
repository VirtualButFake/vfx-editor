local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local listOption = require("@components/listOption")
local input = require("@components/propertyFields/input")

local instance = Instance.new("Part")

local PROPERTY_NAME = "Name"

return {
	summary = "Input property field",
	story = storyBase(function(parent)
		local component = listOption({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			OptionName = PROPERTY_NAME,
			Content = {
				input({
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
