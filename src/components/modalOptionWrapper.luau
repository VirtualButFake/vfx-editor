local fusion = require("@packages/fusion")
local New = fusion.New

local theme = require("@src/theme")

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text

type props = {
	OptionName: string,
	Content: fusion.CanBeState<{ GuiObject }>,
}

local function modalOptionWrapper(props: props)
	local useColor = theme:get("InstanceTreeItem", "gray", "default", "Base")

	return New("Frame")({
		Name = "ModalOptionWrapper",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
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
				Text = props.OptionName,
				Size = UDim2.new(0.35, 0, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			New("Frame")({
				Name = "ValueContainer",
				Size = UDim2.new(0.65, 0, 1, 0),
				BackgroundTransparency = 1,
				[fusion.Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					props.Content,
				},
			}),
		},
	})
end

return modalOptionWrapper
