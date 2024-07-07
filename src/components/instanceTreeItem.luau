local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Out = fusion.Out

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local ForValues = fusion.ForValues
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local baseIcon = studioComponents.base.icon
local baseImageLabel = studioComponents.base.imageLabel
local baseText = studioComponents.base.text
local button = studioComponents.common.button
local contextMenu = studioComponents.common.contextMenu

local fusionUtils = require("@packages/fusionUtils")
local peek = fusionUtils.peek
local awaitLayer = fusionUtils.awaitLayer

local signal = require("@packages/signal")

local theme = require("@src/theme")

local getPropertiesForInstance = require("@src/lib/getPropertiesForInstance")
local historyHandler = require("@src/lib/historyHandler")

local listOption = require("@src/components/listOption")

local function tableFindIter(t, v): number?
	for i, value in t do
		if value == v then
			return i
		end
	end

	return nil
end

export type line = "Horizontal" | "HalfVertical" | "StartVertical" | "Vertical" -- startvertical = half vertical line

export type instanceMapEntry = {
	instance: Instance,
	children: { instanceMapEntry },
	properties: { getPropertiesForInstance.category | getPropertiesForInstance.property },
	linesStart: { line },
	linesCascading: { [number]: { line } },
}

-- export this type up the chain so that we dont have to redefine the types
export type events = {
	OnItemClicked: signal.Signal<Instance>,
	OnPlusClicked: signal.Signal<Instance>,
	AddTab: signal.Signal<Instance>,
}

type props = {
	LayoutOrder: number,
	Instance: Instance,
	Query: fusion.Value<string>,
	SearchMode: fusion.Value<{ string }>,
	OpenedContextMenu: fusion.Value<boolean | fusion.Value<boolean>>,
	Depth: number,
	MaxDepth: number,
	TreeContext: {
		Children: fusion.Value<{ Instance }>,
		Lines: fusion.Value<{ [number]: string }>,
	}?,
	SharedSelectedPropertyState: fusion.Value<{ [Instance]: { string } }>,
	InstanceMap: fusion.Computed<instanceMapEntry>,
	Events: events,
}

local TREE_TAB_SIZE = 24
local ALLOWED_CLASSNAMES = {
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Attachment",
}

