local class = {}

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local range = require("@components/propertyFields/range")
local object = require("@components/propertyFields/object")
local dropdown = require("@components/propertyFields/dropdown")
local colorSequence = require("@components/propertyFields/colorSequence")
local numberSequence = require("@components/propertyFields/numberSequence")
local texturePicker = require("@components/propertyFields/texturePicker")

local scaleUtils = require("@src/lib/scaleUtils")

function class.is(instance: Instance)
	return instance:IsA("Trail")
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
				name = "Color",
				render = colorSequence,
			},
			{
				name = "FaceCamera",
				render = checkbox,
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
						Min = 0.1,
						Max = 5,
						Step = 0.01,
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
				name = "Transparency",
				render = function(props, useColor)
					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = false,
						Min = 0,
						Max = 1,
					}, useColor)
				end,
			},
		},
	},
	{
		name = "Data",
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
		},
	},
	{
		name = "Emission",
		properties = {
			{
				name = "Enabled",
				render = checkbox,
			},
			{
				name = "Lifetime",
				render = function(props)
					return slider({
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
				name = "MaxLength",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return
					end

					instance.MaxLength = tonumber(value)
				end,
			},
			{
				name = "MinLength",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return
					end

					instance.MinLength = tonumber(value)
				end,
			},
			{
				name = "WidthScale",
				render = function(props, useColor)
					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = false,
						Min = 0,
						Max = 1,
					}, useColor)
				end,
			},
		},
	},
}

return class
