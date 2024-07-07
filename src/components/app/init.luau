local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button
local input = studioComponents.common.input
local frame = studioComponents.base.frame
local tooltip = studioComponents.common.tooltip
local modal = studioComponents.common.modal
local selectMenu = studioComponents.common.selectMenu

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

local signal = require("@packages/signal")

local theme = require("@src/theme")

local historyHandler = require("@src/lib/historyHandler")

local newInstanceModal = require("./newInstanceModal")
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

	local selectedInstance = Value(props.Items:get(false)[1] or nil)

	local searchQuery = Value("")
	local searchMode = Value({ "properties" })

	local newInstanceTarget = nil
	local isPlusModalVisible = Value(false)

	local sharedContextMenuState = Value(false)

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
					ForPairs(props.Items, function(index, value)
                        local events = {
                            OnItemClicked = signal.new(),
                            OnPlusClicked = signal.new(),
                            AddTab = signal.new(),
                        } :: instanceTreeRoot.events

                        -- no need to clean these up; instancetreeroot cleans up all of the signals when destroyed
                        events.OnPlusClicked:Connect(function(instance)
                            newInstanceTarget = instance
                            isPlusModalVisible:set(true)
                        end)

                        events.AddTab:Connect(function(instance)
                            local oldItems = table.clone(props.Items:get())

                            if table.find(oldItems, instance) then
                                return
                            end

                            table.insert(oldItems, instance)
                            props.Items:set(oldItems)
                            selectedInstance:set(instance)
                        end)

						return index,
							instanceTreeRoot({
								RootInstance = value,
								Query = searchQuery,
                                SearchMode = searchMode,
								MaxDepth = 3,
								SharedContextMenuState = sharedContextMenuState,
								Visible = Computed(function()
									return selectedInstance:get() == value
								end),
                                Events = events,
							})
					end, Clean),
				},
				ScrollingFrameProps = {
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				},
				Size = UDim2.new(1, 0, 1, 0),
			}),
		},
	})

	modal(instanceTreeContainerFrame, {
		Visible = isPlusModalVisible,
		Content = newInstanceModal({
			useColor = useColor,
			OnClose = function()
				isPlusModalVisible:set(false)
			end,
			OnCreate = function(name, class)
				isPlusModalVisible:set(false)

				historyHandler("Create Instance", function()
					local new = Instance.new(class)
					new.Name = name
					new.Parent = newInstanceTarget
				end)
			end,
		}),
		OnClickBesides = function()
			isPlusModalVisible:set(false)
		end,
		Padding = UDim.new(0, 8),
	})

	local isWidgetEnabled = Value(false)
	local textureWidget

	local component = topLayerProvider.new(New("Frame")({
		Name = "App",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Cleanup] = {
			function()
				if textureWidget then
					textureWidget:Destroy()
				end
			end,
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
								SharedContextMenuState = sharedContextMenuState,
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
										OnClick = function()
											if Selection:Get()[1] then
												-- create new tab with selected instance
												local oldItems = table.clone(props.Items:get())
												local newItem = Selection:Get()[1]

												if table.find(oldItems, newItem) then
													return
												end

												table.insert(oldItems, newItem)
												props.Items:set(oldItems)
											end
										end,
									}),
									tooltip(
										button({
											Color = "white",
											Variant = "ghost",
											Icon = "images",
											OnClick = function()
												if textureWidget == nil then
													textureWidget = widget({
														Name = "Texture Storage",
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
																			Path = Value({ "Home" }),
																		})),
																	})[1]
																end

																return
															end, Clean),
														},
													})
												end

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
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					selectMenu({
						Color = "gray",
						Variant = "default",
						Size = UDim2.new(0, 128, 1, 0),
						MaxHeight = 2,
						SelectedOptions = searchMode,
						Options = {
							{
								Id = "instance",
								Label = "Instance",
								Icon = "cuboid",
							},
							{
								Id = "properties",
								Label = "Properties",
								Icon = "table-properties",
							},
						},
					}),
					input({
						Color = "gray",
						Variant = "default",
						Placeholder = Computed(function()
                            return searchMode:get()[1] == "instance" and "Search instances.." or "Search properties.."
                        end),
						Icon = "search",
						Size = UDim2.new(1, -132, 1, 0),
						Text = searchQuery,
						OnTextChanged = function(text)
							searchQuery:set(text)
						end,
					}),
				},
			}),
			instanceTreeContainerFrame,
		},
	}))

	return component
end

return App
