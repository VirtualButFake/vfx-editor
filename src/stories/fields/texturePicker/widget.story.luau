local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local texturePickerWidget = require("@components/propertyFields/texturePicker/editor")

local generateInstance = require("@src/stories/generateInstance")
local theme = require("@src/theme")

local PROPERTY_NAME = "Texture"

return {
	summary = "Number sequence property field",
	story = storyBase(function(parent)
		local instance = generateInstance().Particles.Drops

		local component = texturePickerWidget({
			Value = Value(instance[PROPERTY_NAME]),
			Instance = instance,
			Path = Value(""),
			useColor = theme:get("InstanceTreeItem", "gray", "default", "Base"),
			IsSelectingImage = false,
		})

		component.Parent = parent

		return function()
			component:Destroy()
			instance.Parent.Parent:Destroy()
		end
	end),
}
