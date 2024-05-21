local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New
local Out = fusion.Out
local Ref = fusion.Ref

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local theme = require("@src/theme")
local tailwind = require("@packages/tailwind")

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button
local input = studioComponents.common.input
local frame = studioComponents.base.frame

local appTopbar = require("./appTopbar")
local instanceTreeRoot = require("./instanceTreeRoot")

type props = {
	Items: fusion.Value<{ Instance }>,
}

local function App(props: props)
	local useColor = theme:get("App", "gray", "default", "Base")

	local selectedInstance = Value(props.Items:get()[1] or nil)
	local searchQuery = Value("")

	local scrollingFrameAbsoluteSize = Value(Vector2.new(0, 0))
	local scrollingFrameCanvasSize = Value(Vector2.new(0, 0))

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
					frame({
						Name = "ScrollbarBackground",
						Appearance = useColor("ScrollBarBackground", true),
						Stroke = useColor("Stroke", true),
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.new(0, 6, 1, 0),
						ZIndex = 0,
						Visible = Computed(function()
                            if not scrollingFrameCanvasSize:get() or not scrollingFrameAbsoluteSize:get()  then
                                return false
                            end

							return scrollingFrameCanvasSize:get().Y > scrollingFrameAbsoluteSize:get().Y
						end),
					}),
					New("ScrollingFrame")({
						Name = "InstanceTreeScroller",
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BottomImage = "rbxassetid://17569049896",
						CanvasSize = UDim2.fromScale(0, 0),
						MidImage = "rbxassetid://17568857612",
						ScrollBarImageColor3 = Computed(function()
							return useColor("ScrollBar").color
						end),
						ScrollBarThickness = 6,
						Size = UDim2.new(1, 0, 1, 0),
						TopImage = "rbxassetid://17569049728",
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						[Out("AbsoluteSize")] = scrollingFrameAbsoluteSize,
						[Out("AbsoluteCanvasSize")] = scrollingFrameCanvasSize,
						[Children] = {
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
