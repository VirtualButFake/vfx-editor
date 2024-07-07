local class = {}

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local object = require("@components/propertyFields/object")
local dropdown = require("@components/propertyFields/dropdown")
local colorSequence = require("@components/propertyFields/colorSequence")
local numberSequence = require("@components/propertyFields/numberSequence")
local texturePicker = require("@components/propertyFields/texturePicker")

local scaleUtils = require("@src/lib/scaleUtils")

function class.is(instance: Instance)
	return instance:IsA("Beam")
end

class.properties = {
	{
		name = "Name",
		render = input,
	},
    {
        name = "Scale",
        render = input,
        get = function(instance)
            return instance:GetAttribute("_vfxEditorScale") or 1
        end,
        set = function(instance: Beam, value)
            -- this number should be at least 0.001
            local number = tonumber(value)

            if not number then
                return
            end

            if number < 0.001 then
                number = 0.001
            end 

            local oldScale = instance:GetAttribute("_vfxEditorScale") or 1
            -- scale our instance relative to the old scale
            scaleUtils.scaleInstance(instance, number / oldScale)
            instance:SetAttribute("_vfxEditorScale", number)
        end,
    },
	{
		name = "Appearance",
		properties = {
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
				name = "Texture",
				render = texturePicker,
				get = function(instance: ParticleEmitter)
					return `{instance.Texture},None`
				end,
				set = function(instance: ParticleEmitter, value)
                    local split = value:split(",")

					instance.Texture = split[1]
				end,
			},
			{
				name = "TextureLength",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 5,
						Step = 0.02,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "TextureMode",
				render = dropdown,
			},
			{
				name = "TextureSpeed",
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
				name = "Transparency",
				render = function(props, useColor)
					return numberSequence({
                        SupportsEnvelope = false,
                        Instance = props.Instance,
                        PropertyName = props.PropertyName,
                        LayoutOrder = props.LayoutOrder,
                        Value = props.Value,
                        Min = 0,
                        Max = 1
                    }, useColor)
				end,
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
		name = "Shape",
		properties = {
            {
                name = "Attachment0",
                render = function(props, useColor)
                    return object({
                        Value = props.Value,
                        LayoutOrder = props.LayoutOrder,
                        Filter = function(instance)
                            return instance:IsA("Attachment")
                        end,
                        Events = props.Events,
                    }, useColor)
                end,
            },
            {
                name = "Attachment1",
                render = function(props, useColor)
                    return object({
                        Value = props.Value,
                        LayoutOrder = props.LayoutOrder,
                        Filter = function(instance)
                            return instance:IsA("Attachment")
                        end,
                        Events = props.Events,
                    }, useColor)
                end,
            },
			{
				name = "CurveSize0",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = -10,
						Max = 10,
						Step = 0.05,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "CurveSize1",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = -10,
						Max = 10,
						Step = 0.05,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "FaceCamera",
				render = checkbox,
			},
			{
				name = "Segments",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return
					end

					if number < 1 then
						number = 1
					elseif number > 1000 then
						number = 1000
					end

					instance.Segments = number
				end,
			},
			{
				name = "Width0",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return
					end

					if number < 0 then
						number = 0
					elseif number > 999999986991104 then
						number = 999999986991104
					end

					instance.Width0 = number
				end,
			},
			{
				name = "Width1",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return
					end

					if number < 0 then
						number = 0
					elseif number > 999999986991104 then
						number = 999999986991104
					end

					instance.Width1 = number
				end,
			},
		},
	},
}

return class
