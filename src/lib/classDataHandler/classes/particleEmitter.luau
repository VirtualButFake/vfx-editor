local class = {}

local fusionUtils = require("@packages/fusionUtils")
local onDestroy = fusionUtils.onDestroy

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local range = require("@components/propertyFields/range")
local enumDropdown = require("@components/propertyFields/enumDropdown")
local colorSequence = require("@components/propertyFields/colorSequence")
local numberSequence = require("@components/propertyFields/numberSequence")
local texturePicker = require("@components/propertyFields/texturePicker")

local scaleUtils = require("@src/lib/scaleUtils")
local settingsManager = require("@src/lib/settingsManager")

local MAX_SIZE = settingsManager.getReactiveWithFallback("max_size", 10)
local MAX_SQUASH = settingsManager.getReactiveWithFallback("max_squash", 3)

function class.is(instance: Instance)
	return instance:IsA("ParticleEmitter")
end

function class.emit(instance: ParticleEmitter)
	local emitStart = tick()
	local emitAmount = instance:GetAttribute("_vfxEditorEmitAmount") or 20
	local emitDelay = instance:GetAttribute("_vfxEditorEmitDelay") or 0
	instance:SetAttribute("_vfxEditorStartEmit", emitStart)

	task.delay(emitDelay, function()
		if instance:GetAttribute("_vfxEditorStartEmit") ~= emitStart then
			return
		end

		instance:Emit(emitAmount)
		instance:SetAttribute("_vfxEditorStartEmit", nil)
	end)
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
		name = "Emit",
		properties = {
			{
				name = "Amount",
				groupIdentifier = "numberInput",
				linkedAttribute = "_vfxEditorEmitAmount",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return false
					end

					instance:SetAttribute("_vfxEditorEmitAmount", value)
					return
				end,
				get = function(instance)
                    if instance:GetAttribute("EmitCount") then 
                        return instance:GetAttribute("EmitCount")
                    end

					return instance:GetAttribute("_vfxEditorEmitAmount") or 20
				end,
			},
			{
				name = "Delay",
				groupIdentifier = "numberInput",
				linkedAttribute = "_vfxEditorEmitDelay",
				render = input,
				set = function(instance, value)
					if not tonumber(value) then
						return false
					end

					instance:SetAttribute("_vfxEditorEmitDelay", value)
					return
				end,
				get = function(instance)
                    if instance:GetAttribute("EmitDelay") then 
                        return instance:GetAttribute("EmitDelay")
                    end

					return instance:GetAttribute("_vfxEditorEmitDelay") or 0
				end,
			},
		},
	},
	{
		name = "Appearance",
		properties = {
			{
				name = "Brightness",
				groupIdentifier = "slider",
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
				groupIdentifier = "colorSequence",
				render = colorSequence,
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
				name = "Orientation",
				groupIdentifier = "orientationenumDropdown",
				render = enumDropdown,
			},
			{
				name = "Size",
				groupIdentifier = "sizeNumberSequence",
				render = function(props, useColor)
					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = true,
						Min = 0,
						Max = MAX_SIZE:get(),
					}, useColor)
				end,
				clipboardGet = function(props)
					return props.Instance:GetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1])
				end,
				clipboardSet = function(props, value)
					props.Instance:SetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1], value)
				end,
			},
			{
				name = "Squash",
				groupIdentifier = "squashNumberSequence",
				render = function(props, useColor)
					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = true,
						Min = -3,
						Max = MAX_SQUASH:get(),
					}, useColor)
				end,
				clipboardGet = function(props)
					return props.Instance:GetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1])
				end,
				clipboardSet = function(props, value)
					props.Instance:SetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1], value)
				end,
			},
			{
				name = "Texture",
				groupIdentifier = "texturePicker",
				render = texturePicker,
				get = function(instance: ParticleEmitter)
					return `{instance.Texture},{instance.FlipbookLayout.Name}`
				end,
				set = function(instance: ParticleEmitter, value)
					local split = value:split(",")

					if #split ~= 2 and Enum.ParticleFlipbookLayout[split[2]] then
						return false
					end

					instance.Texture = split[1]
					instance.FlipbookLayout =
						Enum.ParticleFlipbookLayout[split[2] :: any] :: Enum.ParticleFlipbookLayout

					if instance.FlipbookFramerate == NumberRange.new(1) then
						instance.FlipbookFramerate = NumberRange.new(30)
					end

					return
				end,
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
						SupportsEnvelope = true,
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
			{
				name = "ZOffset",
				groupIdentifier = "slider",
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
				groupIdentifier = "emissionDirectionenumDropdown",
				render = enumDropdown,
			},
			{
				name = "Enabled",
				groupIdentifier = "checkbox",
				render = checkbox,
			},
			{
				name = "Lifetime",
				groupIdentifier = "range",
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
				groupIdentifier = "slider",
				render = function(props)
					return slider({
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
				name = "Rotation",
				groupIdentifier = "range",
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
				groupIdentifier = "range",
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
				groupIdentifier = "range",
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
				groupIdentifier = "vector2Input",
				render = input,
				set = function(instance, value)
					if typeof(value) == "Vector2" then
						if instance.SpreadAngle.X ~= value.X or instance.SpreadAngle.Y ~= value.Y then
							instance.SpreadAngle = value
						end

						return false
					end

					local x, y = value:match("([^,]+),([^,]+)")

					if not x or not y then
						return false
					end

					instance.SpreadAngle = Vector2.new(tonumber(x), tonumber(y))
					return
				end,
			},
		},
	},
	{
		name = "EmitterShape",
		properties = {
			{
				name = "Shape",
				groupIdentifier = "shapeenumDropdown",
				render = enumDropdown,
			},
			{
				name = "ShapeInOut",
				groupIdentifier = "shapeInOutenumDropdown",
				render = enumDropdown,
			},
			{
				name = "ShapePartial",
				groupIdentifier = "slider",
				render = function(props, _, currentProperties)
					if currentProperties:get(false).Shape:get() == Enum.ParticleEmitterShape.Box then
						return nil
					end

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
				name = "ShapeStyle",
				groupIdentifier = "shapeStyleenumDropdown",
				render = enumDropdown,
			},
		},
	},
	{
		name = "Motion",
		properties = {
			{
				name = "Acceleration",
				groupIdentifier = "vector3Input",
				render = input,
				set = function(instance, value)
					if typeof(value) == "Vector3" then
						if
							instance.Acceleration.X ~= value.X
							or instance.Acceleration.Y ~= value.Y
							or instance.Acceleration.Z ~= value.Z
						then
							instance.Acceleration = value
						end

						return false
					end

					local x, y, z = value:match("([^,]+),([^,]+),([^,]+)")

					if not x or not y or not z then
						return false
					end

					instance.Acceleration = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
					return
				end,
			},
		},
	},
	{
		name = "Particles",
		properties = {
			{
				name = "Drag",
				groupIdentifier = "slider",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 5,
						Step = 0.025,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "LockedToPart",
				groupIdentifier = "checkbox",
				render = checkbox,
			},
			{
				name = "TimeScale",
				groupIdentifier = "slider",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 1,
						Step = 0.02,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "VelocityInheritance",
				groupIdentifier = "slider",
				render = function(props)
					return slider({
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						Min = 0,
						Max = 1,
						Step = 0.02,
						Instance = props.Instance,
						PropertyName = props.PropertyName,
					})
				end,
			},
			{
				name = "WindAffectsDrag",
				groupIdentifier = "checkbox",
				render = checkbox,
			},
		},
	},
}

return class
