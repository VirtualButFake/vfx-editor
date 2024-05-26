local theme = require("@src/theme")

local fusion = require("@packages/fusion")

local classes = script.classes:GetChildren()
local classMap: {
	[string]: {
		is: (instance: Instance) -> boolean,
		properties: {
			[number]: property,
		},
	},
} =
	{}

for _, class in classes do
	classMap[class.Name] = require(class)
end

local function getPropertiesForInstance(instance: Instance): { [number]: property }?
	for _, class in classMap do
		if class.is(instance) then
			return class.properties
		end
	end

	return nil
end

type property = {
	name: string,
	render: (
		{
			Instance: Instance,
			PropertyName: string,
			Value: fusion.Value<any>,
		},
		properties: processedProperties,
		useColor: theme.useColorFunction
	) -> nil,
	get: (instance: Instance) -> any,
	set: (instance: Instance, value: any) -> nil,
}

export type processedProperties = {
	[string]: fusion.Value<any>,
}

return getPropertiesForInstance
