local StudioService = game:GetService("StudioService")

local fusion = require("@packages/fusion")

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local baseIcon = studioComponents.base.icon
local baseText = studioComponents.base.text
local button = studioComponents.common.button

local fusionUtils = require("@packages/fusionUtils")
local peek = fusionUtils.peek

local theme = require("@src/theme")

local getPropertiesForInstance = require("@src/lib/getPropertiesForInstance")
local historyHandler = require("@src/lib/historyHandler")

local instanceProperty = require("@src/components/instanceProperty")

type props = {
	Instance: Instance,
	Query: fusion.Value<string>,
	Depth: number,
	MaxDepth: number,
	TreeContext: {
		Children: { Instance },
		Lines: { [number]: string },
	}?,
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
	local lineState = {}
	local cascadingLines = {}

	if props.TreeContext then
		local selfIndex = table.find(props.TreeContext.Children, props.Instance)

		if selfIndex then
			local isLastChild = selfIndex == #props.TreeContext.Children
			local isFirstChild = selfIndex == 1

			if not isLastChild then
				table.insert(lineState, isFirstChild and "StartVertical" or "Vertical")
			else
				table.insert(lineState, "Horizontal")
				table.insert(lineState, "HalfVertical")
			end

			if not isLastChild and not isFirstChild then
				table.insert(lineState, "Horizontal")
			end

			if isFirstChild then
				table.insert(lineState, "Horizontal")
				table.insert(lineState, isLastChild and "HalfVertical" or "StartVertical")
			end

			local lineContext = table.clone(props.TreeContext.Lines)

			if not isLastChild then
				lineContext[props.Depth] = { "Vertical" }
			end

			cascadingLines = lineContext
		end
	end

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
	local instanceProperties = getPropertiesForInstance(props.Instance)

	local onNameChanged = props.Instance:GetPropertyChangedSignal("Name"):Connect(function()
		instanceName:set(props.Instance.Name)
	end)

	-- make this stateful, so that fields can check on existence of the property and react when it is added
	local processedProperties: fusion.Value<getPropertiesForInstance.processedProperties> = fusion.Value({})

	local subItems = Value({})
	local showSubContent = Value(true)

	local children = Value(props.Instance:GetChildren())

	local childAddedConnection = props.Instance.ChildAdded:Connect(function(child)
		local newChildren = children:get()
		table.insert(newChildren, child)
		children:set(newChildren)
	end)

	return New("Frame")({
		Name = "InstanceTreeItem",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		[Cleanup] = {
			onNameChanged,
			childAddedConnection,
		},
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 0),
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
						Size = UDim2.new(0, props.Depth * TREE_TAB_SIZE, 1, 0),
						[Children] = {
							if #lineState > 0
								then New("Frame")({
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
										ForPairs(lineState, function(index, value)
											return index, makeLine(value)
										end, Clean),
									},
								})
								else nil,
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
					New("Frame")({
						Name = "Header",
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.new(1, -props.Depth * TREE_TAB_SIZE, 1, 0),
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							New("Frame")({
								Name = "Content",
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Size = UDim2.new(0, 0, 1, 0),
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, 2),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									baseIcon({
										Name = "Icon",
										Icon = StudioService:GetClassIcon(props.Instance.ClassName).Image,
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
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "play",
									}),
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "chevron-down",
										OnClick = function()
											showSubContent:set(not showSubContent:get())
										end,
									}),
								},
							}),
						},
					}),
				},
			}),
			New("Frame")({
				Name = "SubContentContainer",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				Visible = showSubContent,
				[Children] = {
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

									local newSubItems = peek(subItems) -- doesnt have to be reactive
									table.insert(newSubItems, value)
									subItems:set(newSubItems)

									return index,
										instanceTreeItem({
											Instance = value,
											Query = props.Query,
											Depth = props.Depth + 1,
											MaxDepth = props.MaxDepth,
											TreeContext = {
												Children = children:get(),
												Lines = cascadingLines,
											},
										})
								end, Clean),
							},
						})
						else nil,
					instanceProperties and New("Frame")({
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
							ForPairs(instanceProperties, function(index, property)
								if
									props.Query:get() ~= ""
									and not string.find(property.name:lower(), props.Query:get():lower())
								then
									return index, nil
								end

								local name = property.name
								local processedProperty = property.get and property.get(props.Instance)
									or props.Instance[name]

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

								local renderedProperty = property.render({
									Instance = props.Instance,
									PropertyName = name,
									Value = usedProcessedProperties[name],
								}, processedProperties, useColor)

								local stateChangedObserver = Observer(usedProcessedProperties[name]):onChange(function()
									historyHandler(`Set {name} to {usedProcessedProperties[name]:get()}`, function()
										if property.set then
											property.set(props.Instance, usedProcessedProperties[name]:get())
										else
											props.Instance[name] = usedProcessedProperties[name]:get()
										end
									end)
								end)

								local instanceHasProperty = pcall(function()
									return props.Instance[name] == nil
								end)

								local propertyChanged
								if instanceHasProperty then
									propertyChanged = props.Instance:GetPropertyChangedSignal(name):Connect(function()
										local value = props.Instance[name]

										if usedProcessedProperties[name]:get() ~= value then
											usedProcessedProperties[name]:set(props.Instance[name])
										end
									end)
								end

								local propertyLineType = index == 1 and "StartVertical" or "Vertical"
								local subItemsCount = #peek(subItems)

								if renderedProperty then
									return index,
										New("Frame")({
											Name = name,
											BackgroundTransparency = 1,
											LayoutOrder = index,
											Size = UDim2.new(1, 0, 0, 24),
											[Cleanup] = {
												stateChangedObserver,
												propertyChanged,
											},
											[Children] = {
												instanceProperty({
													Size = UDim2.new(1, -(props.Depth + 1) * TREE_TAB_SIZE, 1, 0),
													Position = UDim2.new(0, (props.Depth + 1) * TREE_TAB_SIZE, 0, 0),
													Property = name,
													Content = renderedProperty,
												}),
												New("Frame")({
													Name = "LineContainer",
													BackgroundTransparency = 1,
													Size = UDim2.new(0, props.Depth * TREE_TAB_SIZE, 1, 0),
													[Children] = {
														New("Frame")({
															Name = tostring(props.Depth),
															BackgroundTransparency = 1,
															Position = UDim2.new(
																0,
																math.clamp(
																	(props.Depth - 1) * TREE_TAB_SIZE,
																	0,
																	math.huge
																) + 8,
																0,
																0
															),
															Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
															[Children] = {
																ForPairs({
																	propertyLineType,
																}, function(idx, value)
																	local treeContextChildren = props.TreeContext
																			and props.TreeContext.Children
																		or {}

																	-- if no treecontext exists or this instance has no children and we are not the last child, render the line
																	if
																		not props.TreeContext
																		or subItemsCount > 0
																			and table.find(
																				treeContextChildren,
																				props.Instance
																			) ~= #treeContextChildren
																	then
																		return idx, makeLine(value)
																	end

																	-- if we are the last child, don't render the line (instance is closed before properties)
																	if
																		table.find(treeContextChildren, props.Instance)
																		== #treeContextChildren
																	then
																		return idx, nil
																	end

																	return idx, makeLine(value)
																end, Clean),
															},
														}),
														-- lines for the sub content, at the same depth as the properties
														if subItemsCount > 0
															then New("Frame")({
																Name = tostring(props.Depth),
																BackgroundTransparency = 1,
																Position = UDim2.new(
																	0,
																	math.clamp(
																		props.Depth * TREE_TAB_SIZE,
																		0,
																		math.huge
																	) + 8,
																	0,
																	0
																),
																Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
																[Children] = {
																	ForPairs({
																		propertyLineType,
																	}, function(idx, value)
																		-- if we have no idea where we are in the tree, just render the line
																		if
																			subItemsCount > 0 or not props.TreeContext
																		then
																			return idx, makeLine(value)
																		end

																		local treeContextChildren =
																			props.TreeContext.Children

																		-- if we are the last child, don't render the line (instance is closed before properties)
																		if
																			table.find(
																				treeContextChildren,
																				props.Instance
																			)
																			== #treeContextChildren
																		then
																			return idx, nil
																		end

																		return idx, makeLine(value)
																	end, Clean),
																},
															})
															else nil,
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
											},
										})
								end

								return index, nil
							end, Clean),
						},
					}),
				},
			}),
		},
	})
end

return instanceTreeItem
