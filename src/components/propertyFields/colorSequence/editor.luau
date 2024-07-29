local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Spring = fusion.Spring
local Tween = fusion.Tween

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Event = fusion.OnEvent
local Ref = fusion.Ref

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local icon = fusionComponents.base.icon
local text = fusionComponents.base.text
local baseButton = fusionComponents.base.button
local inputCollector = fusionComponents.utility.inputCollector
local input = fusionComponents.common.input
local button = fusionComponents.common.button
local colorPicker = fusionComponents.common.colorPicker

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider
local peek = fusionUtils.peek

local widget = require("@components/widget")

local theme = require("@src/theme")

type props = {
	Value: fusion.Value<ColorSequence>,
	useColor: theme.useColorFunction,
}

local function editor(props: props)
	local isWidgetEnabled = Value(false)
	local isHoveringColor = Value(false)

	local colorFrame = Value()

	local mousePosition = Value(Vector2.new())
	local displayedInputText = Value("")

	local selectedNode = Value(1)
	local sequenceNodes: fusion.Value<{ fusion.Value<ColorSequenceKeypoint> }> = Value({})

	local temporaryGradient = Value(peek(sequenceNodes))
	local showTemporaryGradient = Value(false)

	local function refreshText()
		displayedInputText:set(string.format("%.2f", peek(peek(sequenceNodes)[peek(selectedNode)]).Time), true)
	end

	-- resets the current nodes to the new value; primarily used for keeping the property and editor in sync and supporting undo/redo
	local function refreshNodes()
		local currentKeypoints = props.Value:get(false).Keypoints
		local usedSequenceNodes = table.clone(sequenceNodes:get(false))

		for idx, node in currentKeypoints do
			if usedSequenceNodes[idx] then
				usedSequenceNodes[idx]:set(node)
			else
				usedSequenceNodes[idx] = Value(node)
			end
		end

		for idx = #currentKeypoints + 1, #usedSequenceNodes do
			usedSequenceNodes[idx] = nil
		end

		sequenceNodes:set(usedSequenceNodes)

		if #sequenceNodes:get(false) < selectedNode:get(false) then
			selectedNode:set(#sequenceNodes:get(false))
		else
			selectedNode:set(selectedNode:get(false), true)
		end
	end

	-- i thought this pattern was rly ugly, so i made it a function
	local function transformKeypoints(transformationFunction: ({ ColorSequenceKeypoint }) -> { ColorSequenceKeypoint })
		local newKeypoints = table.clone(props.Value:get().Keypoints)
		transformationFunction(newKeypoints)

		table.sort(newKeypoints, function(a, b)
			return a.Time < b.Time
		end)

		return newKeypoints
	end

	local observers = {
		Observer(selectedNode):onChange(refreshText),
		Observer(props.Value):onChange(refreshNodes),
	}

	refreshNodes()
	refreshText()

	local colorValue = Value(peek(peek(sequenceNodes)[peek(selectedNode)]).Value)

	local createdWidget

	local function setupWidget()
		return widget({
			Name = "Color Picker",
			Id = HttpService:GenerateGUID(),
			InitialDockTo = Enum.InitialDockState.Float,
			InitialEnabled = false,
			ForceInitialEnabled = true,
			FloatingSize = Vector2.new(220, 300),
			Enabled = isWidgetEnabled,
			MinimumSize = Vector2.new(200, 300),
			[Children] = {
				Computed(function()
					if isWidgetEnabled:get() then
						return ({
							topLayerProvider.new(New("Frame")({
								Name = "ColorPicker",
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 0, 1, 0),
								[Children] = {
									New("UIPadding")({
										PaddingBottom = UDim.new(0, 4),
										PaddingLeft = UDim.new(0, 4),
										PaddingRight = UDim.new(0, 4),
										PaddingTop = UDim.new(0, 4),
									}),
									colorPicker({
										Color = "white",
										Value = colorValue,
										Size = UDim2.new(1, 0, 1, 0),
										OnDragStart = function()
											temporaryGradient:set(table.clone(peek(props.Value).Keypoints))
											showTemporaryGradient:set("colorPicker")
										end,
										OnDragEnd = function()
											showTemporaryGradient:set(false)
										end,
										OnColorSet = function(color)
											local allowChange = true

											local newKeypoints = transformKeypoints(function(keypoints)
												local targetNode = keypoints[selectedNode:get()]
												keypoints[selectedNode:get()] =
													ColorSequenceKeypoint.new(targetNode.Time, color)
											end)

											if not allowChange then
												return
											end

											props.Value:set(ColorSequence.new(newKeypoints))
										end,
										OnColorChange = function(color)
											if showTemporaryGradient:get() == "colorPicker" then -- if dragging
												local newKeypoints = transformKeypoints(function(keypoints)
													local targetNode = keypoints[selectedNode:get()]
													keypoints[selectedNode:get()] =
														ColorSequenceKeypoint.new(targetNode.Time, color)
												end)

												temporaryGradient:set(newKeypoints)
											end
										end,
									}),
								},
							})),
						})[1]
					end

					return nil
				end, Clean),
			},
		})
	end

	local component = topLayerProvider.new(New("Frame")({
		Name = "ColorSequenceEditor",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Cleanup] = {
			function()
				-- not destroying it, see https://devforum.roblox.com/t/2853087
				isWidgetEnabled:set(false)

				if createdWidget then
					createdWidget:Destroy()
				end
			end,
			observers,
		},
		[Children] = {
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
			}),
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("Frame")({
				Name = "Color",
				Size = UDim2.new(1, 0, 1, -64),
				[Ref] = colorFrame,
				[Event("MouseEnter")] = function()
					isHoveringColor:set(true)
				end,
				[Event("MouseLeave")] = function()
					isHoveringColor:set(false)
				end,
				[Children] = {
					New("UIGradient")({
						Color = Computed(function()
							if showTemporaryGradient:get() then
								return ColorSequence.new(temporaryGradient:get())
							end

							return props.Value:get()
						end),
					}),
					New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),
					New("UIStroke")({
						Color = Computed(function()
							return (props.useColor("Line") :: theme.color).color
						end),
					}),
					New("Frame")({
						Name = "Line",
						BackgroundColor3 = Computed(function()
							return (props.useColor("Line") :: theme.color).color
						end),
						BackgroundTransparency = Spring(
							Computed(function()
								return isHoveringColor:get() and 0.5 or 1
							end),
							45,
							1
						),
						Position = Spring(
							Computed(function()
								local mousePos = mousePosition:get()

								if not colorFrame:get() then
									return UDim2.new(0, 0, 0, 0)
								end

								local colorFrameAbsoluteSize = math.clamp(colorFrame:get().AbsoluteSize.X, 1, math.huge)

								local relativePos = mousePos - colorFrame:get().AbsolutePosition
								local time = math.clamp(relativePos.X / colorFrameAbsoluteSize, 0, 1)

								for _, node in sequenceNodes:get() do
									if math.abs(node:get(false).Time - time) < 0.01 then
										time = node:get(false).Time
										break
									end
								end

								return UDim2.new(time, 0, 0, 0)
							end),
							30,
							1
						),
						Size = UDim2.new(0, 1, 1, 0),
					}),
				},
			}),
			New("Frame")({
				Name = "ColorTimeline",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 36),
				[Children] = {
					ForPairs(sequenceNodes, function(index, node)
						local isHovering = Value(false)
						local isPressing = Value(false)

						local lastClick = 0

						local timelineButton = New("TextButton")({
							Name = tostring(index),
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							LayoutOrder = index,
							Position = Computed(function()
								isHovering:set(false)
								return UDim2.new(node:get().Time, 0, 0, 0)
							end),
							Size = UDim2.new(0, 16, 1, 0),
							Text = "",
							ZIndex = index,
							[Event("MouseEnter")] = function()
								isHovering:set(true)
							end,
							[Event("MouseLeave")] = function()
								isHovering:set(false)
							end,
							[Event("MouseButton1Up")] = function()
								isPressing:set(false)
								showTemporaryGradient:set(false)
							end,
							[Event("MouseButton1Down")] = function()
								isPressing:set(true)
								selectedNode:set(index)
								colorValue:set(node:get().Value)

								if tick() - lastClick < 0.5 then
									if createdWidget == nil then
										createdWidget = setupWidget()
									end

									isWidgetEnabled:set(true)
								end

								lastClick = tick()
							end,
							[Event("MouseButton2Click")] = function()
								local newKeypoints = transformKeypoints(function(keypoints)
									table.remove(keypoints, index)
								end)

								-- min 2 keypoints and first and last keypoint must be at 0 and 1
								if
									#newKeypoints >= 2
									and newKeypoints[1].Time == 0
									and newKeypoints[#newKeypoints].Time == 1
								then
									if selectedNode:get() == index then
										selectedNode:set(1)
										colorValue:set(newKeypoints[1].Value)
									end

									isHovering:set(false)
									props.Value:set(ColorSequence.new(newKeypoints))
								end
							end,
							[Children] = {
								icon({
									Icon = "chevron-up",
									Color = props.useColor("Text", true),
									Position = Computed(function()
										return UDim2.new(0, 0, 0, isHovering:get() and -4 or 0)
									end),
								}),
								New("Frame")({
									Name = "Color",
									BackgroundColor3 = Computed(function()
										local baseColor = node:get().Value

										-- if hovering, darken color
										if isHovering:get() then
											local lerpColor = theme.global.isDark:get() and Color3.new(1, 1, 1)
												or Color3.new(0, 0, 0)
											baseColor = baseColor:Lerp(lerpColor, 0.2)
										end

										return baseColor
									end),
									Position = UDim2.new(0, 0, 0, 16),
									Size = UDim2.new(1, 0, 0.5, 0),
									[Children] = {
										New("UICorner")({
											CornerRadius = UDim.new(0, 4),
										}),
									},
								}),
							},
						})

						local isMouseInRange = Value(false)
						local dragStartPosition = UDim2.new(node:get(false).Time, 0, 0, 0)
						local currentEndPosition = UDim2.new(node:get(false).Time, 0, 0, 0)
						local wasMoved = false

						local meetsVisibilityCriteria = Computed(function()
							local isVisible = isPressing:get()
								and (isHovering:get() or isMouseInRange:get())
								and index ~= 1
								and index ~= #sequenceNodes:get()

							if not isVisible and currentEndPosition ~= dragStartPosition and wasMoved then
								local newKeypoint =
									ColorSequenceKeypoint.new(currentEndPosition.X.Scale, node:get(false).Value)

								local newKeypoints = transformKeypoints(function(keypoints)
									keypoints[index] = newKeypoint
								end)

								selectedNode:set(table.find(newKeypoints, newKeypoint), true)
								props.Value:set(ColorSequence.new(newKeypoints))
								showTemporaryGradient:set(false)
								wasMoved = false
							elseif isVisible then
								dragStartPosition = timelineButton.Position
							end

							return isVisible
						end)

						inputCollector({
							ReferenceObject = timelineButton,
							Visible = meetsVisibilityCriteria,
							OnMouseMove = function(position)
								mousePosition:set(position)

								isMouseInRange:set(
									(mousePosition:get() - timelineButton.AbsolutePosition).Magnitude < 96
								)

								if meetsVisibilityCriteria:get() then
									wasMoved = true
									currentEndPosition = UDim2.new(
										math.clamp(
											(position.X - colorFrame:get().AbsolutePosition.X)
												/ colorFrame:get().AbsoluteSize.X,
											0,
											1
										),
										0,
										0,
										0
									)

									timelineButton.Position = currentEndPosition

									local newKeypoints = transformKeypoints(function(keypoints)
										if node:get(false).Value == nil then
											return
										end

										keypoints[index] =
											ColorSequenceKeypoint.new(currentEndPosition.X.Scale, node:get(false).Value)
									end)

									temporaryGradient:set(newKeypoints)
									showTemporaryGradient:set("timeline")
								end
							end,
							OnMouseButton1Changed = function(pressing, wasHover)
								if wasHover then
									return
								end

								if not pressing then
									isPressing:set(false)
									showTemporaryGradient:set(false)
								end

								return
							end,
						})

						return index, timelineButton
					end, Clean),
				},
			}),
			New("Frame")({
				Name = "ColorToolbar",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					text({
						Text = "Time",
						Appearance = props.useColor("Text", true),
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					input({
						Variant = "default",
						Color = "gray",
						Text = displayedInputText,
						Size = UDim2.new(0, 48, 0, 24),
						OnFocusLost = function(inputText)
							local node = sequenceNodes:get()[selectedNode:get()]
							local textToNumber = tonumber(inputText)

							if not node or textToNumber == nil then
								return
							end

							textToNumber = math.clamp(textToNumber, 0, 1)

							-- start at 0, end at 1
							if selectedNode:get() == 1 and textToNumber ~= 0 then
								textToNumber = 0
							elseif selectedNode:get() == #sequenceNodes:get() and textToNumber ~= 1 then
								textToNumber = 1
							end

							local createdKeypoint = ColorSequenceKeypoint.new(textToNumber, node:get(false).Value)
							local newKeypoints = transformKeypoints(function(keypoints)
								keypoints[selectedNode:get()] = createdKeypoint
							end)

							colorValue:set(createdKeypoint.Value)
							props.Value:set(ColorSequence.new(newKeypoints), true)
							selectedNode:set(table.find(newKeypoints, createdKeypoint), true)
						end,
					}),
					baseButton({
						BackgroundColor3 = Tween(
							Computed(function()
								local node = sequenceNodes:get()[selectedNode:get()]
								return node and node:get().Value or Color3.new()
							end),
							TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						Stroke = props.useColor("Line", true),
						Size = UDim2.new(0, 24, 0, 24),
						OnClick = function()
							if createdWidget == nil then
								createdWidget = setupWidget()
							end

							isWidgetEnabled:set(true)
						end,
					}),
					button({
						Size = UDim2.new(0, 24, 0, 24),
						Icon = "trash",
						Variant = "solid",
						Color = "red",
						ButtonText = "Delete",
						Stroke = props.useColor("Line", true),
						Disabled = Computed(function()
							if selectedNode:get() == 1 or selectedNode:get() == #sequenceNodes:get() then
								return true
							end

							return false
						end),
						OnClick = function()
							local newKeypoints = transformKeypoints(function(keypoints)
								table.remove(keypoints, selectedNode:get(false))
							end)

							-- min 2 keypoints and first and last keypoint must be at 0 and 1
							if
								#newKeypoints >= 2
								and newKeypoints[1].Time == 0
								and newKeypoints[#newKeypoints].Time == 1
							then
								props.Value:set(ColorSequence.new(newKeypoints))
								selectedNode:set(1)
								colorValue:set(newKeypoints[1].Value)
							end
						end,
					}),
				},
			}),
		},
	}))

	inputCollector({
		ReferenceObject = colorFrame:get(),
		Visible = isHoveringColor,
		OnMouseMove = function(position)
			mousePosition:set(position)
		end,
		OnClick = function(wasHovering)
			if not colorFrame:get() or not isHoveringColor:get() or wasHovering then
				return
			end

			local relativePosition = mousePosition:get() - colorFrame:get().AbsolutePosition
			local time = math.clamp(relativePosition.X / colorFrame:get().AbsoluteSize.X, 0, 1)

			-- find the current color at this time, interpolating between colors if necessary
			local keypoints = props.Value:get().Keypoints

			if #keypoints >= 20 then
				return
			end

			-- check if our new keypoint is too close to an existing keypoint
			for _, node in keypoints do
				if math.abs(node.Time - time) < 0.01 then
					return
				end
			end

			local color = Color3.new()

			if #keypoints == 1 then
				color = keypoints[1].Value
			else
				local lastKeypoint = keypoints[1]
				for i = 2, #keypoints do
					local currentKeypoint = keypoints[i]

					if time >= lastKeypoint.Time and time <= currentKeypoint.Time then
						local alpha = (time - lastKeypoint.Time) / (currentKeypoint.Time - lastKeypoint.Time)
						color = lastKeypoint.Value:Lerp(currentKeypoint.Value, alpha)
						break
					end

					lastKeypoint = currentKeypoint
				end
			end

			-- add a new keypoint
			local newKeypoints = table.clone(keypoints)

			-- add keypoint to list of keypoints, sorted by time
			local keypoint = ColorSequenceKeypoint.new(time, color)
			table.insert(newKeypoints, keypoint)

			table.sort(newKeypoints, function(a, b)
				return a.Time < b.Time
			end)

			props.Value:set(ColorSequence.new(newKeypoints))
			selectedNode:set(table.find(newKeypoints, keypoint), true)
			colorValue:set(color)
		end,
	})

	return component
end

return editor
