local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Spring = fusion.Spring
local Tween = fusion.Tween

local Children = fusion.Children
local New = fusion.New
local Event = fusion.OnEvent
local Ref = fusion.Ref

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local icon = studioComponents.base.icon
local inputCollector = studioComponents.utility.inputCollector

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

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

	widget({
		Name = "Color Picker",
		Id = HttpService:GenerateGUID(),
		InitialDockTo = Enum.InitialDockState.Float,
		InitialEnabled = false,
		ForceInitialEnabled = true,
		FloatingSize = Vector2.new(400, 300),
		Enabled = isWidgetEnabled,
		MinimumSize = Vector2.new(300, 200),
	})

	local sequenceNodes = Computed(function()
		-- potential optimization here: doing this causes all timeline items to refresh when a new node is added
		-- (colorsequence.keypoints provides a different table each time, so fusion thinks it's a new table and re-renders)
		-- or something? because all keypoints do match up, but it still re-renders all of them
		return props.Value:get().Keypoints
	end)

	local component = topLayerProvider.new(New("Frame")({
		Name = "ColorSequenceEditor",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
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
				Size = UDim2.new(1, 0, 1, -36),
				[Ref] = colorFrame,
				[Event("MouseEnter")] = function()
					isHoveringColor:set(true)
				end,
				[Event("MouseLeave")] = function()
					isHoveringColor:set(false)
				end,
				[Children] = {
					New("UIGradient")({
						Color = props.Value,
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

								for _, node in ipairs(sequenceNodes:get()) do
									if math.abs(node.Time - time) < 0.01 then
										time = node.Time
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

						return index,
							New("Frame")({
								Name = tostring(index),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								LayoutOrder = index,
								Position = UDim2.new(node.Time, 0, 0, 0),
								Size = UDim2.new(0, 16, 1, 0),
								[Children] = {
									icon({
										Icon = "chevron-up",
										Color = props.useColor("Text", true),
										Position = Tween(
											Computed(function()
												return UDim2.new(0, 0, 0, isHovering:get() and -4 or 0)
											end),
											TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
										),
									}),
									New("Frame")({
										Name = "Color",
										BackgroundColor3 = Tween(
											Computed(function()
												local baseColor = node.Value

												-- if hovering, darken color
												if isHovering:get() then
													local lerpColor = theme.global.isDark:get() and Color3.new(1, 1, 1)
														or Color3.new(0, 0, 0)
													baseColor = baseColor:Lerp(lerpColor, 0.2)
												end

												return baseColor
											end),
											TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
										),
										Position = UDim2.new(0, 0, 0, 16),
										Size = UDim2.new(1, 0, 0.5, 0),
										[Event("MouseEnter")] = function()
											isHovering:set(true)
										end,
										[Event("MouseLeave")] = function()
											isHovering:set(false)
										end,
										[Children] = {
											New("UICorner")({
												CornerRadius = UDim.new(0, 4),
											}),
										},
									}),
								},
							})
					end, Clean),
				},
			}),
			New("Frame")({
				Name = "ColorToolbar",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 36),
				[Children] = {
                    -- edit time, color, delete keypoint, left-aligned
                },
			}),
		},
	}))

	inputCollector({
		ReferenceObject = colorFrame:get(),
		Visible = isHoveringColor,
		OnMouseMove = function(position)
			mousePosition:set(Vector2.new(position.X, position.Y))
		end,
		OnClick = function()
			if not colorFrame:get() or not isHoveringColor:get() then
				return
			end

			local relativePosition = mousePosition:get() - colorFrame:get().AbsolutePosition
			local time = math.clamp(relativePosition.X / colorFrame:get().AbsoluteSize.X, 0, 1)

			-- find the current color at this time, interpolating between colors if necessary
			local keypoints = props.Value:get().Keypoints

			if #keypoints >= 20 then
				return
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
			table.insert(newKeypoints, ColorSequenceKeypoint.new(time, color))

			table.sort(newKeypoints, function(a, b)
				return a.Time < b.Time
			end)

			props.Value:set(ColorSequence.new(newKeypoints))
		end,
	})

	return component
end

return editor