local function instanceTreeItem(props: props)
	local useColor = theme:get("InstanceTreeItem", "gray", "default", "Base")

	-- recursively iterate through instancemap to find ourselves
	local function findInstanceInMap(map: instanceMapEntry, instance: Instance): instanceMapEntry?
		if map.instance == instance then
			return map
		end

		for _, child in map.children do
			local found = findInstanceInMap(child, instance)

			if found then
				return found
			end
		end

		return nil
	end

	local instanceInMap = Computed(function()
		return findInstanceInMap(props.InstanceMap:get(), props.Instance)
	end)

	local cascadingLines = Computed(function()
		if instanceInMap:get() == nil then
			return {}
		end

		return instanceInMap:get().linesCascading
	end)

	local lineState = Computed(function()
		if instanceInMap:get() == nil or props.Depth == 0 then
			return {}
		end

		return instanceInMap:get().linesStart
	end)

	local function makeLine(type: string): GuiObject?
		if type == "Vertical" then
			return New("Frame")({
				Name = "Vertical",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0.5, -2),
				Size = UDim2.new(0, 1, 1, 4),
			})
		elseif type == "StartVertical" then
			return New("Frame")({
				Name = "StartVertical",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0, 1, 1, 2),
			})
		elseif type == "Horizontal" then
			return New("Frame")({
				Name = "Horizontal",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.new(1, -4, 0, 1),
			})
		elseif type == "HalfVertical" then
			return New("Frame")({
				Name = "HalfVertical",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0, -2),
				Size = UDim2.new(0, 1, 0.5, 2),
			})
		end

		return nil
	end

	local instanceName = Value(props.Instance.Name)
	local instanceCategories, className = getPropertiesForInstance(props.Instance)

	local onNameChanged = props.Instance:GetPropertyChangedSignal("Name"):Connect(function()
		instanceName:set(props.Instance.Name)
	end)

	-- make this stateful, so that fields can check on existence of the property and react when it is added
	local processedProperties: fusion.Value<getPropertiesForInstance.processedProperties> = fusion.Value({})

	local showSubContent = Value(true)

	local children = Value(props.Instance:GetChildren())
	local classIcon = theme.getClassIcon(props.Instance.ClassName)

	local isContextMenuVisible = Value(false)

	local function closeSelf()
		isContextMenuVisible:set(false)

		if props.OpenedContextMenu:get() == isContextMenuVisible then
			props.OpenedContextMenu:set(false)
		end
	end

	local lastClick = 0

	local isCtrlHeld = Value(false)
	local keyConnections = {}

	local component = New("Frame")({
		Name = "InstanceTreeItem",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = Computed(function()
			if props.SearchMode:get()[1] == "instance" and props.Query:get() ~= "" then
				if string.find(props.Instance.Name:lower(), props.Query:get():lower()) then
					return true
				end

				-- recursively search through all children, see if any of them are visible
				local function searchChildren(entry: instanceMapEntry?): boolean
					if entry == nil then
						return false
					end

					local doesEntryMatch = string.find(entry.instance.Name:lower(), props.Query:get():lower())

					if doesEntryMatch then
						return true
					end

					for _, child in entry.children do
						if searchChildren(child) then
							return true
						end
					end

					return false
				end

				return searchChildren(instanceInMap:get())
			elseif props.SearchMode:get()[1] == "properties" and props.Query:get() ~= "" then
				-- recursively iterate through all instance maps, see if any of the properties or categories match
				local function searchProperties(entry: instanceMapEntry?): boolean
					if entry == nil then
						return false
					end

					if entry.properties then
						for _, category in entry.properties do
							if string.find(category.name:lower(), props.Query:get():lower()) then
								return true
							end

							if category.properties then
								for _, property in category.properties do
									if string.find(property.name:lower(), props.Query:get():lower()) then
										return true
									end
								end
							end
						end
					end

					for _, child in entry.children do
						if searchProperties(child) then
							return true
						end
					end

					return false
				end

				return searchProperties(instanceInMap:get())
			end

			return true
		end),
		[Cleanup] = {
			keyConnections,
			onNameChanged,
			props.Instance.ChildAdded:Connect(function(child)
				if not game:IsAncestorOf(props.Instance) then
					return
				end

				local newChildren = children:get()
				table.insert(newChildren, child)
				children:set(newChildren, true)
			end),
			props.Instance.ChildRemoved:Connect(function(child)
				if not game:IsAncestorOf(props.Instance) then
					return
				end

				local newChildren = children:get()
				local childIndex = tableFindIter(newChildren, child)

				if not childIndex then
					return
				end

				-- this might seem weird at first, but Fusion plays a LOT better with us having an empty index instead of
				-- moving all 1 down, resulting in a rerender, etc
				newChildren[childIndex] = nil
				children:set(newChildren, true)
			end),
		},
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("Frame")({
				Name = "MainContent",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				ZIndex = 2,
				[Children] = {
					New("Frame")({
						Name = "LineContainer",
						BackgroundTransparency = 1,
						Size = UDim2.new(0, props.Depth * TREE_TAB_SIZE, 1, 2),
						[Children] = {
							Computed(function()
								if #lineState:get() > 0 then
									return New("Frame")({
										Name = tostring(props.Depth),
										BackgroundTransparency = 1,
										Position = UDim2.new(
											0,
											math.clamp((props.Depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 10,
											0,
											0
										),
										Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
										[Children] = {
											ForValues(lineState, function(value)
												return makeLine(value)
											end, Clean),
										},
									})
								end

								return nil
							end, Clean),
							ForPairs(cascadingLines, function(depth, states)
								if depth >= props.Depth then
									return depth, nil
								end

								return depth,
									New("Frame")({
										Name = tostring(depth),
										BackgroundTransparency = 1,
										Position = UDim2.new(
											0,
											math.clamp((depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 10,
											0,
											0
										),
										Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
										[Children] = {
											ForPairs(states, function(index, value)
												return index, makeLine(value)
											end, Clean),
										},
									})
							end, Clean),
						},
					}),
					contextMenu(
						button({
							Color = "neutral",
							Variant = "ghost",
							DisableHoverLighting = true,
							AutomaticSize = Enum.AutomaticSize.None,
							Name = "Header",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, 0),
							Size = UDim2.new(1, -props.Depth * TREE_TAB_SIZE, 1, 0),
							ContentFullSize = true,
							OnClick = function()
								local now = tick()

								if now - lastClick < 0.35 then
									props.Events.AddTab:Fire(props.Instance)
								end

								lastClick = now
								props.Events.OnItemClicked:Fire(props.Instance)
							end,
							Content = {
								New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									HorizontalAlignment = Enum.HorizontalAlignment.Left,
									Padding = UDim.new(0, 0),
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								New("Frame")({
									Name = "Content",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									Size = UDim2.new(0, 0, 0, 0),
									[Children] = {
										New("UIFlexItem")({
											FlexMode = Enum.UIFlexMode.Fill,
										}),
										New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											Padding = UDim.new(0, 4),
											SortOrder = Enum.SortOrder.LayoutOrder,
											VerticalAlignment = Enum.VerticalAlignment.Center,
										}),
										baseImageLabel({
											Name = "Icon",
											Image = Computed(function()
												return classIcon:get().Image
											end),
											ImageRectSize = Computed(function()
												return classIcon:get().ImageRectSize
											end),
											ImageRectOffset = Computed(function()
												return classIcon:get().ImageRectOffset
											end),
											Appearance = useColor("Text", true),
											Size = UDim2.new(0, 16, 0, 16),
											LayoutOrder = 0,
										}),
										baseText({
											Name = "Text",
											Appearance = useColor("Text", true),
											Text = instanceName,
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
										}),
									},
								}),
								New("Frame")({
									Name = "Buttons",
									BackgroundTransparency = 1,
									Size = UDim2.new(0, 0, 1, 0),
									[Children] = {
										New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											HorizontalAlignment = Enum.HorizontalAlignment.Right,
											Padding = UDim.new(0, 2),
											SortOrder = Enum.SortOrder.LayoutOrder,
											VerticalAlignment = Enum.VerticalAlignment.Center,
										}),
										New("UIFlexItem")({
											FlexMode = Enum.UIFlexMode.Fill,
										}),
										className ~= "trail" and button({
											Color = "white",
											Variant = "ghost",
											Icon = "play",
											Margin = 2,
										}) or nil,
										Computed(function()
											if
												not instanceCategories
												or instanceInMap:get() == nil
												or #instanceCategories == 0 and #instanceInMap:get().children == 0
											then
												return nil
											end

											return button({
												Color = "white",
												Variant = "ghost",
												OnClick = function()
													showSubContent:set(not showSubContent:get())
												end,
												Content = Computed(function()
													return baseIcon({
														Icon = {
															Name = showSubContent:get() and "chevron-up"
																or "chevron-down",
															Size = 16,
														},
														Color = useColor("Text", true),
													})
												end, Clean),
												Margin = 2,
											})
										end, Clean),
									},
								}),
							},
						}),
						{
							Color = "gray",
							Variant = "default",
							Visible = isContextMenuVisible,
							EnabledLogic = function(isEnabled)
								local currentState = props.OpenedContextMenu:get()

								if isEnabled then
									if typeof(currentState) ~= "boolean" then
										currentState:set(false)
									end

									isContextMenuVisible:set(true)
									props.OpenedContextMenu:set(isContextMenuVisible)
								elseif currentState:get() == isContextMenuVisible then
									isContextMenuVisible:set(false)
									props.OpenedContextMenu:set(false)
								end

								return true
							end,
							Options = {
								{
									className == "container" and {
										Label = "Insert Instance",
										Icon = "plus",
										Callback = function()
											props.Events.OnPlusClicked:Fire(props.Instance)
											closeSelf()
										end,
									} or nil,
									{
										Label = "Delete",
										Icon = "trash",
										Color = "red",
										Callback = function()
											historyHandler(`Delete {props.Instance.Name}`, function()
												props.Instance:Destroy()
											end)

											closeSelf()
										end,
									},
									props.Depth ~= 0 and {
										Label = "New tab for instance",
										Icon = "ungroup",
										Callback = function()
											props.Events.AddTab:Fire(props.Instance)
											closeSelf()
										end,
									} or nil,
									{
										Label = "Select in Explorer",
										Icon = "list-tree",
										Callback = function()
											Selection:Set({ props.Instance })
										end,
									},
								},
								{
									{
										Label = Computed(function()
											return showSubContent:get() and "Collapse" or "Expand"
										end),
										Icon = Computed(function()
											return showSubContent:get() and "square-minus" or "square-plus"
										end),
										Callback = function()
											showSubContent:set(not showSubContent:get())
										end,
									},
								},
							},
						}
					),
				},
			}),
			New("Frame")({
				Name = "SubContentContainer",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				Visible = Computed(function()
					if
						not instanceCategories
						or instanceInMap:get() == nil
						or #instanceCategories == 0 and #instanceInMap:get().children == 0
					then
						return false
					end

					return showSubContent:get()
				end),
				[Children] = {
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 2),
					}),
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					if props.Depth ~= props.MaxDepth
						then New("Frame")({
							Name = "SubContent",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 3,
							Size = UDim2.new(1, 0, 0, 0),
							[Children] = {
								New("UIListLayout")({
									FillDirection = Enum.FillDirection.Vertical,
									Padding = UDim.new(0, 0),
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Top,
								}),
								ForPairs(children, function(index, value)
									if not table.find(ALLOWED_CLASSNAMES, value.ClassName) then
										return index, nil
									end

									return index,
										instanceTreeItem({
											LayoutOrder = index,
											Instance = value,
											Query = props.Query,
											SearchMode = props.SearchMode,
											Depth = props.Depth + 1,
											MaxDepth = props.MaxDepth,
											TreeContext = {
												Children = children,
												Lines = cascadingLines,
											},
											SharedSelectedPropertyState = props.SharedSelectedPropertyState,
											OpenedContextMenu = props.OpenedContextMenu,
											InstanceMap = props.InstanceMap,
											Events = props.Events,
										})
								end, function(index, value)
									Clean(index, value)
								end),
							},
						})
						else nil,
					instanceCategories and New("Frame")({
						Name = "Properties",
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 0),
						[Children] = {
							New("UIPadding")({
								PaddingRight = UDim.new(0, 2),
							}),
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 2),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Top,
							}),
							ForPairs(instanceCategories, function(index, category)
								local listContentSize = Value(Vector2.new())
								local showCategory = Value(true)

								return index,
									New("Frame")({
										Name = "Category",
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										LayoutOrder = index,
										Size = UDim2.new(1, 0, 0, 0),
										Visible = Computed(function()
											if props.SearchMode:get()[1] ~= "properties" or props.Query:get() == "" then
												return true
											end

											if category.properties then
												local containsProperties = false

												for _, property in category.properties do
													if
														string.find(property.name:lower(), props.Query:get():lower())
													then
														containsProperties = true
														break
													end
												end

												if not containsProperties then
													return false
												end
											end

											return true
										end),
										[Children] = {
											category.properties ~= nil and New("Frame")({
												Name = "CategoryHeader",
												BackgroundTransparency = 1,
												Position = UDim2.new(
													0,
													math.clamp(props.Depth * TREE_TAB_SIZE, 0, math.huge) + 8,
													0,
													0
												),
												Size = UDim2.new(1, -props.Depth * TREE_TAB_SIZE, 0, 20),
												[Children] = {
													New("UIPadding")({
														PaddingBottom = UDim.new(0, 2),
														PaddingTop = UDim.new(0, 2),
													}),
													New("UIListLayout")({
														FillDirection = Enum.FillDirection.Horizontal,
														HorizontalAlignment = Enum.HorizontalAlignment.Left,
														Padding = UDim.new(0, 4),
														SortOrder = Enum.SortOrder.LayoutOrder,
														VerticalAlignment = Enum.VerticalAlignment.Center,
													}),
													baseText({
														Appearance = useColor("SecondaryText", true),
														Text = {
															Font = Font.new(
																peek(theme.global.font).Family,
																Enum.FontWeight.SemiBold
															),
															Label = category.name,
															TextSize = 14,
														},
														AutomaticSize = Enum.AutomaticSize.XY,
													}),
													button({
														Margin = 2,
														Color = "white",
														Variant = "ghost",
														Content = {
															Computed(function()
																if showCategory:get() then
																	return baseIcon({
																		Icon = {
																			Name = "chevron-up",
																			Size = 12,
																		},
																		Color = useColor("SecondaryText", true),
																	})
																end

																return baseIcon({
																	Icon = {
																		Name = "chevron-down",
																		Size = 12,
																	},
																	Color = useColor("SecondaryText", true),
																})
															end, Clean),
														},
														AutomaticSize = Enum.AutomaticSize.XY,
														OnClick = function()
															showCategory:set(not showCategory:get())
														end,
													}),
												},
											}) or nil,
											New("Frame")({
												Name = "LineContainer",
												BackgroundTransparency = 1,
												Size = Computed(function()
													if listContentSize:get() == nil or not showCategory:get() then
														return UDim2.new(0, props.Depth * TREE_TAB_SIZE, 0, 20)
													end

													return UDim2.new(
														0,
														props.Depth * TREE_TAB_SIZE,
														0,
														listContentSize:get().Y + (category.properties and 20 or 0)
													)
												end),
												[Children] = {
													ForPairs(cascadingLines, function(depth, states)
														return depth,
															New("Frame")({
																Name = tostring(depth),
																BackgroundTransparency = 1,
																Position = UDim2.new(
																	0,
																	math.clamp(
																		(depth - 1) * TREE_TAB_SIZE,
																		0,
																		math.huge
																	) + 10,
																	0,
																	0
																),
																Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
																[Children] = {
																	ForPairs(states, function(idx, value)
																		return idx, makeLine(value)
																	end, Clean),
																},
															})
													end, Clean),
												},
											}),
											New("Frame")({
												Name = "Properties",
												AutomaticSize = Enum.AutomaticSize.Y,
												BackgroundTransparency = 1,
												Position = UDim2.new(0, 0, 0, category.properties and 20 or 0),
												Size = UDim2.new(1, 0, 0, 0),
												Visible = showCategory,
												[Children] = {
													New("UIListLayout")({
														FillDirection = Enum.FillDirection.Vertical,
														HorizontalAlignment = Enum.HorizontalAlignment.Right,
														Padding = UDim.new(0, 2),
														SortOrder = Enum.SortOrder.LayoutOrder,
														VerticalAlignment = Enum.VerticalAlignment.Top,
														[Out("AbsoluteContentSize")] = listContentSize,
													}),
													ForPairs(
														category.properties ~= nil and category.properties
															or { category },
														function(idx, property)
															local name = property.name
															local instanceHasProperty = pcall(function()
																return props.Instance[name] == nil
															end)

															local processedProperty = property.get
																	and property.get(props.Instance)
																or instanceHasProperty and props.Instance[name]
																or nil

															local usedProcessedProperties = peek(processedProperties)
															local tableUpdated = false

															if usedProcessedProperties[name] ~= nil then
																usedProcessedProperties[name]:set(processedProperty)
															else
																usedProcessedProperties[name] = Value(processedProperty)
																tableUpdated = true
															end

															if tableUpdated then
																processedProperties:set(usedProcessedProperties)
															end

															local wasStateChangeCascading = false

															local stateChangedObserver = Observer(
																usedProcessedProperties[name]
															):onChange(function()
																local function process()
																	local success, result = pcall(function()
																		if property.set then
																			local oldValue = property.get
																					and property.get(props.Instance)
																				or instanceHasProperty and props.Instance[name]
																				or nil

																			property.set(
																				props.Instance,
																				usedProcessedProperties[name]:get()
																			)

																			local newValue = property.get
																					and property.get(props.Instance)
																				or instanceHasProperty and props.Instance[name]
																				or nil

																			if oldValue == newValue then
																				usedProcessedProperties[name]:set(
																					oldValue
																				)
																			end
																		elseif instanceHasProperty then
																			local oldValue = props.Instance[name]

																			props.Instance[name] =
																				usedProcessedProperties[name]:get()

																			local newValue = props.Instance[name]

																			if oldValue == newValue then
																				usedProcessedProperties[name]:set(
																					oldValue
																				)
																			end
																		end

																		print(
																			`Set {name} to {usedProcessedProperties[name]:get()}`
																		)
																	end)

																	if not success then
																		usedProcessedProperties[name]:set(
																			property.get
																					and property.get(props.Instance)
																				or instanceHasProperty and props.Instance[name]
																				or nil
																		)

																		error(`Error setting {name}: {result}`)
																	elseif not wasStateChangeCascading then
																		-- see if we are a selected property
																		local selectedProperties =
																			props.SharedSelectedPropertyState:get()
																		local isSelected = selectedProperties[props.Instance]
																			and selectedProperties[props.Instance][name]
																				~= nil

																		if isSelected then
																			-- change all selected properties that arent ourself to the new value
																			-- we do this inside of the recording so that the recordings that these changes create get cancelled and merged with the main recording
																			local usedSelectedProperties =
																				props.SharedSelectedPropertyState:get()

																			local newValue =
																				usedProcessedProperties[name]:get()

																			for instance, properties in
																				usedSelectedProperties
																			do
																				if instance == props.Instance then
																					continue
																				end

																				for _, prop in properties do
																					prop.set(newValue)
																				end
																			end
																		end
																	end

																	wasStateChangeCascading = false
																end

																local currentValue = property.get
																		and property.get(props.Instance)
																	or instanceHasProperty and props.Instance[name]
																	or nil

																if
																	currentValue
																	== usedProcessedProperties[name]:get()
																then
																	process()
																	return
																end

																historyHandler(
																	`Set {name} to {usedProcessedProperties[name]:get()}`,
																	process
																)
															end)

															local propertyChanged
															if instanceHasProperty then
																propertyChanged = props.Instance
																	:GetPropertyChangedSignal(name)
																	:Connect(function()
																		local value = props.Instance[name]

																		if
																			tostring(
																				usedProcessedProperties[name]:get()
																			) ~= tostring(value)
																		then
																			usedProcessedProperties[name]:set(
																				property.get
																						and property.get(props.Instance)
																					or props.Instance[name]
																			)
																		end
																	end)
															end

															local renderedProperty = Computed(function()
																-- we want to isolate dependencies from the ren!dered property from the actual property
																-- not doing this makes us vulnerable to a lot of issues when ie a rendered property doesnt properly
																-- isolate its dependencies
																-- (this is a lot of words for "i'm lazy and don't think a better solution is worth the effort")
																return property.render({
																	Instance = props.Instance,
																	PropertyName = name,
																	Value = usedProcessedProperties[name],
																	Events = props.Events,
																}, useColor, processedProperties)
															end, Clean)

															local isPressing = Value(false)

															return idx,
																Computed(function()
																	return button({
																		Color = "neutral",
																		Variant = "ghost",
																		CustomPressBehaviour = true,
																		DisableHoverLighting = true,
																		LayoutOrder = idx,
																		AutomaticSize = Enum.AutomaticSize.Y,
																		Margin = 2,
																		Size = UDim2.new(
																			1,
																			-(props.Depth + 1) * TREE_TAB_SIZE,
																			0,
																			24
																		),
																		Disabled = Computed(function()
																			if not isCtrlHeld:get() then
																				return false
																			end

																			-- make sure that only properties of the same type can be set together
																			local selectedProperties =
																				props.SharedSelectedPropertyState:get()

																			for instance, properties in
																				selectedProperties
																			do
																				for propertyName, _ in properties do
																					if propertyName ~= name then
																						return true
																					end

																					if
																						instance == props.Instance
																						and propertyName == name
																					then
																						return false
																					end

																					if propertyName == name then
																						local propertyTypeData =
																							properties[propertyName].type

																						-- might seem like a weird comparison, but this is because of a few cases:
																						-- case 1: we want to only allow the same types of instances to be set together (so only string & number)
																						-- case 2: we do not want conflicting property fields to be set together (so no slider and input field)
																						-- case 3: we do not want properties that mutate the result differently to be set together
																						--         (so no particle emitter texture picker that supports flipbooks, and a normal texture picker)
																						--         (or number sequence editors with varying min/max values)
																						--
																						-- this introduces a few issues, the most major of which is the fact that sliders of different instance kinds
																						-- can now generally not be set together, but this is a tradeoff that we have to make for the sake of simplicity
																						if
																							propertyTypeData[1]
																								~= (property.render or typeof(
																									props.Instance[name]
																								))
																							or propertyTypeData[2]
																								~= property.set
																						then
																							return true
																						end
																					end
																				end
																			end

																			return false
																		end),
																		Pressing = Computed(function()
																			-- if this property is selected, return true
																			local selectedProperties =
																				props.SharedSelectedPropertyState:get()[props.Instance]

																			if
																				selectedProperties
																				and selectedProperties[name]
																			then
																				return selectedProperties[name] ~= nil
																			end

																			return isPressing:get()
																		end),
																		OnPress = function(pressing)
																			isPressing:set(pressing)

																			if pressing and isCtrlHeld:get() then
																				local isSelfSelected = props.SharedSelectedPropertyState:get()[props.Instance]
																					and props.SharedSelectedPropertyState:get()[props.Instance][name]

																				if not isSelfSelected then
																					local selectedProperties =
																						props.SharedSelectedPropertyState:get()
																					local instanceProperties =
																						selectedProperties[props.Instance]

																					if not instanceProperties then
																						instanceProperties = {}
																					end

																					instanceProperties[name] = {
																						set = function(newValue)
																							wasStateChangeCascading =
																								true
																							usedProcessedProperties[name]:set(
																								newValue
																							)
																						end,
																						type = {
																							property.render
																								or typeof(
																									props.Instance[name]
																								),
																							property.set,
																						},
																					}
																					selectedProperties[props.Instance] =
																						instanceProperties

																					props.SharedSelectedPropertyState:set(
																						selectedProperties
																					)
																				else
																					-- remove the property from the selected properties
																					local selectedProperties =
																						props.SharedSelectedPropertyState:get()
																					local instanceProperties =
																						selectedProperties[props.Instance]

																					if instanceProperties then
																						instanceProperties[name] = nil
																						props.SharedSelectedPropertyState:set(
																							selectedProperties
																						)
																					end
																				end
																			elseif pressing then -- if not ctrl held
																				-- if this instance is not selected, deselect all other instances
																				local selectedProperties =
																					props.SharedSelectedPropertyState:get()

																				if
																					not selectedProperties[props.Instance]
																					or not selectedProperties[props.Instance][property.name]
																				then
																					props.SharedSelectedPropertyState:set({})
																				end
																			end
																		end,
																		Visible = Computed(function()
																			if
																				props.SearchMode:get()[1]
																				== "properties"
																			then
																				if
																					props.Query:get() ~= ""
																					and not string.find(
																						property.name:lower(),
																						props.Query:get():lower()
																					)
																				then
																					return nil
																				end
																			end

																			return renderedProperty:get() ~= nil
																		end),
																		Content = {
																			New("UIPadding")({
																				PaddingLeft = UDim.new(0, 4),
																			}),
																			listOption({
																				Size = UDim2.new(0, 0, 1, 0),
																				OptionName = name,
																				Content = renderedProperty,
																			}),
																		},
																		[Cleanup] = {
																			stateChangedObserver,
																			propertyChanged,
																		},
																	})
																end, Clean)
														end,
														Clean
													),
												},
											}),
										},
									})
							end, Clean),
						},
					}),
				},
			}),
		},
	})

	awaitLayer(component, function(layer)
		local inputFrame = layer.contentFrame

		table.insert(
			keyConnections,
			inputFrame.InputBegan:Connect(function(inputObject)
				if inputObject.UserInputType == Enum.UserInputType.Keyboard then
					if
						inputObject.KeyCode == Enum.KeyCode.LeftControl
						or inputObject.KeyCode == Enum.KeyCode.RightControl
					then
						isCtrlHeld:set(true)
					end
				end
			end)
		)

		table.insert(
			keyConnections,
			inputFrame.InputEnded:Connect(function(inputObject)
				if inputObject.UserInputType == Enum.UserInputType.Keyboard then
					if
						inputObject.KeyCode == Enum.KeyCode.LeftControl
						or inputObject.KeyCode == Enum.KeyCode.RightControl
					then
						isCtrlHeld:set(false)
					end
				end
			end)
		)
	end)

	return component
end

return instanceTreeItem
