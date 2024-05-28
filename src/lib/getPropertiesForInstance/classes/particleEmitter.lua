local class = {}

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local dropdown = require("@components/propertyFields/dropdown")
local colorSequence = require("@components/propertyFields/colorSequence")

function class.is(instance: Instance)
	return instance:IsA("ParticleEmitter")
end

class.properties = {
	{
		name = "Name",
		render = input,
	},
	{
		name = "Enabled",
		render = checkbox,
	},
	{
		name = "ZOffset",
		render = function(props)
			return slider({
				Instance = props.Instance,
				PropertyName = props.PropertyName,
				Value = props.Value,
				LayoutOrder = props.LayoutOrder,
				Min = 0,
				Max = 20,
				Step = 0.5,
			})
		end,
	},
	{
		name = "Orientation",
		render = dropdown,
	},
	{
		name = "Color",
		render = colorSequence,
	},
}

return class
