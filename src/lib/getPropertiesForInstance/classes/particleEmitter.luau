local class = {}

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local range = require("@components/propertyFields/range")
local dropdown = require("@components/propertyFields/dropdown")
local colorSequence = require("@components/propertyFields/colorSequence")
local numberSequence = require("@components/propertyFields/numberSequence")
local texturePicker = require("@components/propertyFields/texturePicker")

function class.is(instance: Instance)
	return instance:IsA("ParticleEmitter")
end

class.properties = {
	{
		name = "Appearance",
		properties = {
			--[[{
				name = "Name",
				render = input,
			},]]
			{
				name = "Brightness",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 10,
						Step = 0.05,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "Color",
				render = colorSequence,
			},
			{
				name = "LightEmission",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 1,
						Step = 0.01,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "LightInfluence",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 1,
						Step = 0.01,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "Orientation",
				render = dropdown,
			},
			{
				name = "Size",
				render = numberSequence,
			},
			{
				name = "Squash",
				render = numberSequence,
			},
			{
				name = "Texture",
				render = texturePicker,
				get = function(instance)
					return {
						Texture = instance.Texture,
						FlipbookLayout = instance.FlipbookLayout,
					}
				end,
				set = function(instance: ParticleEmitter, value)
					instance.Texture = value.Texture
					instance.FlipbookLayout = value.FlipbookLayout

					if instance.FlipbookFramerate == NumberRange.new(1) then
						instance.FlipbookFramerate = NumberRange.new(30)
					end
				end,
			},

			{
				name = "Transparency",
				render = numberSequence,
			},
			{
				name = "ZOffset",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 20,
						Step = 0.5,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
		},
	},
	{
		name = "Emission",
		properties = {
			{
				name = "EmissionDirection",
				render = dropdown,
			},
			{
				name = "Enabled",
				render = checkbox,
			},
			{
				name = "Lifetime",
				render = function(props)
					return range({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 5,
						Step = 0.1,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "Rate",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Max = 100,
						Step = 1,
						Instance = props.Instance,
						Min = 0,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "Rotation",
				render = function(props)
					return range({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = -180,
						Max = 180,
						Step = 1,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
            {
                name = "RotSpeed",
                render = function(props)
                    return range({
                        Value = props.Value,
                        LayoutOrder = props.LayoutOrder,
                        Min = -360,
                        Max = 360,
                        Step = 1,
                        Instance = props.Instance,
                        PropertyName = props.PropertyName,
                    })
                end,
            },
            {
                name = "Speed",
                render = function(props)
                    return range({
                        Value = props.Value,
                        LayoutOrder = props.LayoutOrder,
                        Min = 0,
                        Max = 100,
                        Step = 1,
                        Instance = props.Instance,
                        PropertyName = props.PropertyName,
                    })
                end,
            },
            {
                name = "SpreadAngle",
                render = input,
                set = function(instance, value)
                    if typeof(value) == "Vector2" then 
                        if instance.SpreadAngle.X ~= value.X or instance.SpreadAngle.Y ~= value.Y then
                            instance.SpreadAngle = value
                        end

                        return
                    end

                    local x, y = value:match("([^,]+),([^,]+)")

                    if not x or not y then
                        return
                    end

                    instance.SpreadAngle = Vector2.new(tonumber(x), tonumber(y))
                end,
            }
		},
	},
}

return class
