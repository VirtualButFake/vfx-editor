local Selection = game:GetService("Selection")
local StudioService = game:GetService("StudioService")

local fusion = require("@packages/fusion")

local Tween = fusion.Tween

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Event = fusion.OnEvent
local Out = fusion.Out

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local ForValues = fusion.ForValues
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local baseIcon = studioComponents.base.icon
local baseText = studioComponents.base.text
local button = studioComponents.common.button
local contextMenu = studioComponents.common.contextMenu

local fusionUtils = require("@packages/fusionUtils")
local peek = fusionUtils.peek

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
	OnPlusClicked: (instance: Instance) -> (),
	AddTab: (instance: Instance) -> (),
	InstanceMap: fusion.Computed<instanceMapEntry>,
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
		return instanceInMap:get().linesCascading
	end)

	local lineState = Computed(function()
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
	local classIcon = StudioService:GetClassIcon(props.Instance.ClassName)

	local isHoveringHeader = Value(false)
	local isContextMenuVisible = Value(false)

	local function closeSelf()
		isContextMenuVisible:set(false)

		if props.OpenedContextMenu:get() == isContextMenuVisible then
			props.OpenedContextMenu:set(false)
		end
	end

	return New("Frame")({
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
				local function searchChildren(entry: instanceMapEntry): boolean
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
                local function searchProperties(entry: instanceMapEntry): boolean
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
											math.clamp((props.Depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 8,
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
								if depth == props.Depth then
									return depth, nil
								end

								return depth,
									New("Frame")({
										Name = tostring(depth),
										BackgroundTransparency = 1,
										Position = UDim2.new(
											0,
											math.clamp((depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 8,
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
						New("Frame")({
							Name = "Header",
							AnchorPoint = Vector2.new(1, 0),
							BackgroundColor3 = Computed(function()
								return useColor("Background").color
							end),
							BackgroundTransparency = Tween(
								Computed(function()
									if isHoveringHeader:get() then
										return 0.5
									end

									return 1
								end),
								TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
							),
							Position = UDim2.new(1, 0, 0, 0),
							Size = UDim2.new(1, -props.Depth * TREE_TAB_SIZE, 1, 0),
							[Event("MouseEnter")] = function()
								isHoveringHeader:set(true)
							end,
							[Event("MouseLeave")] = function()
								isHoveringHeader:set(false)
							end,
							[Children] = {
								New("UICorner")({
									CornerRadius = UDim.new(0, 4),
								}),
								New("UIPadding")({
									PaddingBottom = UDim.new(0, 2),
									PaddingLeft = UDim.new(0, 2),
									PaddingRight = UDim.new(0, 2),
									PaddingTop = UDim.new(0, 2),
								}),
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
										New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											Padding = UDim.new(0, 4),
											SortOrder = Enum.SortOrder.LayoutOrder,
											VerticalAlignment = Enum.VerticalAlignment.Center,
										}),
										baseIcon({
											Name = "Icon",
											Icon = classIcon.Image,
											ImageRectSize = classIcon.ImageRectSize,
											ImageRectOffset = classIcon.ImageRectOffset,
											Color = useColor("Text", true),
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
									Name = "Arrow",
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
											props.OnPlusClicked(props.Instance)
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
											props.AddTab(props.Instance)
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
					if not instanceCategories or #instanceCategories == 0 and #instanceInMap:get().children == 0 then
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
											OnPlusClicked = props.OnPlusClicked,
											AddTab = props.AddTab,
											OpenedContextMenu = props.OpenedContextMenu,
											InstanceMap = props.InstanceMap,
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
																	) + 8,
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
																	end
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
																}, useColor, processedProperties)
															end, Clean)

															return idx,
																Computed(function()
																	return New("Frame")({
																		Name = name,
																		BackgroundTransparency = 1,
																		LayoutOrder = idx,
																		Size = UDim2.new(1, 0, 0, 24),
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
																		[Cleanup] = {
																			stateChangedObserver,
																			propertyChanged,
																		},
																		[Children] = {
																			listOption({
																				Size = UDim2.new(
																					1,
																					-(props.Depth + 1) * TREE_TAB_SIZE,
																					1,
																					0
																				),
																				Position = UDim2.new(
																					0,
																					(props.Depth + 1) * TREE_TAB_SIZE,
																					0,
																					0
																				),
																				OptionName = name,
																				Content = renderedProperty,
																			}),
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
end

return instanceTreeItem
