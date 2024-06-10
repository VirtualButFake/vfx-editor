local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local instanceProperty = require("@components/instanceProperty")
local checkbox = require("@components/propertyFields/checkbox")

local instance = Instance.new("Part")

local PROPERTY_NAME = "Anchored"

return {
	summary = "Checkbox property field",
	story = storyBase(function(parent)
		local component = instanceProperty({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			Property = PROPERTY_NAME,
			Content = {
				checkbox({
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
