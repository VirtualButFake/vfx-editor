local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local class = {}

local fusionUtils = require("@packages/fusionUtils")
local onDestroy = fusionUtils.onDestroy

local checkbox = require("@components/propertyFields/checkbox")
local input = require("@components/propertyFields/input")
local slider = require("@components/propertyFields/slider")
local object = require("@components/propertyFields/object")
local dropdown = require("@components/propertyFields/dropdown")
local enumDropdown = require("@components/propertyFields/enumDropdown")
local colorSequence = require("@components/propertyFields/colorSequence")
local numberSequence = require("@components/propertyFields/numberSequence")
local texturePicker = require("@components/propertyFields/texturePicker")

local scaleUtils = require("@src/lib/scaleUtils")
local settingsManager = require("@src/lib/settingsManager")

local MAX_SIZE = settingsManager.getReactiveWithFallback("max_size", 10)

-- from https://create.roblox.com/docs/reference/engine/datatypes/NumberSequence
local function evalNumberSequence(sequence: NumberSequence, time: number)
	-- If time is 0 or 1, return the first or last value respectively

	if time == 0 then
		return sequence.Keypoints[1].Value
	elseif time == 1 then
		return sequence.Keypoints[#sequence.Keypoints].Value
	end

	-- Otherwise, step through each sequential pair of keypoints
	for i = 1, #sequence.Keypoints - 1 do
		local currKeypoint = sequence.Keypoints[i]

		local nextKeypoint = sequence.Keypoints[i + 1]

		if time >= currKeypoint.Time and time < nextKeypoint.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)

			-- Return the value between the points using alpha
			return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
		end
	end

	return
end

function class.is(instance: Instance)
	return instance:IsA("Beam")
end

