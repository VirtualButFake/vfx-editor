local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Value = fusion.Value

local colorSequenceEditor = require("@components/propertyFields/colorSequence/editor")

local theme = require("@src/theme")

local PROPERTY_NAME = "Color"

return {
	summary = "Color sequence widget",
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

		local component = New("Frame")({
			Name = "ColorSequenceWidget",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 400, 0, 275),
			[Children] = {
				colorSequenceEditor({
					Value = Value(instance[PROPERTY_NAME]),
					useColor = theme:get("InstanceTreeItem", "gray", "default", "Base"),
				}),
			},
		})

		component.Parent = parent

		return function()
			component:Destroy()
			instance:Destroy()
		end
	end),
}
