local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local theme = require("@src/theme")

local fusionComponents = require("@packages/fusionComponents")
local text = fusionComponents.base.text

type props = {
	Title: string,
	Description: string?,
	Content: fusion.CanBeState<any>,
	Visible: fusion.CanBeState<boolean>,
}

local function settingsListOption(props: props)
	local useColor = theme:get("App", "gray", "default", "Base")

	return New("Frame")({
		Name = "ListOption",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = props.Visible,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			New("Frame")({
				Name = "TextContainer",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(0.5, 0, 0, 0),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					text({
						Appearance = useColor("Text", true),
						Text = {
							Label = props.Title,
							Font = theme.global.font,
							TextSize = 14,
						},
						Size = UDim2.new(1, 0, 0, 16),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
						TextWrapped = true,
					}),
					props.Description and text({
						Appearance = useColor("SecondaryText", true),
						Text = {
							Label = props.Description,
							Font = theme.global.font,
							TextSize = 14,
						},
						Position = UDim2.new(0, 2, 0, 0),
						Size = UDim2.new(1, -2, 0, 14),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
						TextWrapped = true,
					}),
				},
			}),

			New("Frame")({
				Name = "ValueContainer",
				BackgroundTransparency = 1,
				Size = UDim2.new(0.5, 0, 1, 0),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					props.Content,
				},
			}),
		},
	})
end

return settingsListOption
