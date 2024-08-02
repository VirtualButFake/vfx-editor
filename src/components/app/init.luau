local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Spring = fusion.Spring

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Out = fusion.Out
local Ref = fusion.Ref

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.common.button
local input = fusionComponents.common.input
local frame = fusionComponents.base.frame
local tooltip = fusionComponents.common.tooltip
local modal = fusionComponents.common.modal
local selectMenu = fusionComponents.common.selectMenu
local canvasFrame = fusionComponents.utility.canvasFrame
local scrollingFrame = fusionComponents.common.scrollingFrame
local baseText = fusionComponents.base.text

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

local signal = require("@packages/signal")
local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

local historyHandler = require("@src/lib/historyHandler")
local settingsManager = require("@src/lib/settingsManager")
local classDataHandler = require("@src/lib/classDataHandler")

local newInstanceModal = require("./newInstanceModal")
local settingsMenu = require("./settings")
local appTopbar = require("@components/appTopbar")
local instanceTreeRoot = require("@components/instanceTreeRoot")
local widget = require("@components/widget")
local texturePicker = require("@components/propertyFields/texturePicker/editor")
local standaloneScroller = require("@components/standaloneScroller")

type props = {
	Items: fusion.Value<{ Instance }>,
}

local ENABLE_VIRTUAL_SCROLLER = settingsManager.getReactiveWithFallback("enable_virtual_scroller", true)
local LIGHTWEIGHT_MODE = settingsManager.getReactiveWithFallback("lightweight_mode", false)

