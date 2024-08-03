local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local listOption = require("@components/listOption")
local numberSequence = require("@components/propertyFields/numberSequence")

local theme = require("@src/theme")

local PROPERTY_NAME = "Transparency"

return {
	summary = "Number sequence property field",
	story = storyBase(function(parent)
		local instance = Instance.new("ParticleEmitter")
		instance.Transparency = NumberSequence.new(0, 1)

		instance.Parent = workspace

		local component = listOption({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			OptionName = PROPERTY_NAME,
			Content = {
				numberSequence({
					Instance = instance,
					PropertyName = PROPERTY_NAME,
					Value = Value(instance[PROPERTY_NAME]),
					LayoutOrder = 1,
					Max = 1,
					Min = 0,
					SupportsEnvelope = true,
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
