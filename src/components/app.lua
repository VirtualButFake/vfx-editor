local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New
local Out = fusion.Out

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local theme = require("@src/theme")

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button
local input = studioComponents.common.input
local frame = studioComponents.base.frame

local appTopbar = require("./appTopbar")
local instanceTreeRoot = require("./instanceTreeRoot")
local scrollingFrame = require("./scrollingFrame")

type props = {
	Items: fusion.Value<{ Instance }>,
}

local function App(props: props)
	local useColor = theme:get("App", "gray", "default", "Base")

	local selectedInstance = Value(props.Items:get()[1] or nil)
	local searchQuery = Value("")

	return New("Frame")({
		Name = "App",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			frame({
				Name = "TopbarContainer",
				Appearance = useColor("BackgroundPrimary", true),
				Size = UDim2.new(1, 0, 0, 32),
				Content = {
					New("Frame")({
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = Computed(function()
							return useColor("Stroke").color
						end),
						Position = UDim2.new(0, 0, 1, 0),
						Size = UDim2.new(1, 0, 0, 1),
					}),
					New("Frame")({
						Name = "Topbar",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						[Children] = {
							New("UIPadding")({
								PaddingBottom = UDim.new(0, 2),
								PaddingLeft = UDim.new(0, 2),
								PaddingRight = UDim.new(0, 2),
								PaddingTop = UDim.new(0, 2),
							}),
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							appTopbar({
								Items = props.Items,
								SelectedInstance = selectedInstance,
							}),
							New("Frame")({
								Name = "Buttons",
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								Size = UDim2.new(0, 0, 1, 0),
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "plus",
									}),
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "settings",
									}),
								},
							}),
						},
					}),
				},
			}),
			New("Frame")({
				Name = "InputContainer",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				[Children] = {
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 2),
					}),
					input({
						Color = "gray",
						Variant = "default",
						Placeholder = "Filter instances and properties..",
						Icon = "search",
						Size = UDim2.new(1, 0, 1, 0),
						Text = searchQuery,
					}),
				},
			}),
			frame({
				Name = "InstanceTreeContainer",
				Size = UDim2.new(1, -8, 1, -72),
				Appearance = useColor("BackgroundPrimary", true),
				Stroke = useColor("Stroke", true),
				Padding = UDim.new(0, 4),
				Content = {
					scrollingFrame({
						Size = UDim2.new(1, 0, 1, 0),
						ScrollingFrameProps = {
							VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
						},
						Content = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Top,
							}),
							New("UIPadding")({
								PaddingRight = UDim.new(0, 4),
							}),
							Computed(function()
								return instanceTreeRoot({
									RootInstance = selectedInstance:get(),
									Query = searchQuery,
									MaxDepth = 3,
								})
							end, Clean),
						},
					}),
				},
			}),
		},
	})
end

return App