function class.emit(instance: Beam)
	local emitStart = tick()
	instance:SetAttribute("_vfxEditorStartEmit", emitStart)

	local originalProperties = {}

	local selectedProperties = instance:GetAttribute("_vfxEditorEmitProperty") or { "Width" }

	if table.find(selectedProperties, "Width") then
		table.remove(selectedProperties, table.find(selectedProperties, "Width"))
		table.insert(selectedProperties, "Width0")
		table.insert(selectedProperties, "Width1")
	end

	for _, property in selectedProperties do
		local originalValue = instance:GetAttribute("_vfxEditorEmitOriginal" .. property) or instance[property]
		originalProperties[property] = originalValue
		instance:SetAttribute("_vfxEditorEmitOriginal" .. property, originalValue)
	end

	task.delay(instance:GetAttribute("_vfxEditorEmitDelay") or 0, function()
		if instance:GetAttribute("_vfxEditorStartEmit") ~= emitStart then
			return
		end
		local renderConnection
		local progress = 0
		local duration = instance:GetAttribute("_vfxEditorEmitDuration") or 1

		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if instance:GetAttribute("_vfxEditorStartEmit") ~= emitStart then
				renderConnection:Disconnect()
				return
			end

			progress += dt

			if progress > duration then
				renderConnection:Disconnect()

				for property, originalValue in originalProperties do
					instance[property] = originalValue
				end

				if instance:GetAttribute("_vfxEditorStartEmit") == emitStart then
					instance:SetAttribute("_vfxEditorStartEmit", nil)
				end
			end

			-- interpolate on the curves, set values based on progrees
			for _, property in selectedProperties do
				local curve = instance:GetAttribute("_vfxEditorEmit" .. property .. "Curve")

				if curve then
					local value = evalNumberSequence(curve, progress / duration)

					if value then
						instance[property] = value
					end
				end
			end
		end)
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
		render = function(props)
			local inputField = input(props)

			onDestroy(inputField, {
				props.Instance:GetAttributeChangedSignal("_vfxEditorScale"):Connect(function()
					props.Value:set(props.Instance:GetAttribute("_vfxEditorScale") or 1)
				end),
			})

			return inputField
		end,
		groupIdentifier = "scaleInput",
		get = function(instance)
			return instance:GetAttribute("_vfxEditorScale") or 1
		end,
		set = function(instance: Beam, value)
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
				name = "Duration",
				groupIdentifier = "numberInput",
				linkedAttribute = "_vfxEditorEmitDuration",
				render = input,
				get = function(instance)
					return instance:GetAttribute("_vfxEditorEmitDuration") or 1
				end,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return false
					end

					instance:SetAttribute("_vfxEditorEmitDuration", number)
					return
				end,
			},
			{
				name = "Delay",
				groupIdentifier = "numberInput",
				linkedAttribute = "_vfxEditorEmitDelay",
				render = input,
				get = function(instance)
					return instance:GetAttribute("_vfxEditorEmitDelay") or 0
				end,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return false
					end

					instance:SetAttribute("_vfxEditorEmitDelay", number)
					return
				end,
			},
			{
				name = "Property",
				groupIdentifier = "propertyDropdown",
				linkedAttribute = "_vfxEditorEmitProperty",
				render = function(props)
					return dropdown({
						Value = props.Value,
						Instance = props.Instance,
						LayoutOrder = props.LayoutOrder,
						Multiple = true,
						Options = {
							{
								Id = "Width",
							},
							{
								Id = "Transparency",
							},
						},
					})
				end,
				get = function(instance)
					local attribute = instance:GetAttribute("_vfxEditorEmitProperty")

					if typeof(attribute) == "string" then
						return HttpService:JSONDecode(attribute)
					end

					return { "Width" }
				end,
				set = function(instance, value)
					instance:SetAttribute("_vfxEditorEmitProperty", HttpService:JSONEncode(value))
				end,
			},
			{
				name = "Width0 Curve",
				groupIdentifier = "curveNumberSequence",
				linkedAttribute = "_vfxEditorEmitWidth0Curve",
				render = function(props, useColor, properties)
					if properties:get().Property and not table.find(properties:get().Property:get(), "Width") then
						return
					end

					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = false,
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
				get = function(instance)
					return instance:GetAttribute("_vfxEditorEmitWidth0Curve") or NumberSequence.new(0, 1)
				end,
				set = function(instance, value)
					instance:SetAttribute("_vfxEditorEmitWidth0Curve", value)
				end,
			},
			{
				name = "Width1 Curve",
				groupIdentifier = "curveNumberSequence",
				linkedAttribute = "_vfxEditorEmitWidth1Curve",
				render = function(props, useColor, properties)
					if properties:get().Property and not table.find(properties:get().Property:get(), "Width") then
						return
					end

					return numberSequence({
						Instance = props.Instance,
						PropertyName = props.PropertyName,
						Value = props.Value,
						LayoutOrder = props.LayoutOrder,
						SupportsEnvelope = false,
						Min = 0,
						Max = MAX_SIZE:get(),
					}, useColor)
				end,
				get = function(instance)
					return instance:GetAttribute("_vfxEditorEmitWidth1Curve") or NumberSequence.new(0, 1)
				end,
				set = function(instance, value)
					instance:SetAttribute("_vfxEditorEmitWidth1Curve", value)
				end,
				clipboardGet = function(props)
					return props.Instance:GetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1])
				end,
				clipboardSet = function(props, value)
					props.Instance:SetAttribute("_vfxEditorGraph" .. props.PropertyName:split(" ")[1], value)
				end,
			},
			{
				name = "Transparency Curve",
				groupIdentifier = "curveNumberSequence",
				linkedAttribute = "_vfxEditorEmitTransparencyCurve",
				render = function(props, useColor, properties)
					if
						properties:get().Property and not table.find(properties:get().Property:get(), "Transparency")
					then
						return
					end

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
				get = function(instance)
					return instance:GetAttribute("_vfxEditorEmitTransparencyCurve") or NumberSequence.new(1)
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
				groupIdentifier = "textureModeenumDropdown",
				render = enumDropdown,
			},
			{
				name = "TextureSpeed",
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
		name = "Shape",
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
			{
				name = "CurveSize0",
				groupIdentifier = "slider",
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
				groupIdentifier = "slider",
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
				groupIdentifier = "checkbox",
				render = checkbox,
			},
			{
				name = "Segments",
				groupIdentifier = "numberInput",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return false
					end

					if number < 1 then
						number = 1
					elseif number > 1000 then
						number = 1000
					end

					instance.Segments = number
					return
				end,
			},
			{
				name = "Width0",
				groupIdentifier = "numberInput",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return false
					end

					if number < 0 then
						number = 0
					elseif number > 999999986991104 then
						number = 999999986991104
					end

					instance.Width0 = number
					return
				end,
			},
			{
				name = "Width1",
				groupIdentifier = "numberInput",
				render = input,
				set = function(instance, value)
					local number = tonumber(value)

					if not number then
						return false
					end

					if number < 0 then
						number = 0
					elseif number > 999999986991104 then
						number = 999999986991104
					end

					instance.Width1 = number
					return
				end,
			},
		},
	},
}

return class
