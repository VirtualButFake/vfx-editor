local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button
local input = studioComponents.common.input
local frame = studioComponents.base.frame
local tooltip = studioComponents.common.tooltip

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

local theme = require("@src/theme")

local appTopbar = require("@components/appTopbar")
local instanceTreeRoot = require("@components/instanceTreeRoot")
local scrollingFrame = require("@components/scrollingFrame")
local widget = require("@components/widget")
local texturePicker = require("@components/propertyFields/texturePicker/editor")

type props = {
	Items: fusion.Value<{ Instance }>,
}

local function App(props: props)
	local useColor = theme:get("App", "gray", "default", "Base")

	local selectedInstance = Value(props.Items:get()[1] or nil)
	local searchQuery = Value("")

	local instanceTreeContainerFrame = frame({
		Name = "InstanceTreeContainer",
		Size = UDim2.new(1, -8, 1, -72),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Appearance = useColor("TreeBackground", true),
		Stroke = useColor("Stroke", true),
		Padding = UDim.new(0, 4),
		Content = {
			scrollingFrame({
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
					New("Frame")({
						Name = "Padding",
						BackgroundTransparency = 1,
						Size = UDim2.new(0, 0, 0, 128),
					}),
				},
				ScrollingFrameProps = {
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				},
				Size = UDim2.new(1, 0, 1, 0),
			}),
		},
	})

	local instanceTreeContainer = topLayerProvider.new(instanceTreeContainerFrame)

	local isWidgetEnabled = Value(false)
	local textureWidget = widget({
		Name = `Texture Storage`,
		Id = HttpService:GenerateGUID(),
		InitialDockTo = Enum.InitialDockState.Float,
		InitialEnabled = false,
		ForceInitialEnabled = true,
		FloatingSize = Vector2.new(575, 408),
		MinimumSize = Vector2.new(400, 300),
		Enabled = isWidgetEnabled,
		[Children] = {
			Computed(function()
				local widgetEnabled = isWidgetEnabled:get()

				if widgetEnabled then
					return ({
						topLayerProvider.new(texturePicker({
							IsSelectingImage = false,
							Path = Value(""),
						})),
					})[1]
				end

				return
			end, Clean),
		},
	})

	local component = New("Frame")({
		Name = "App",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Cleanup] = {
			textureWidget,
		},
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
				Appearance = useColor("TopbarBackground", true),
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
									tooltip(
										button({
											Color = "white",
											Variant = "ghost",
											Icon = "images",
											OnClick = function()
												isWidgetEnabled:set(true)
											end,
										}),
										{
											Variant = "default",
											Text = "Open Texture Storage\n\n<b>(hold ctrl or shift to select multiple items)</b>",
											Placement = "bottom",
											RelativePosition = UDim2.new(0, -35, 0, 0),
										}
									),
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
						Placeholder = "Filter properties..",
						Icon = "search",
						Size = UDim2.new(1, 0, 1, 0),
						Text = searchQuery,
					}),
				},
			}),
			instanceTreeContainer,
		},
	})

	return component
end

return App
