local fusion = require("@packages/fusion")
local Children = fusion.Children
local Hydrate = fusion.Hydrate
local New = fusion.New

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

local getPropertiesForInstance = require("@src/lib/getPropertiesForInstance")

local instanceTreeItem = require("@src/components/instanceTreeItem")

type line = "Horizontal" | "StartVertical" | "Vertical" -- startvertical = half vertical line

type instanceMapEntry = {
	instance: Instance,
	children: { instanceMapEntry },
	properties: { getPropertiesForInstance.category | getPropertiesForInstance.property },
	linesStart: { line },
	linesCascading: { [number]: { line } },
	isVisible: boolean,
}

type props = {
	RootInstance: Instance,
	Query: fusion.CanBeState<string>,
	SearchMode: fusion.CanBeState<{ string }>,
	MaxDepth: number,
	OnPlusClicked: (instance: Instance) -> (),
	SharedContextMenuState: fusion.Value<boolean | fusion.Value<boolean>>,
	AddTab: (instance: Instance) -> (),
}

local function instanceTree(props: props)

	local component = New("Frame")({
		Name = "InstanceTreeRoot",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		[Children] = {
			instanceTreeItem({
				LayoutOrder = 0,
				Instance = props.RootInstance,
				Query = props.Query,
				SearchMode = props.SearchMode,
				AddTab = props.AddTab,
				Depth = 0,
				MaxDepth = props.MaxDepth,
				OnPlusClicked = props.OnPlusClicked,
				OpenedContextMenu = props.SharedContextMenuState,
			}),
		},
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "Frame"))
end

return instanceTree
