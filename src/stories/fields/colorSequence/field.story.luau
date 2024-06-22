local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local listOption = require("@components/listOption")
local colorSequence = require("@components/propertyFields/colorSequence")

local theme = require("@src/theme")

local PROPERTY_NAME = "Color"

return {
	summary = "Color sequence property field",
	story = storyBase(function(parent)
		local instance = Instance.new("ParticleEmitter")
		instance.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255)),
		})

		instance.Parent = workspace

		local component = listOption({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			OptionName = PROPERTY_NAME,
			Content = {
				colorSequence({
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
