local classDataHandler = {}

local fusion = require("@packages/fusion")

local theme = require("@src/theme")

local classMap: {
	[string]: {
		is: (instance: Instance) -> boolean,
		properties: {
			[number]: property | category,
		},
		emit: (instance: Instance) -> nil,
	},
} =
	nil :: any

local function setup()
	local classes = script.classes:GetChildren()
	classMap = {}

	for _, class in classes do
		classMap[class.Name] = require(class)
	end
end

function classDataHandler.getProperties(instance: Instance): ({ [number]: category }?, string?)
	if not classMap then
		setup()
	end

	for idx, class in classMap do
		if class.is(instance) then
			return class.properties, idx
		end
	end

	return nil, nil
end

function classDataHandler.emit(instance: Instance)
	if not classMap then
		setup()
	end

	for _, class in classMap do
		if class.is(instance) and class.emit then
			class.emit(instance)
			break
		end
	end
end

export type property = {
	name: string,
	groupIdentifier: string?,
	render: (
		{
			Instance: Instance,
			PropertyName: string,
			Value: fusion.Value<any>,
			Events: { [string]: BindableEvent },
		},
		useColor: theme.useColorFunction,
		properties: processedProperties
	) -> nil,
	get: (instance: Instance) -> any,
	set: (instance: Instance, value: any) -> nil,
	clipboardGet: ({
		Instance: Instance,
		PropertyName: string,
		Value: fusion.Value<any>,
	}) -> nil,
	clipboardSet: (
		{
			Instance: Instance,
			PropertyName: string,
			Value: fusion.Value<any>,
		},
		value: any
	) -> nil,
}

export type category = {
	name: string,
	properties: { [number]: property },
}

export type processedProperties = {
	[string]: fusion.Value<any>,
}

return classDataHandler
