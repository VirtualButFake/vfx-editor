local class = {}

local input = require("@components/propertyFields/input")
function class.is(instance: Instance)
	return instance:IsA("Attachment") or instance:IsA("Part")
end

class.properties = {
	--[[{
		name = "Scale",
		render = input,
		get = function(instance)
			return 1
		end,
		set = function(instance, value) end,
	},]]
}

return class
