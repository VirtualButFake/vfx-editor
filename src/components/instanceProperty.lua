local fusion = require("@packages/fusion")
local New = fusion.New

local theme = require("@src/theme")

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text

type props = {
	Size: fusion.CanBeState<UDim2>,
	Position: fusion.CanBeState<UDim2>,
	Property: string,
	Content: fusion.CanBeState<{ GuiObject }>,
}

local function instanceProperty(props: props)
	local useColor = theme:get("InstanceTreeItem", "gray", "default", "Base")

	return New("Frame")({
        Name = "PropertyContainer",
		Size = props.Size,
		Position = props.Position,
		BackgroundTransparency = 1,
		[fusion.Children] = {
			New("UIListLayout")({
				Padding = UDim.new(0, 0),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
            text({
                Appearance = useColor("Text", true),
                Text = props.Property,
                Size = UDim2.new(0.5, 0, 0, 20),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
			New("Frame")({
                Name = "Property",
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				[fusion.Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					props.Content,
				},
			}),
		},
	})
end

return instanceProperty
