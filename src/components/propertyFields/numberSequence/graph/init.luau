local InsertService = game:GetService("InsertService")

local fusion = require("@packages/fusion")

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Ref = fusion.Ref

local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local viewport2D = require("@components/viewport2D")

local cube = InsertService:LoadAsset(17679216306):FindFirstChild("Cube")
local node = script.assets.Node
local cap = script.assets.Cap

type graphKeypoint = {
	index: number,
	value: number,
	envelope: number,
}

type props = {
	Points: fusion.CanBeState<{ graphKeypoint }>,
	LineColor: Color3,
	EnvelopeColor: Color3,
	PixelScale: number, -- thickness
	Resolution: number,
}

function interpolate(a: number, b: number, alpha: number): number
	a = not a and 0 or a :: number
	b = not b and 0 or b :: number

	return a * (1 - alpha) + b * alpha
end

function extrapolate(a: graphKeypoint, b: graphKeypoint, alpha: number, valueName: string)
	local aValue = a[valueName] or 0
	local bValue = b[valueName] or 0

	return (aValue + (alpha - a.index) / (b.index - a.index) * (bValue - aValue))
end

local function getPoint(points: { graphKeypoint }, pointIndex): graphKeypoint
	local lastPoint: number
	local lastIndex: number

	for i, point in points do
		if lastPoint then
			if pointIndex > lastPoint and pointIndex < point.index then
				-- falls inbetween
				local perc = (pointIndex - lastPoint) / (point.index - lastPoint)

				return {
					value = interpolate(points[lastIndex].value, points[i].value, perc),
					index = pointIndex,
					envelope = interpolate(points[lastIndex].envelope, points[i].envelope, perc),
				}
			end

			if pointIndex == point.index and i then
				return table.clone(point)
			end
		end

		lastPoint = point.index
		lastIndex = i
	end

	return {
		index = pointIndex,
		value = pointIndex > points[#points].index
				and extrapolate(points[#points - 1], points[#points], pointIndex, "value")
			or extrapolate(points[1], points[2], pointIndex, "value"),
		envelope = pointIndex > points[#points].index
				and extrapolate(points[#points - 1], points[#points], pointIndex, "envelope")
			or extrapolate(points[1], points[2], pointIndex, "envelope"),
	}
end

local function compressPoints(points: { graphKeypoint }, resolution: number, start: number, bounds: viewport2D.bounds)
	resolution = math.min(#points - 1, resolution)
	local rangeWidth = bounds.x.max - bounds.x.min
	local resolutionIncrement = rangeWidth / resolution
	local compressedPoints: { graphKeypoint } = {}

	for i = 0, resolution + 1 do
		table.insert(compressedPoints, getPoint(points, start + (resolutionIncrement * i)))
	end

	local validPoints = {}
	local lastPoint: graphKeypoint?

	for i, point in ipairs(compressedPoints) do
		if lastPoint and points[i - 2] then
			local slopes = {}

			-- compare self to slope between i-2 and i-1 and exchange self with i-1 if same
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
				local distanceToBounds =
					math.clamp(math.min(bounds.y.max - point.value, point.value - bounds.y.min), 0, bounds.y.max)
				local lastDistanceToBounds = math.clamp(
					math.min(bounds.y.max - lastPoint.value, lastPoint.value - bounds.y.min),
					0,
					bounds.y.max
				)

				local envelopeConstrained = math.clamp(point.envelope, 0, distanceToBounds)
				local lastEnvelopeConstrained = math.clamp(lastPoint.envelope, 0, lastDistanceToBounds)

				local diffX = point.index - lastPoint.index
				local diffY = envelopeConstrained - lastEnvelopeConstrained
				slopes[2][1] = diffY / diffX
			end

			do
				local distanceToBounds = math.clamp(
					math.min(bounds.y.max - points[i - 2].value, points[i - 2].value - bounds.y.min),
					0,
					bounds.y.max
				)
				local lastDistanceToBounds = math.clamp(
					math.min(bounds.y.max - lastPoint.value, lastPoint.value - bounds.y.min),
					0,
					bounds.y.max
				)

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
				table.insert(validPoints, point)
				lastPoint = point
				continue
			else
				-- replace i-1
				validPoints[#validPoints] = point
				lastPoint = point
				continue
			end
		end

		table.insert(validPoints, point)
		lastPoint = point
	end

	return validPoints
end

local function graphComponent(props: props)
	local graphKeypoints = Computed(function()
		local points = use(props.Points)
		local dereferencedKeypoints = {}

		for _, point in ipairs(points) do
			table.insert(dereferencedKeypoints, {
				index = use(point.index),
				value = use(point.value),
				envelope = use(point.envelope),
			})
		end

		return dereferencedKeypoints
	end)

	local pointBase = node:Clone()
	pointBase.Color = props.LineColor

	local pointCap = cap:Clone()
	pointCap.Color = props.LineColor
	pointCap.Parent = pointBase

	return function(
		convertToVector: viewport2D.convertToVector,
		bounds: fusion.Computed<viewport2D.bounds>,
		size: fusion.Value<Vector2>
	)
		if size:get() == nil then
			return {}
		end

		-- not using forPairs as the values are inherently linked, so going value by value is not needed
		local usedBounds = bounds:get()
		local rangeWidth = usedBounds.x.max - usedBounds.x.min
		local verticalScale = rangeWidth / 2 * 2
		local pxScale = props.PixelScale / size:get().Y
		local lineSize = verticalScale * pxScale
		pointCap.Size = Vector3.new(lineSize, lineSize, lineSize)

		local points = compressPoints(graphKeypoints:get(), props.Resolution, usedBounds.x.min, usedBounds)
		local children = {}

		local lastPoint: graphKeypoint?
		local lineData = {}

		for i, point in points do
			if lastPoint then
				local startPosition = convertToVector(Vector2.new(lastPoint.index, lastPoint.value))
				local endPosition = convertToVector(Vector2.new(point.index, point.value))
				local inbetweenPosition = (startPosition + endPosition) / 2

				local rot = math.atan2(endPosition.Y - startPosition.Y, endPosition.X - startPosition.X)
				local distance = (endPosition - startPosition).Magnitude

				local line = pointBase:Clone()
				line.Size = Vector3.new(distance, 1, lineSize)
				line.CFrame = CFrame.new(inbetweenPosition) * CFrame.Angles(0, 0, rot)

				line.Cap.CFrame = CFrame.new(endPosition)

				if point.envelope ~= 0 or lastPoint.envelope ~= 0 then
					local distanceToBounds = math.clamp(
						math.min(usedBounds.y.max - point.value, point.value - usedBounds.y.min),
						0,
						usedBounds.y.max
					)
					local lastDistanceToBounds = math.clamp(
						math.min(usedBounds.y.max - lastPoint.value, lastPoint.value - usedBounds.y.min),
						0,
						usedBounds.y.max
					)

					local envelopeConstrained = math.clamp(point.envelope, 0, distanceToBounds)
					local lastEnvelopeConstrained = math.clamp(lastPoint.envelope, 0, lastDistanceToBounds)

					local verticalSize = convertToVector(envelopeConstrained + point.value) - endPosition.Y
					local lastEnvelope = convertToVector(lastEnvelopeConstrained + lastPoint.value) - startPosition.Y

					local envelopeCube = cube:Clone()
					envelopeCube.Color = props.EnvelopeColor
					envelopeCube.Parent = line

					local pastSegment = lineData[i - 1]

					envelopeCube.TopLeft.WorldPosition = pastSegment and pastSegment[1] - Vector3.new(0.001, 0, 0)
						or startPosition + Vector3.new(0, lastEnvelope, 0)
					envelopeCube.TopRight.WorldPosition = endPosition + Vector3.new(0, verticalSize, 0)

					envelopeCube.BottomLeft.WorldPosition = pastSegment and pastSegment[2] - Vector3.new(0.001, 0, 0)
						or startPosition - Vector3.new(0, lastEnvelope, 0)
					envelopeCube.BottomRight.WorldPosition = endPosition - Vector3.new(0, verticalSize, 0)

					lineData[i] = {
						envelopeCube.TopRight.WorldPosition,
						envelopeCube.BottomRight.WorldPosition,
					}
				end

				table.insert(children, line)
			end

			lastPoint = point
		end

		return children
	end
end

return graphComponent
