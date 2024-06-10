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
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text
local modal = studioComponents.common.modal
local button = studioComponents.common.button
local inputCollector = studioComponents.utility.inputCollector
local contextMenu = studioComponents.common.contextMenu
local icon = studioComponents.base.icon
local input = studioComponents.common.input

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider
local use = fusionUtils.use
local peek = fusionUtils.peek

local easingModes = require("./easingModes")
local grid = require("./grid")
local graph = require("./graph")
local handleComponent = require("./handle")

local viewport2D = require("@components/viewport2D")

local theme = require("@src/theme")

local function exportGraph(resolution: number, points: { point })
	local resolutionIncrement = 1 / resolution
	local currentKeypoints = {}

	local sortedPoints = table.clone(points)

	table.sort(sortedPoints, function(a, b)
		local peekA = peek(a)
		local peekB = peek(b)

		return peekA.index < peekB.index
	end)

	for iteration = 0, resolution do
		local currentTime = iteration * resolutionIncrement
		local point1, point2

		for _, point in sortedPoints do
			local peekedPoint = peek(point)

			if peekedPoint.index <= currentTime and point ~= sortedPoints[#sortedPoints] then
				point1 = peek(point)
			end

			if peekedPoint.index >= currentTime and point ~= point1 then
				point2 = peek(point)
				break
			end
		end

		if point1 and point2 then
			local time = 1 - (point2.index - currentTime) / (point2.index - point1.index)

			if time == 0 or time ~= time then
				-- to prevent nan
				table.insert(currentKeypoints, {
					index = currentTime,
					value = point1.value,
					envelope = point1.envelope,
				})

				continue
			end

			if point1.easingMode == "bezier" then
				local handle1 = point1.handle2
				local handle2 = point2.handle1

				local value = easingModes.bezier.Ease(
					time,
					Vector2.new(point1.index, point1.value),
					Vector2.new(handle1.x, handle1.y) + Vector2.new(point1.index, point1.value),
					Vector2.new(handle2.x, handle2.y) + Vector2.new(point2.index, point2.value),
					Vector2.new(point2.index, point2.value)
				)

				table.insert(currentKeypoints, {
					index = currentTime,
					value = value.Y,
					envelope = easingModes.linear.InOut(point1.envelope, point2.envelope, time),
				})
			else
				table.insert(currentKeypoints, {
					index = currentTime,
					value = easingModes[point1.easingMode][point1.direction](point1.value, point2.value, time),
					envelope = easingModes[point1.easingMode][point1.direction](point1.envelope, point2.envelope, time),
				})
			end
		end
	end

	return currentKeypoints
end

local function numberSequenceEq(a: NumberSequence, b: NumberSequence)
	local keypointsA = a.Keypoints
	local keypointsB = b.Keypoints

	if #keypointsA ~= #keypointsB then
		return false
	end

	for i, keypointA in keypointsA do
		local keypointB = keypointsB[i]

		if
			keypointA.Time ~= keypointB.Time
			or keypointA.Value ~= keypointB.Value
			or keypointA.Envelope ~= keypointB.Envelope
		then
			return false
		end
	end

	return true
end

local function compressPoints(points: { keypoint }): { keypoint }
	local keypoints = {}
	local lastPoint: keypoint?

	for i, point in points do
		if lastPoint and points[i - 2] then
			local slopes = {}

			-- compare self to slope between i-2 and i-1 and exchange self with i-1 if similiar enough
			-- batch points of similiar slope together
			-- value
			slopes[1] = {}

			do
				local diffX = point.index - lastPoint.index
				local diffY = point.value - lastPoint.value
				slopes[1][1] = diffY / diffX
			end

			do
				local diffX = points[i - 2].index - lastPoint.index
				local diffY = points[i - 2].value - lastPoint.value

				slopes[1][2] = diffY / diffX
			end

			slopes[2] = {}

			-- envelope
			do
				local distanceToBounds = math.clamp(math.min(1 - point.value, point.value), 0, 1)
				local lastDistanceToBounds = math.clamp(math.min(1 - lastPoint.value, lastPoint.value), 0, 1)

				local envelopeConstrained = math.clamp(point.envelope, 0, distanceToBounds)
				local lastEnvelopeConstrained = math.clamp(lastPoint.envelope, 0, lastDistanceToBounds)

				local diffX = point.index - lastPoint.index
				local diffY = envelopeConstrained - lastEnvelopeConstrained
				slopes[2][1] = diffY / diffX
			end

			do
				local distanceToBounds = math.clamp(math.min(1 - points[i - 2].value, points[i - 2].value), 0, 1)
				local lastDistanceToBounds = math.clamp(math.min(1 - lastPoint.value, lastPoint.value), 0, 1)

				local envelopeConstrained = math.clamp(points[i - 2].envelope, 0, distanceToBounds)
				local lastEnvelopeConstrained = math.clamp(lastPoint.envelope, 0, lastDistanceToBounds)

				local diffX = points[i - 2].index - lastPoint.index
				local diffY = envelopeConstrained - lastEnvelopeConstrained
				slopes[2][2] = diffY / diffX
			end

			local canNotBeExchanged = false

			for _, slope in pairs(slopes) do
				if math.abs(slope[1] - slope[2]) > 1e-4 then
					canNotBeExchanged = true
					break
				end
			end

			if canNotBeExchanged then
				table.insert(keypoints, point)
				lastPoint = point
				continue
			else
				-- replace i-1
				keypoints[#keypoints] = point
				lastPoint = point
				continue
			end
		end

		table.insert(keypoints, point)
		lastPoint = point
	end

	return keypoints
end

local function numberTableToSequence(points: { keypoint })
	local keypoints = compressPoints(points)

	if #keypoints > 20 then
		-- keypoints is now a "curve" of points, divided unequally and based on the detail in a section
		-- we split the curve into (at most) 20 points, on the following 2 factors:
		-- 1. the distance (in time) between the points
		-- 2. the distance (in indices) between the points
		-- this guarantees that we use the maximum amount of points while retaining the maximum amount of detail
		-- the caveat with this is that both algorithms limit the amount of points to 20 *per algorithm*, resulting in a slightly higher amount of points
		-- so to combat this, we compress the data further if we have more than 20 points

		local newKeypoints = { keypoints[1] }
		local lastKeypoint = keypoints[1]
		local lastIndex = 1

		local indexMin = #keypoints / 18

		for i = 2, #keypoints - 1 do
			local currentKeypoint = keypoints[i]

			local distanceTime = currentKeypoint.index - lastKeypoint.index
			local distanceIndex = i - lastIndex

			if distanceTime > 1 / 18 or distanceIndex > indexMin then
				table.insert(newKeypoints, currentKeypoint)
				lastKeypoint = currentKeypoint
				lastIndex = i
			end
		end

		table.insert(newKeypoints, keypoints[#keypoints])

		if #newKeypoints > 20 then
			-- we need to compress our data further, as we have more than 20 points
			-- remove the values that have the lowest relative slope (both value and envelope)
			-- compare both the point before and after the point to determine the slope
			local slopes: {
				{
					point: keypoint,
					slopes: { number },
				}
			} = {}

			for i, point in newKeypoints do
				if i == 1 or i == #newKeypoints then
					continue
				end

				local pointSlopes = {}

				-- value
				pointSlopes[1] = {}

				do
					local diffX = point.index - newKeypoints[i - 1].index
					local diffY = point.value - newKeypoints[i - 1].value
					pointSlopes[1][1] = diffY / diffX
				end

				do
					local diffX = newKeypoints[i + 1].index - point.index
					local diffY = newKeypoints[i + 1].value - point.value
					pointSlopes[1][2] = diffY / diffX
				end

				pointSlopes[2] = {}

				-- envelope
				do
					local distanceToBounds = math.clamp(math.min(1 - point.value, point.value), 0, 1)
					local lastDistanceToBounds =
						math.clamp(math.min(1 - newKeypoints[i - 1].value, newKeypoints[i - 1].value), 0, 1)

					local envelopeConstrained = math.clamp(point.envelope, 0, distanceToBounds)
					local lastEnvelopeConstrained = math.clamp(newKeypoints[i - 1].envelope, 0, lastDistanceToBounds)

					local diffX = point.index - newKeypoints[i - 1].index
					local diffY = envelopeConstrained - lastEnvelopeConstrained
					pointSlopes[2][1] = diffY / diffX
				end

				do
					local distanceToBounds =
						math.clamp(math.min(1 - newKeypoints[i + 1].value, newKeypoints[i + 1].value), 0, 1)
					local lastDistanceToBounds = math.clamp(math.min(1 - point.value, point.value), 0, 1)

					local envelopeConstrained = math.clamp(newKeypoints[i + 1].envelope, 0, distanceToBounds)
					local lastEnvelopeConstrained = math.clamp(point.envelope, 0, lastDistanceToBounds)

					local diffX = newKeypoints[i + 1].index - point.index
					local diffY = envelopeConstrained - lastEnvelopeConstrained
					pointSlopes[2][2] = diffY / diffX
				end

				table.insert(slopes, {
					point = point,
					slopes = pointSlopes,
				})
			end

			table.sort(slopes, function(a, b)
				local aSlope = math.abs(a.slopes[1][1] - a.slopes[1][2]) + math.abs(a.slopes[2][1] - a.slopes[2][2])
				local bSlope = math.abs(b.slopes[1][1] - b.slopes[1][2]) + math.abs(b.slopes[2][1] - b.slopes[2][2])

				return aSlope > bSlope
			end)

			local finalKeypoints = { newKeypoints[1], newKeypoints[#newKeypoints] }

			for i = 1, 18 do
				table.insert(finalKeypoints, slopes[i].point)
			end

			table.sort(finalKeypoints, function(a, b)
				return a.index < b.index
			end)

			newKeypoints = finalKeypoints
		end

		keypoints = newKeypoints
	end

	local numberSequenceKeypoints = {}

	for _, keypoint in keypoints do
		table.insert(
			numberSequenceKeypoints,
			NumberSequenceKeypoint.new(keypoint.index, keypoint.value, keypoint.envelope)
		)
	end

	return NumberSequence.new(numberSequenceKeypoints)
end

local function concatMultilineString(...: string)
	return table.concat({ ... }, "\n")
end

type keypoint = {
	index: number,
	value: number,
	envelope: number,
}

type point =
	fusion.Value<{
		index: number,
		value: number,
		envelope: number,
		easingMode: "back" | "bounce" | "cubic" | "elastic" | "expo" | "linear" | "quad" | "quart" | "quint" | "sine" | "bezier",
		direction: "In" | "Out" | "InOut",
		handle1: {
			x: number,
			y: number,
		}?,
		handle2: {
			x: number,
			y: number,
		}?,
	}>

type props = {
	Value: fusion.Value<NumberSequence>,
	useColor: theme.useColorFunction,
	Instance: Instance,
}

local GRAPH_UPDATE_HZ = 45
local GRAPH_RESOLUTION_RENDER = 200
local GRAPH_RESOLUTION_EXPORT = 500
local LINE_COLOR = Color3.new(0, 0, 0)
local ENVELOPE_COLOR = Color3.fromRGB(255, 127, 127)
local HANDLE_COLOR = Color3.fromRGB(255, 50, 50)

local ENVELOPE_SPACING = 0.1

local function numberSequenceEditor(props: props)
	local useColor = theme:get("NumberSequenceEditor", "gray", "default", "Base")

	local points: fusion.Value<{ point }> = Value({})
	local graphPoints = Value({
		{
			index = 0,
			value = 0,
			envelope = 0,
		},
		{
			index = 1,
			value = 1,
			envelope = 0,
		},
	})

	local lastGraphUpdate = 0

	local selectedDot: fusion.Value<{ point }> = Value(nil)
	local inputTimeText = Value("")
	local inputValueText = Value("")
	local inputEnvelopeText = Value("")

	local processedSelectedDot = Computed(function()
		local dot = selectedDot:get()
		local idx = table.find(points:get(), dot)

		if not idx then
			inputTimeText:set("")
			inputValueText:set("")
			inputEnvelopeText:set("")
			return nil
		end

		local peekedPoint = peek(dot)
		inputTimeText:set(tostring(peekedPoint.index))
		inputValueText:set(tostring(peekedPoint.value))
		inputEnvelopeText:set(tostring(peekedPoint.envelope))
		return dot
	end)

	local function rerenderGraph()
		if tick() - lastGraphUpdate < 1 / GRAPH_UPDATE_HZ then
			local cachedGraphUpdate = lastGraphUpdate

			task.delay(1 / GRAPH_UPDATE_HZ, function()
				if cachedGraphUpdate == lastGraphUpdate then
					rerenderGraph()
				end
			end)

			return
		end

		lastGraphUpdate = tick()
		graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, points:get(false)))
	end

	local isChanging = false

	local function applyChanges()
		local sequence = numberTableToSequence(exportGraph(GRAPH_RESOLUTION_EXPORT, points:get(false)))
		isChanging = true

		local dereferencedPoints = {}

		for _, point in (points:get()) do
			table.insert(dereferencedPoints, point:get())
		end

		props.Instance:SetAttribute("_vfxEditorGraphData", HttpService:JSONEncode(dereferencedPoints))
		props.Value:set(sequence)

		task.delay(0.05, function()
			isChanging = false
		end)
	end

	local disconnectAttributeChange = props.Instance:GetAttributeChangedSignal("_vfxEditorGraphData"):Connect(function()
		if isChanging then
			return
		end

		local savedData = props.Instance:GetAttribute("_vfxEditorGraphData")
		local decodedPoints: { point } = savedData and HttpService:JSONDecode(savedData) or nil

		if decodedPoints then
			local oldPoints = points:get()

			for i, point in decodedPoints do
				if oldPoints[i] then
					oldPoints[i]:set(point)
				else
					oldPoints[i] = Value(point)
				end
			end

			-- clean up any extra points
			for i = #decodedPoints + 1, #oldPoints do
				oldPoints[i] = nil
			end

			local exportedGraph = exportGraph(GRAPH_RESOLUTION_EXPORT, decodedPoints)

			points:set(oldPoints)
			graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, decodedPoints))
			props.Value:set(numberTableToSequence(exportedGraph))
		end
	end)

	local sequenceEditor = Value(nil)
	local graphContainer = Value(nil)

	local isContextVisible = Value(false)
	local isHoveringGraph = Value(false)
	local isDraggingHandle = Value(false)

	local component, layer
	component, layer = topLayerProvider.new(New("Frame")({
		Name = "SequenceEditor",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Ref] = sequenceEditor,
		[Cleanup] = {
			disconnectAttributeChange,
		},
		[Children] = {
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
			}),
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("ImageButton")({
				Name = "Graph",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -36),
				[Ref] = graphContainer,
				[Event("MouseEnter")] = function()
					isHoveringGraph:set(true)
				end,
				[Event("MouseLeave")] = function()
					isHoveringGraph:set(false)
				end,
				[Event("MouseButton1Click")] = function()
					if isContextVisible:get() then
						isContextVisible:get():set(false)
						isContextVisible:set(false)
					elseif #points:get() < 20 then
						local mousePosition = layer.state.mousePosition:get()

						local relativePosition = mousePosition - graphContainer:get().AbsolutePosition
						local horizontalProgress = relativePosition.X / graphContainer:get().AbsoluteSize.X
						local verticalProgress = 1 - relativePosition.Y / graphContainer:get().AbsoluteSize.Y

						local newPoint = Value({
							index = horizontalProgress,
							value = verticalProgress,
							envelope = 0,
							easingMode = "linear",
							direction = "InOut",
							handle1 = {
								x = -0.1,
								y = 0,
							},
							handle2 = {
								x = 0.1,
								y = 0,
							},
						})

						local oldPoints = points:get()
						table.insert(oldPoints, newPoint)

						table.sort(oldPoints, function(a, b)
							return a:get().index < b:get().index
						end)

						points:set(oldPoints)
						selectedDot:set(newPoint)
						rerenderGraph()
						applyChanges()
					end
				end,
				[Children] = {
					New("UIStroke")({
						Color = Computed(function()
							return (useColor("Line") :: theme.color).color
						end),
						Thickness = 1,
					}),
					New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),
					grid({
						color = Computed(function()
							return (useColor("Line") :: theme.color).color
						end),
						spacingX = 0.1,
						spacingY = 0.25,
					}),
					viewport2D({
						BackgroundColor = LINE_COLOR,
						Corner = UDim.new(0, 4),
						Children = {
							graph({
								Points = graphPoints,
								EnvelopeColor = ENVELOPE_COLOR,
								LineColor = LINE_COLOR,
								PixelScale = 4,
								Resolution = 200,
							}),
							function(convertToVector, bounds, size)
								return Computed(function()
									local usedSelectedDot = selectedDot:get()

									if usedSelectedDot then
										local usedDot = usedSelectedDot:get()
										local pointPos = Vector2.new(usedDot.index, usedDot.value)

										return {
											handleComponent({
												HandlePosition = pointPos
													+ Vector2.new(0, math.max(usedDot.envelope, ENVELOPE_SPACING)),
												PointPosition = pointPos,
												Color = HANDLE_COLOR,
											})(convertToVector, bounds, size),
											handleComponent({
												HandlePosition = pointPos
													- Vector2.new(0, math.max(usedDot.envelope, ENVELOPE_SPACING)),
												PointPosition = pointPos,
												Color = HANDLE_COLOR,
											})(convertToVector, bounds, size),
										}
									end

									return
								end, Clean)
							end,
							function(convertToVector, bounds, size)
								return Computed(function()
									local usedSelectedDot = selectedDot:get()
									local instances = {}

									if usedSelectedDot then
										local usedDot = usedSelectedDot:get()

										local dotIndex = table.find(points:get(), usedSelectedDot)

										if dotIndex == nil then
											return instances
										end

										local previousPoint = points:get()[dotIndex - 1]

										local pointValue = Vector2.new(usedDot.index, usedDot.value)

										if
											usedDot.handle1
											and previousPoint
											and previousPoint:get().easingMode == "bezier"
										then
											table.insert(
												instances,
												handleComponent({
													HandlePosition = Vector2.new(usedDot.handle1.x, usedDot.handle1.y)
														+ pointValue,
													PointPosition = pointValue,
													Color = HANDLE_COLOR,
												})(convertToVector, bounds, size)
											)
										end

										if usedDot.handle2 and usedDot.easingMode == "bezier" then
											table.insert(
												instances,
												handleComponent({
													HandlePosition = Vector2.new(usedDot.handle2.x, usedDot.handle2.y)
														+ pointValue,
													PointPosition = pointValue,
													Color = HANDLE_COLOR,
												})(convertToVector, bounds, size)
											)
										end
									end

									return instances
								end, Clean)
							end,
						},
						Bounds = {
							x = {
								min = 0,
								max = 1,
							},
							y = {
								min = 0,
								max = 1,
							},
						},
						Size = UDim2.new(1, 0, 1, 0),
					}),
					New("Frame")({
						Name = "GraphPoints",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						[Children] = {
							ForPairs({ -1, 1 }, function(index, value)
								local handle = Value(nil)
								local isHovering = Value(false)
								local isDragging = Value(false)

								return index,
									New("Frame")({
										Name = "EnvelopeHandle",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = Computed(function()
											local usedSelectedDot = selectedDot:get()

											if usedSelectedDot then
												usedSelectedDot = usedSelectedDot:get()

												local envelopeEnd = usedSelectedDot.value
													+ (math.max(usedSelectedDot.envelope, ENVELOPE_SPACING)) * value

												return UDim2.new(usedSelectedDot.index, 0, 1 - envelopeEnd, 0)
											end

											return UDim2.new(0, 0, 0, 0)
										end),
										Size = UDim2.new(0, 10, 0, 10),
										Visible = Computed(function()
											local usedSelectedDot = selectedDot:get()

											if usedSelectedDot then
												return true
											end

											return false
										end),
										[Ref] = handle,
										[Event("MouseEnter")] = function()
											isHovering:set(true)
										end,
										[Event("MouseLeave")] = function()
											isHovering:set(false)
										end,
										[Children] = {
											Computed(function()
												if handle:get() == nil then
													return
												end

												return inputCollector({
													ReferenceObject = handle:get(),
													Visible = Computed(function()
														return isHovering:get() or isDragging:get()
													end),
													OnMouseButton1Changed = function(pressed)
														isDragging:set(pressed)
														isDraggingHandle:set(pressed)

														if not pressed then
															applyChanges()
														end
													end,
													OnMouseMove = function(mousePosition)
														if not isDragging:get() then
															return
														end

														local relativePosition = mousePosition
															- graphContainer:get().AbsolutePosition
														local verticalProgress = 1
															- math.clamp(
																relativePosition.Y / graphContainer:get().AbsoluteSize.Y,
																0,
																1
															)

														local usedSelectedDot = selectedDot:get()

														if usedSelectedDot then
															local dotData = usedSelectedDot:get()
															local diff = math.abs(dotData.value - verticalProgress)
															local distanceToBounds = math.clamp(
																math.min(1 - dotData.value, dotData.value),
																0,
																1
															)

															dotData.envelope = math.clamp(diff, 0, distanceToBounds)

															usedSelectedDot:set(dotData)
															inputEnvelopeText:set(math.clamp(dotData.envelope, 0, 1))
															rerenderGraph()
														end
													end,
												})
											end),
										},
									})
							end, Clean),
							ForPairs({ 1, 2 }, function(index, value)
								local HANDLE_INDEX = "handle" .. tostring(value)

								local handle = Value(nil)
								local isHovering = Value(false)
								local isDragging = Value(false)

								return index,
									New("Frame")({
										Name = "BezierHandle" .. tostring(value),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = Computed(function()
											local usedSelectedDot = selectedDot:get()

											if usedSelectedDot then
												usedSelectedDot = usedSelectedDot:get()

												if usedSelectedDot[HANDLE_INDEX] then
													return UDim2.new(
														usedSelectedDot[HANDLE_INDEX].x + usedSelectedDot.index,
														0,
														1 - usedSelectedDot[HANDLE_INDEX].y - usedSelectedDot.value,
														0
													)
												end
											end

											return UDim2.new(0, 0, 0, 0)
										end),
										Size = UDim2.new(0, 16, 0, 16),
										Visible = Computed(function()
											local usedSelectedDot = selectedDot:get()

											if usedSelectedDot then
												local usedDot = usedSelectedDot:get()

												local selfIndex = table.find(points:get(), usedSelectedDot)

												if selfIndex == nil then
													return
												end

												local previousPoint = points:get()[selfIndex - 1]

												if usedDot[HANDLE_INDEX] ~= nil then
													if
														value == 1
														and previousPoint
														and previousPoint:get().easingMode == "bezier"
													then
														return true
													elseif value == 2 and usedDot.easingMode == "bezier" then
														return true
													end
												end
											end

											return false
										end),
										[Ref] = handle,
										[Event("MouseEnter")] = function()
											isHovering:set(true)
										end,
										[Event("MouseLeave")] = function()
											isHovering:set(false)
										end,
										[Children] = {
											Computed(function()
												if handle:get() == nil then
													return
												end

												-- this doesn't actually pass anything to the computed, the computed purely exists so we can await the ref
												return inputCollector({
													ReferenceObject = handle:get(),
													Visible = Computed(function()
														return isHovering:get() or isDragging:get()
													end),
													OnMouseButton1Changed = function(pressed)
														isDragging:set(pressed)
														isDraggingHandle:set(pressed)

														if not pressed then
															applyChanges()
														end
													end,
													OnMouseMove = function(mousePosition)
														if not isDragging:get() then
															return
														end

														local relativePosition = mousePosition
															- graphContainer:get().AbsolutePosition
														local horizontalProgress = math.clamp(
															relativePosition.X / graphContainer:get().AbsoluteSize.X,
															0,
															1
														)
														local verticalProgress = 1
															- math.clamp(
																relativePosition.Y / graphContainer:get().AbsoluteSize.Y,
																0,
																1
															)

														local usedSelectedDot = selectedDot:get()

														if usedSelectedDot then
															local dotData = usedSelectedDot:get()

															dotData[HANDLE_INDEX].x = math.clamp(
																horizontalProgress - dotData.index,
																value - 2,
																value - 1
															)
															dotData[HANDLE_INDEX].y = verticalProgress - dotData.value

															usedSelectedDot:set(dotData)
															rerenderGraph()
														end
													end,
												})
											end),
										},
									})
							end, Clean),
							Computed(function()
								if isHoveringGraph:get() and #points:get() < 19 then
									return New("Frame")({
										Name = "GraphPoint",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = Spring(
											Computed(function()
												if graphContainer:get() == nil then
													return UDim2.new(0, 0, 0, 0)
												end

												local mousePosition = layer.state.mousePosition:get()

												local relativePosition = mousePosition
													- graphContainer:get().AbsolutePosition
												local horizontalProgress = relativePosition.X
													/ graphContainer:get().AbsoluteSize.X
												local verticalProgress = relativePosition.Y
													/ graphContainer:get().AbsoluteSize.Y

												return UDim2.new(horizontalProgress, 0, verticalProgress, 0)
											end),
											30,
											1
										),
										Size = UDim2.new(0, 16, 0, 16),
										Visible = Computed(function()
											-- if we're within 0.01 of anmother point, don't show the point
											if graphContainer:get() == nil or isDraggingHandle:get() then
												return false
											end

											local mousePosition = layer.state.mousePosition:get()

											local relativePosition = mousePosition
												- graphContainer:get().AbsolutePosition
											local horizontalProgress = relativePosition.X
												/ graphContainer:get().AbsoluteSize.X
											local verticalProgress = 1
												- relativePosition.Y / graphContainer:get().AbsoluteSize.Y

											for _, point in (points:get()) do
												local peekedPoint = peek(point)

												if
													math.abs(peekedPoint.index - horizontalProgress) < 0.025
													and math.abs(peekedPoint.value - verticalProgress) < 0.05
												then
													return false
												end
											end

											return true
										end),
										[Children] = {
											New("Frame")({
												Name = "GraphDot",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Computed(function()
													return useColor("Dot").color
												end),
												BackgroundTransparency = 0.5,
												Position = UDim2.new(0.5, 0, 0.5, 0),
												Size = UDim2.new(0, 8, 0, 8),
												[Children] = {
													New("UICorner")({
														CornerRadius = UDim.new(1, 0),
													}),
												},
											}),
										},
									})
								end

								return nil
							end, Clean),
							ForPairs(points, function(index, value: point)
								local isHovering = Value(false)
								local isDragging = Value(false)
								local isThisContextVisible = Value(false)

								local easingModeOptions = {}
								local easingDirectionOptions = {}

								for easingMode, _ in easingModes do
									local name = easingMode:sub(1, 1):upper() .. easingMode:sub(2)

									table.insert(easingModeOptions, {
										Label = name,
										Callback = function()
											local newValue = table.clone(value:get())
											newValue.easingMode = easingMode

											value:set(newValue)

											applyChanges()
											rerenderGraph()
										end,
										Slots = {
											Right = function(useSlotColor, _)
												return Computed(function()
													return icon({
														Icon = "check",
														Color = Computed(function()
															local color = useSlotColor("Text")

															if value:get().easingMode ~= easingMode then
																color.transparency = 1
															end

															return color
														end),
													})
												end, Clean)
											end,
										},
									})
								end

								for _, direction in { "In", "Out", "InOut" } do
									table.insert(easingDirectionOptions, {
										Label = direction,
										Callback = function()
											local newValue = table.clone(value:get())
											newValue.direction = direction
											value:set(newValue)

											rerenderGraph()
											applyChanges()
										end,
										Slots = {
											Right = function(useSlotColor, _)
												return Computed(function()
													return icon({
														Icon = "check",
														Color = Computed(function()
															local color = useSlotColor("Text")

															if value:get().direction ~= direction then
																color.transparency = 1
															end

															return color
														end),
													})
												end, Clean)
											end,
										},
									})
								end

								local graphPoint = contextMenu(
									New("ImageButton")({
										Name = "GraphPoint",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = Computed(function()
											local usedValue = value:get()
											return UDim2.new(usedValue.index, 0, 1 - usedValue.value, 0)
										end),
										Size = UDim2.new(0, 16, 0, 16),
										[Event("MouseButton1Click")] = function()
											selectedDot:set(value)
										end,
										[Event("MouseEnter")] = function()
											isHovering:set(true)
										end,
										[Event("MouseLeave")] = function()
											isHovering:set(false)
										end,
										[Children] = {
											New("Frame")({
												Name = "GraphDot",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Tween(
													Computed(function()
														if selectedDot:get() == value then
															return useColor("SelectedDot").color
														end

														return useColor("Dot").color
													end),
													TweenInfo.new(
														0.3,
														Enum.EasingStyle.Exponential,
														Enum.EasingDirection.Out
													)
												),
												Position = UDim2.new(0.5, 0, 0.5, 0),
												Size = UDim2.new(0, 8, 0, 8),
												[Children] = {
													New("UICorner")({
														CornerRadius = UDim.new(1, 0),
													}),
												},
											}),
										},
									}),
									{
										Color = "gray",
										Variant = "default",
										Enabled = true,
										Visible = Computed(function()
											return isThisContextVisible:get()
												and isContextVisible:get() == isThisContextVisible
										end),
										EnabledLogic = function(wouldBeEnabled)
											if not wouldBeEnabled then
												isThisContextVisible:set(false)
												isContextVisible:set(false)
											end

											return false
										end,
										Options = {
											{
												{
													Label = "Style",
													Options = {
														easingModeOptions,
													},
												},
												{
													Label = "Direction",
													Disabled = Computed(function()
														return value:get().easingMode == "linear"
															or value:get().easingMode == "bezier"
													end),
													Options = {
														easingDirectionOptions,
													},
												},
												(index ~= 1 and index ~= #points:get()) and {
													Color = "red",
													Label = "Delete",
													Icon = "trash",
													Callback = function()
														local oldPoints = points:get()
														table.remove(oldPoints, index)
														points:set(oldPoints)

														if selectedDot:get() == value then
															selectedDot:set(nil)
														end

														rerenderGraph()
														applyChanges()
													end,
												} or nil,
											},
										},
									}
								)

								inputCollector({
									ReferenceObject = graphPoint,
									Visible = Computed(function()
										return isHovering:get() or isDragging:get() and not isThisContextVisible:get()
									end),
									OnInputEnded = function(userInput)
										if userInput.UserInputType == Enum.UserInputType.MouseButton2 then
											isThisContextVisible:set(not isThisContextVisible:get())

											if
												isContextVisible:get() == isThisContextVisible
												and not isThisContextVisible:get()
											then
												isContextVisible:set(false)
											else
												local currentValue = isContextVisible:get()

												if typeof(currentValue) == "table" then
													currentValue:set(false)
												end

												isContextVisible:set(isThisContextVisible)
											end
										end
									end,
									OnMouseButton1Changed = function(pressing)
										if pressing then
											isDragging:set(true)

											if selectedDot:get() ~= value then
												selectedDot:set(value)
											end
										else
											isDragging:set(false)

											local oldPoints = points:get()
											oldPoints[index] = value
											points:set(oldPoints)

											rerenderGraph()
											applyChanges()
										end
									end,
									OnMouseMove = function(position)
										if isDragging:get() then
											-- get position relative to the graph
											local relativePosition = position - graphContainer:get().AbsolutePosition

											local clampedPosition = Vector2.new(
												math.clamp(relativePosition.X, 0, graphContainer:get().AbsoluteSize.X),
												math.clamp(relativePosition.Y, 0, graphContainer:get().AbsoluteSize.Y)
											)

											local horizontalProgress = clampedPosition.X
												/ graphContainer:get().AbsoluteSize.X

											if index == 1 or index == #points:get() then
												horizontalProgress = index == 1 and 0 or 1
											end

											local verticalProgress = 1
												- clampedPosition.Y / graphContainer:get().AbsoluteSize.Y

											local newValue = table.clone(value:get())
											newValue.index = math.clamp(horizontalProgress, 0.001, 0.999)
											newValue.value = verticalProgress

											if newValue.envelope > 0 then
												local distanceToBounds =
													math.clamp(math.min(1 - newValue.value, newValue.value), 0, 1)
												newValue.envelope = math.clamp(newValue.envelope, 0, distanceToBounds)
											end

											-- not necessary, but this is so the ui feels more responsive
											inputTimeText:set(tostring(newValue.index))
											inputValueText:set(tostring(newValue.value))
											inputEnvelopeText:set(tostring(newValue.envelope))

											value:set(newValue)

											rerenderGraph()
										end
									end,
								})

								return index, graphPoint
							end, Clean),
						},
					}),
				},
			}),
			New("Frame")({
				Name = "Toolbar",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
					}),
					New("Frame")({
						Name = "TimeValue",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),
							text({
								Text = "Time",
								Appearance = props.useColor("Text", true),
								Size = UDim2.new(0, 0, 0, 24),
								AutomaticSize = Enum.AutomaticSize.X,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							input({
								Variant = "default",
								Color = "gray",
								Disabled = Computed(function()
									return processedSelectedDot:get() == nil
								end),
								Text = inputTimeText,
								Size = UDim2.new(0, 48, 0, 24),
								OnFocusLost = function(currentText)
									local dot = selectedDot:get()

									if dot then
										local newIndex = tonumber(currentText)

										if not newIndex then
											return
										end

										local newDot = table.clone(dot:get())
										newDot.index = math.clamp(newIndex, 0.001, 0.999)

										local pointIndex = table.find(points:get(), dot)
										if pointIndex == 1 or pointIndex == #points:get() then
											newDot.index = pointIndex == 1 and 0 or 1
										end

										inputTimeText:set(tostring(newDot.index))
										dot:set(newDot, true)

										rerenderGraph()
										applyChanges()
									end
								end,
							}),
						},
					}),
					New("Frame")({
						Name = "Value",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),
							text({
								Text = "Value",
								Appearance = props.useColor("Text", true),
								Size = UDim2.new(0, 0, 0, 24),
								AutomaticSize = Enum.AutomaticSize.X,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							input({
								Variant = "default",
								Color = "gray",
								Disabled = Computed(function()
									return processedSelectedDot:get() == nil
								end),
								Text = inputValueText,
								Size = UDim2.new(0, 48, 0, 24),
								OnFocusLost = function(currentText)
									local dot = selectedDot:get()

									if dot then
										local newValue = tonumber(currentText)

										if not newValue then
											return
										end

										local newDot = table.clone(dot:get())
										newDot.value = math.clamp(newValue, 0, 1)

										inputValueText:set(tostring(newDot.value))
										dot:set(newDot, true)

										rerenderGraph()
										applyChanges()
									end
								end,
							}),
						},
					}),
					New("Frame")({
						Name = "Envelope",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),
							text({
								Text = "Envelope",
								Appearance = props.useColor("Text", true),
								Size = UDim2.new(0, 0, 0, 24),
								AutomaticSize = Enum.AutomaticSize.X,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							input({
								Variant = "default",
								Color = "gray",
								Disabled = Computed(function()
									return processedSelectedDot:get() == nil
								end),
								Text = inputEnvelopeText,
								Size = UDim2.new(0, 48, 0, 24),
								OnFocusLost = function(currentText)
									local dot = selectedDot:get()

									if dot then
										local newEnvelope = tonumber(currentText)

										if not newEnvelope then
											return
										end

										local newDot = table.clone(dot:get())
										newDot.envelope = math.clamp(newEnvelope, 0, 1)

										inputEnvelopeText:set(tostring(newDot.envelope), true)
										dot:set(newDot, true)

										rerenderGraph()
										applyChanges()
									end
								end,
							}),
						},
					}),
					button({
						Size = UDim2.new(0, 24, 0, 24),
						Icon = "trash",
						Variant = "solid",
						Color = "red",
						ButtonText = "Delete",
						Stroke = props.useColor("Line", true),
						OnClick = function()
							local dot = selectedDot:get()

							if dot then
								local oldPoints = points:get()
								local index = table.find(oldPoints, dot)

								if index then
									table.remove(oldPoints, index)
									points:set(oldPoints)

									if selectedDot:get() == dot then
										selectedDot:set(nil)
									end

									rerenderGraph()
									applyChanges()
								end
							end
						end,
					}),
				},
			}),
		},
	}))

	local savedData = props.Instance:GetAttribute("_vfxEditorGraphData")
	local decodedPoints: { point } = savedData and HttpService:JSONDecode(savedData) or nil

	if decodedPoints then
		local exportedGraph = exportGraph(GRAPH_RESOLUTION_EXPORT, decodedPoints)

		if not numberSequenceEq(props.Value:get(false), numberTableToSequence(exportedGraph)) then
			-- when a mismatch is detected, open a modal to ask the user if they want to load the saved data
			local isVisible = Value(true)
			local hasPressed = false

			modal(sequenceEditor:get(), {
				Visible = isVisible,
				Padding = UDim.new(0, 8),
				Content = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					text({
						Appearance = useColor("Title", true),
						Text = {
							Label = "Overwrite saved data?",
							TextSize = 18,
							Font = Font.new(use(theme.global.font).Family, Enum.FontWeight.Bold),
						},
						AutomaticSize = Enum.AutomaticSize.XY,
					}),
					text({
						Appearance = useColor("Description", true),
						Text = {
							Label = concatMultilineString(
								"The data saved for this graph does not match the current data.",
								"Would you like to overwrite the current data with the saved data?",
								"<b>All changes made without the plugin will be lost.</b>"
							),
							TextSize = 14,
							Font = theme.global.font,
						},
						Size = UDim2.new(0, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.XY,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
					}),
					New("Frame")({
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							button({
								Color = "gray",
								Variant = "ghost",
								ButtonText = "Use current data",
								AutomaticSize = Enum.AutomaticSize.XY,
								Margin = 6,
								OnClick = function()
									if hasPressed then
										return
									end

									hasPressed = true

									isVisible:set(false)

									local value = props.Value:get(false)
									local positionData = {}

									for _, keypoint in value.Keypoints do
										table.insert(
											positionData,
											Value({
												index = keypoint.Time,
												value = keypoint.Value,
												envelope = keypoint.Envelope,
												easingMode = "linear",
												direction = "InOut",
											})
										)
									end

									points:set(positionData)
									graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, positionData))
								end,
							}),
							button({
								Color = "red",
								Variant = "solid",
								ButtonText = "Overwrite",
								AutomaticSize = Enum.AutomaticSize.XY,
								Margin = 6,
								OnClick = function()
									if hasPressed then
										return
									end

									hasPressed = true

									for i, point in decodedPoints do
										decodedPoints[i] = Value(point)
									end

									isVisible:set(false)
									points:set(decodedPoints)
									graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, decodedPoints))
									props.Value:set(numberTableToSequence(exportedGraph))
								end,
							}),
						},
					}),
				},
			})
		else
			for i, point in decodedPoints do
				decodedPoints[i] = Value(point)
			end

			points:set(decodedPoints)
			graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, decodedPoints))
		end
	else
		local value = props.Value:get(false)
		local positionData = {}

		for _, keypoint in value.Keypoints do
			table.insert(
				positionData,
				Value({
					index = keypoint.Time,
					value = keypoint.Value,
					envelope = keypoint.Envelope,
					easingMode = "linear",
					direction = "InOut",
				})
			)
		end

		points:set(positionData)
		graphPoints:set(exportGraph(GRAPH_RESOLUTION_RENDER, positionData))
	end

	return component
end

return numberSequenceEditor
