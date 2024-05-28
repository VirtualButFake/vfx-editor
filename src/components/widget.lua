local PluginDebugService = game:GetService("PluginDebugService")

local fusion = require("@packages/fusion")
local Hydrate = fusion.Hydrate

local plugin = script:FindFirstAncestorWhichIsA("Plugin") or PluginDebugService:FindFirstChild("plugin") :: Plugin?

type props = {
	Id: string,
	Name: string,
	InitialDockTo: Enum.InitialDockState,
	InitialEnabled: boolean,
	ForceInitialEnabled: boolean,
	FloatingSize: Vector2,
	MinimumSize: Vector2,
	[any]: any,
}

-- from https://github.com/mvyasu/PluginEssentials/blob/main/src/PluginComponents/Widget.lua
local COMPONENT_ONLY_PROPERTIES = {
	"Id",
	"InitialDockTo",
	"InitialEnabled",
	"ForceInitialEnabled",
	"FloatingSize",
	"MinimumSize",
	"Plugin",
}

local function pluginWidget(props: props)
	if plugin == nil then
		warn("Attempted to create widget but plugin is nil!")
		return nil
	end

	if props.ZIndexBehavior == nil then
		props.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end

	local newWidget = plugin:CreateDockWidgetPluginGui(
		props.Id,
		DockWidgetPluginGuiInfo.new(
			props.InitialDockTo,
			props.InitialEnabled,
			props.ForceInitialEnabled,
			props.FloatingSize.X,
			props.FloatingSize.Y,
			props.MinimumSize.X,
			props.MinimumSize.Y
		)
	)

	for _, propertyName in COMPONENT_ONLY_PROPERTIES do
		props[propertyName] = nil
	end

	props.Title = props.Name

	if typeof(props.Enabled) == "table" and props.Enabled.kind == "Value" then
		props.Enabled:set(newWidget.Enabled)
	end

	return Hydrate(newWidget)(props)
end

return pluginWidget
