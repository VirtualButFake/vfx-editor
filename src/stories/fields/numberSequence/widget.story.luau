local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local numberSequenceWidget = require("@components/propertyFields/numberSequence/editor")

local theme = require("@src/theme")

local generateInstance = require("@src/stories/generateInstance")

local PROPERTY_NAME = "Transparency"

return {
	summary = "Number sequence property field",
	story = storyBase(function(parent)
		local instance = generateInstance().Particles.Drops

		local component = numberSequenceWidget({
			Value = Value(instance[PROPERTY_NAME]),
			useColor = theme:get("InstanceTreeItem", "gray", "default", "Base"),
			Instance = instance,
			PropertyName = PROPERTY_NAME,
			Max = 1,
			Min = 0,
			SupportsEnvelope = true,
		})

		component.Parent = parent

		return function()
			component:Destroy()
			instance.Parent.Parent:Destroy()
		end
	end),
}
