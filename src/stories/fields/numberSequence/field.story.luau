local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local instanceProperty = require("@components/instanceProperty")
local numberSequence = require("@components/propertyFields/numberSequence")

local theme = require("@src/theme")

local PROPERTY_NAME = "Transparency"

return {
	summary = "Number sequence property field",
	story = storyBase(function(parent)
		local instance = Instance.new("ParticleEmitter")
		instance.Transparency = NumberSequence.new(0, 1)

		instance.Parent = workspace

		local component = instanceProperty({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			Property = PROPERTY_NAME,
			Content = {
				numberSequence({
					Instance = instance,
					PropertyName = PROPERTY_NAME,
					Value = Value(instance[PROPERTY_NAME]),
					LayoutOrder = 1,
				}, theme:get("InstanceTreeItem", "gray", "default", "Base")),
			},
		})

		component.Parent = parent

		return function()
			component:Destroy()
			instance:Destroy()
		end
	end),
}
