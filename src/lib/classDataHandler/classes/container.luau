local class = {}

local fusionUtils = require("@packages/fusionUtils")
local onDestroy = fusionUtils.onDestroy

local input = require("@components/propertyFields/input")

local scaleUtils = require("@src/lib/scaleUtils")

function class.is(instance: Instance)
	return instance:IsA("Attachment") or instance:IsA("Part") or instance:IsA("Model") or instance:IsA("Folder")
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
		set = function(instance: Instance, value)
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
}

return class
