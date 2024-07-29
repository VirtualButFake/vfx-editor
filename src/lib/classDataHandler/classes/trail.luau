local class = {}

local fusionUtils = require("@packages/fusionUtils")
local onDestroy = fusionUtils.onDestroy

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local object = require("@components/propertyFields/object")
local enumDropdown = require("@components/propertyFields/enumDropdown")
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
		groupIdentifier = "stringInput",
		render = input,
	},
	{
		name = "Scale",
		groupIdentifier = "scaleInput",
		render = function(props)
			local inputField = input(props)

			onDestroy(inputField, {
				props.Instance:GetAttributeChangedSignal("_vfxEditorScale"):Connect(function()
					props.Value:set(props.Instance:GetAttribute("_vfxEditorScale") or 1)
				end),
			})

			return inputField
		end,
		get = function(instance)
			return instance:GetAttribute("_vfxEditorScale") or 1
		end,
		set = function(instance: ParticleEmitter, value)
			-- this number should be at least 0.001
			local number = tonumber(value)

			if not number then
				return false
			end

			if number < 0.001 then
				number = 0.001
			end

			local oldScale = instance:GetAttribute("_vfxEditorScale") or 1
			-- scale our instance relative to the old scale
			scaleUtils.scaleInstance(instance, number / oldScale)
			instance:SetAttribute("_vfxEditorScale", number)
			return
		end,
	},
	{
		name = "Appearance",
		properties = {
			{
				name = "Color",
				groupIdentifier = "colorSequence",
				render = colorSequence,
			},
			{
				name = "FaceCamera",
				groupIdentifier = "checkbox",
				render = checkbox,
			},
			{
				name = "LightEmission",
				groupIdentifier = "slider",
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
				groupIdentifier = "slider",
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
				groupIdentifier = "texturePicker",
				render = texturePicker,
				get = function(instance: ParticleEmitter)
					return `{instance.Texture},None`
				end,
				set = function(instance: ParticleEmitter, value)
					local split = value:split(",")

					if #split ~= 2 then
						return false
					end

					instance.Texture = split[1]
					return
				end,
			},
			{
				name = "TextureLength",
				groupIdentifier = "slider",
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
				groupIdentifier = "textureModeenumDropdown",
				render = enumDropdown,
			},
			{
				name = "Transparency",
				groupIdentifier = "transparencyNumberSequence",
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
				clipboardGet = function(props)
					return props.Instance:GetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1])
				end,
				clipboardSet = function(props, value)
					props.Instance:SetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1], value)
				end,
			},
		},
	},
	{
		name = "Data",
		properties = {
			{
				name = "Attachment0",
				groupIdentifier = "object",
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
				groupIdentifier = "object",
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
				groupIdentifier = "checkbox",
				render = checkbox,
			},
			{
				name = "Lifetime",
				groupIdentifier = "slider",
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
				groupIdentifier = "numberInput",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return false
					end

					instance.MaxLength = tonumber(value)
					return
				end,
			},
			{
				name = "MinLength",
				groupIdentifier = "numberInput",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return false
					end

					instance.MinLength = tonumber(value)
					return
				end,
			},
			{
				name = "WidthScale",
				groupIdentifier = "slider",
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
				clipboardGet = function(props)
					return props.Instance:GetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1])
				end,
				clipboardSet = function(props, value)
					props.Instance:SetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1], value)
				end,
			},
		},
	},
}

return class