local function App(props: props)
	local useColor = theme:get("App", "gray", "default", "Base")

	local _, firstValue = next(props.Items:get(false))
	local selectedInstance = Value(firstValue or nil)
	local childrenReplacement = Value({}) -- for lightweight mode

	local searchQuery = Value("")
	local searchMode = Value({ "properties" })

	local newInstanceTarget = nil
	local isPlusModalVisible = Value(false)

	local settingsMenuVisible = Value(false)
	local settingsMenuTransparency = Spring(
		Computed(function()
			return settingsMenuVisible:get() and 0 or 1
		end),
		30,
		1
	)

	local sharedContextMenuState = Value(false)
	local listContentSize = Value()
	local scrollFrame = scrollingFrame({
		Content = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				[Out("AbsoluteContentSize")] = listContentSize,
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

				local isSelected = Computed(function()
					return selectedInstance:get() == value or LIGHTWEIGHT_MODE:get()
				end)

				local maxDepth = LIGHTWEIGHT_MODE:get() and 0
					or settingsManager.getReactiveWithFallback("max_depth", 3):get()

				return index,
					instanceTreeRoot({
						RootInstance = value,
						Query = searchQuery,
						ChildrenReplacement = LIGHTWEIGHT_MODE:get() and childrenReplacement or nil,
						Events = events,
						IsSelfSelected = isSelected,
						MaxDepth = maxDepth,
						SearchMode = searchMode,
						SharedContextMenuState = sharedContextMenuState,
						Visible = isSelected,
					})
			end, Clean),
		},
		ScrollingFrameProps = {
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			CanvasSize = Computed(function()
				if listContentSize:get() == nil then
					return UDim2.new(0, 0, 0, 0)
				end

				return UDim2.new(0, 0, 0, listContentSize:get().Y)
			end),
		},
		Size = UDim2.new(1, 0, 1, 0),
	})

	local instanceTreeContainerFrame = topLayerProvider.new(frame({
		Name = "InstanceTreeContainer",
		Size = Computed(function()
			if LIGHTWEIGHT_MODE:get() then
				-- topbar goes away, so we get +32 - 4 px extra
				return UDim2.new(1, -8, 1, -40)
			end

			return UDim2.new(1, -8, 1, -72)
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Appearance = useColor("TreeBackground", true),
		Stroke = useColor("Stroke", true),
		Padding = UDim.new(0, 4),
		Content = {
			Computed(function()
				if LIGHTWEIGHT_MODE:get() then
					return nil
				end

				local countedItems = 0

				for _ in (props.Items:get()) do
					countedItems = countedItems + 1
				end

				if countedItems > 0 then
					return
				end

				-- text + button to automatically create a new instance
				-- this instance is just a part + attachment created near in front of the camera
				-- it's automatically added and selected
				return New("Frame")({
					Name = "NoItemPrompt",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					[Children] = {
						New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						baseText({
							Appearance = useColor("Text", true),
							Text = {
								Label = "There are no selected items. Click the plus button in the top right to add your currently selected instance to the editor, or click the button below to quickly create a basic instance.",
								TextSize = 18,
								Font = theme.global.font,
							},
							TextWrapped = true,
							Size = UDim2.new(1, 0, 0, 24),
							AutomaticSize = Enum.AutomaticSize.Y,
							TextXAlignment = Enum.TextXAlignment.Center,
						}),
						button({
							Color = "white",
							Variant = "solid",
							AutomaticSize = Enum.AutomaticSize.XY,
							ButtonText = "Create New Instance",
							OnClick = function()
								local instance = Instance.new("Part")
								instance.Size = Vector3.new(1, 1, 1)
								instance.Position = (workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -5)).Position
								instance.Anchored = true
								instance.Transparency = 1

								local attachment = Instance.new("Attachment")
								attachment.Parent = instance

								local particleEmitter = Instance.new("ParticleEmitter")
								particleEmitter.Parent = attachment

								instance.Parent = workspace

								props.Items:set({ instance })
								selectedInstance:set(instance)
							end,
						}),
					},
				})
			end, Clean),
			ENABLE_VIRTUAL_SCROLLER:get() and standaloneScroller.frame(scrollFrame) or scrollFrame,
		},
	}))

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

	local topbarContainer = Value()
	local inputContainer = Value()

	local buttonContainer = New("Frame")({
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
			Computed(function()
				if LIGHTWEIGHT_MODE:get() then
					local meetsCondition = false

					if typeof(childrenReplacement:get()) == "table" then
						for _, instance in (childrenReplacement:get()) do
							local _, className = classDataHandler.getProperties(instance)

							if className ~= "trail" and className ~= nil then
								meetsCondition = true
								break
							end
						end

						return
					end

					if meetsCondition then
						return tooltip(
							button({
								Color = "white",
								Variant = "ghost",
								Icon = "play",
								LayoutOrder = -1,
								OnClick = function()
									if typeof(childrenReplacement:get()) == "table" then
										for _, instance in selectedInstance:get(false) do
											classDataHandler.emit(instance)
										end
									else
										classDataHandler.emit(selectedInstance:get(false))
									end
								end,
							}),
							{
								Variant = "default",
								Text = "Emit",
								Placement = "bottom",
							}
						)
					end

					return
				end

				return button({
					Color = "white",
					Variant = "ghost",
					Icon = "plus",
					LayoutOrder = -1,
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
				})
			end, Clean),
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
			button({
				Color = "white",
				Variant = "ghost",
				Icon = "settings",
				OnClick = function()
					settingsMenuVisible:set(true)
				end,
			}),
		},
	})

	local function updateButtonParent()
		task.delay(0.1, function()
			if LIGHTWEIGHT_MODE:get() then
				buttonContainer.Parent = inputContainer:get()
			else
				buttonContainer.Parent = topbarContainer:get()
			end
		end)
	end

	local selectionChangedConnection

	local function updateSelectionMode()
		if selectionChangedConnection then
			selectionChangedConnection:Disconnect()
			selectionChangedConnection = nil
		end

		if LIGHTWEIGHT_MODE:get() then
			childrenReplacement:set(Selection:Get())

			selectionChangedConnection = Selection.SelectionChanged:Connect(function()
				print("Changed")
				childrenReplacement:set(Selection:Get())
			end)
		end
	end

	updateSelectionMode()

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
			Observer(LIGHTWEIGHT_MODE):onChange(updateSelectionMode),
			Observer(LIGHTWEIGHT_MODE):onChange(updateButtonParent),
			selectionChangedConnection,
			buttonContainer,
		},
		[Children] = {
			canvasFrame({
				Name = "SettingsContainer",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
				GroupTransparency = settingsMenuTransparency,
				Children = settingsMenu({
					SettingsVisible = settingsMenuVisible,
					useColor = useColor,
				}),
			}),
			New("Frame")({
				Name = "MainAppContainer",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Visible = Computed(function()
					if settingsMenuTransparency:get() < 0.1 then
						return false
					end

					return true
				end),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					Computed(function()
						if LIGHTWEIGHT_MODE:get() then
							return New("UIPadding")({
								PaddingTop = UDim.new(0, 4),
							})
						end

						return frame({
							Name = "TopbarContainer",
							Appearance = useColor("TopbarBackground", true),
							Size = UDim2.new(1, 0, 0, 32),
							LayoutOrder = -1,
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
									[Ref] = topbarContainer,
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
											LayoutOrder = -1,
											SelectedInstance = selectedInstance,
											SharedContextMenuState = sharedContextMenuState,
										}),
									},
								}),
							},
						})
					end, function(...)
						if LIGHTWEIGHT_MODE:get() then
							-- to prevent it from being cleaned up
							buttonContainer.Parent = inputContainer:get()
						end

						return Clean(...)
					end),
					New("Frame")({
						Name = "InputContainer",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 28),
						[Ref] = inputContainer,
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
								HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							Computed(function()
								if LIGHTWEIGHT_MODE:get() then
									searchMode:set({ "properties" })
									return nil
								end

								return selectMenu({
									Color = "gray",
									Variant = "default",
									AppearanceOverride = {
										_global = {
											Background = Computed(function()
												return theme.global.isDark:get() and tailwind.neutral[800]
													or Color3.fromRGB(255, 255, 255)
											end),
										},
									},
									Size = UDim2.new(0, 128, 1, 0),
									MaxHeight = 2,
									SelectedOptions = searchMode,
									OnOptionClicked = function(id, isVisible)
										searchMode:set({ id })
										isVisible:set(false)
									end,
									Options = {
										{
											Id = "properties",
											Label = "Properties",
											Icon = "table-properties",
										},
										Computed(function()
											return not LIGHTWEIGHT_MODE:get()
													and {
														Id = "instance",
														Label = "Instance",
														Icon = "cuboid",
													}
												or nil
										end),
									},
									LayoutOrder = -1,
								})
							end, Clean),
							input({
								Color = "gray",
								Variant = "default",
								AppearanceOverride = {
									_global = {
										Background = Computed(function()
											return theme.global.isDark:get() and tailwind.neutral[800]
												or Color3.fromRGB(255, 255, 255)
										end),
									},
								},
								Placeholder = Computed(function()
									return searchMode:get()[1] == "instance" and "Search instances.."
										or "Search properties.."
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
			}),
		},
	}))

	updateButtonParent()

	return component
end

return App
