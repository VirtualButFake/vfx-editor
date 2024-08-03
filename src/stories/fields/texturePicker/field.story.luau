local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Value = fusion.Value

local listOption = require("@components/listOption")
local texturePicker = require("@components/propertyFields/texturePicker")

local PROPERTY_NAME = "Texture"

return {
	summary = "Texture property field",
	story = storyBase(function(parent)
		local instance = Instance.new("ParticleEmitter")
		instance.Texture = "rbxassetid://0"

		instance.Parent = workspace

		local component = listOption({
			Size = UDim2.new(0, 256, 0, 48),
			Position = UDim2.new(0, 0, 0, 0),
			OptionName = PROPERTY_NAME,
			Content = {
				texturePicker({
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
			instance:Destroy()
		end
	end),
}
