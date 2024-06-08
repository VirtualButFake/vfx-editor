local graphHandler = {}
graphHandler.__index = graphHandler

local InsertService = game:GetService("InsertService")

-- rojo can't import skinned meshes properly so we do it like this
local cube = InsertService:LoadAsset(17679216306):FindFirstChild("Cube")
local node = script.assets.Node
local cap = script.assets.Cap

local cameraOrientation = CFrame.new(Vector3.new(), Vector3.new(0, 0, -1))
-- this constant might seem hacky at first, but it's used as follows:
-- we set the camera's CFrame to CFrame.new(0, 0, rangeWidth / fovConstant), which makes sure that the entire rangewidth fits in the camera's view
-- this way we can treat the graph as 2D space, as if the camera had no FOV (since rangewidth is "2d")
local fovConstant = 0.017454177141189575

local function convertTo3D(value: number, minBound: number, maxBound: number, offset: number): number
	return (-offset / 2) + ((offset / 2 - (-offset / 2)) * (value - minBound) / (maxBound - minBound))
end

local function convertToVector(value1: number, value2: number, bounds: bounds, offset: Vector2): Vector3
	local xPos = convertTo3D(value1, bounds.x.min, bounds.x.max, offset.X)
	local yPos = convertTo3D(value2, bounds.y.min, bounds.y.max, offset.Y)
	return Vector3.new(xPos, yPos, 0)
end

function interpolate(a: number, b: number, alpha: number): number
	a = not a and 0 or a :: number
	b = not b and 0 or b :: number

	return a * (1 - alpha) + b * alpha
end

function extrapolate(a: point, b: point, alpha: number, valueName: string)
	local aValue = a[valueName] or 0
	local bValue = b[valueName] or 0

	return (aValue + (alpha - a.index) / (b.index - a.index) * (bValue - aValue))
end

local function getPoint(points: { point }, pointIndex): point
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

local function compressPoints(points: { point }, resolution: number, rangeWidth: number, start: number, bounds: bounds)
	resolution = math.min(#points - 1, resolution)
	local resolutionIncrement = rangeWidth / resolution
	local compressedPoints: { point } = {}

	for i = 0, resolution + 1 do
		table.insert(compressedPoints, getPoint(points, start + (resolutionIncrement * i)))
	end

	local validPoints = {}
	local lastPoint: point?

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
				if math.abs(slope[1] - slope[2]) > 1e-6 then
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

local function convertToPoints(points: { point | number }): { point }
	local newPoints: { point } = {}

	for idx, point in pairs(points) do
		if typeof(point) == "number" then
			table.insert(newPoints, {
				index = idx,
				value = point,
				envelope = 0,
			})
		else
			if point.envelope == nil then
				point.envelope = 0
			end

			table.insert(newPoints, point)
		end
	end

	return newPoints
end

function graphHandler.new(
	points: { [number]: number } | { point },
	bounds: bounds,
	color: Color3,
	envelopeColor: Color3,
	pxScale: number,
	viewportCorner: number?
): graph
	if #points < 2 then
		error("Not enough points to draw a graph.")
	end

	local graph = {
		bounds = bounds,
		color = color,
		envelopeColor = envelopeColor,
		pxScale = pxScale or 1,
	}

	local container = Instance.new("ViewportFrame")
	container.BackgroundColor3 = color
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Name = "GraphContainer"
	container.Ambient = Color3.fromRGB(255, 255, 255)
	container.LightColor = Color3.fromRGB(255, 255, 255)
	container.LightDirection = Vector3.new(1, 1, 1)

	if viewportCorner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, viewportCorner)
		corner.Parent = container
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = container

	local camera = Instance.new("Camera")
	camera.FieldOfView = 1
	camera.CFrame = cameraOrientation * CFrame.new(0, 0, -bounds.x.max - bounds.x.min)
	container.CurrentCamera = camera

	graph._camera = camera
	graph._container = container
	graph._worldmodel = worldModel
	graph.points = convertToPoints(points)

	return setmetatable(graph, graphHandler) :: graph
end

function graphHandler._updateRender(self: graph, frame: GuiObject, resolution: number)
	local rangeWidth = math.clamp(self.bounds.x.max - self.bounds.x.min, 0, #self.points)

	local absoluteSize = frame.AbsoluteSize
	absoluteSize = Vector2.new(math.round(absoluteSize.X / 2) * 2, math.round(absoluteSize.Y / 2) * 2)
	self._container.Size = UDim2.fromOffset(absoluteSize.X, absoluteSize.Y)

	local aspectRatio = absoluteSize.X / absoluteSize.Y
	local horizontalScale = rangeWidth * aspectRatio
	local verticalScale = rangeWidth / 2 * 2

	local pxScale = self.pxScale / absoluteSize.Y
	local lineSize = verticalScale * pxScale

	local offset = Vector2.new(horizontalScale, verticalScale)

	local pointBase = node:Clone()
	pointBase.Color = self.color

	local pointCap = cap:Clone()
	pointCap.Size = Vector3.new(lineSize, lineSize, lineSize)
	pointCap.Color = self.color
	pointCap.Parent = pointBase

	self._worldmodel:ClearAllChildren()

	local validPoints = compressPoints(self.points, resolution, rangeWidth, self.bounds.x.min, self.bounds)

	local lastPoint: point?
	local lineData = {}

	for i, point in validPoints do
		if lastPoint then
			local startPosition = convertToVector(lastPoint.index, lastPoint.value, self.bounds, offset)
			local endPosition = convertToVector(point.index, point.value, self.bounds, offset)
			local inbetweenPosition = (startPosition + endPosition) / 2

			local rot = math.atan2(endPosition.Y - startPosition.Y, endPosition.X - startPosition.X)
			local distance = (startPosition - endPosition).Magnitude

			local line = pointBase:Clone()
			line.Size = Vector3.new(distance, 1, lineSize)
			line.CFrame = CFrame.new(inbetweenPosition) * CFrame.Angles(0, 0, rot)

			line.Cap.CFrame = CFrame.new(startPosition)

			self.instances[point.index] = line

			if point.envelope ~= 0 or lastPoint.envelope ~= 0 then
				-- envelope is constrained to the minimum value of the vertical bounds
				local distanceToBounds = math.clamp(
					math.min(self.bounds.y.max - point.value, point.value - self.bounds.y.min),
					0,
					self.bounds.y.max
				)
				local lastDistanceToBounds = math.clamp(
					math.min(self.bounds.y.max - lastPoint.value, lastPoint.value - self.bounds.y.min),
					0,
					self.bounds.y.max
				)

				local envelopeConstrained = math.clamp(point.envelope, 0, distanceToBounds)
				local lastEnvelopeConstrained = math.clamp(lastPoint.envelope, 0, lastDistanceToBounds)

				local verticalSize = convertTo3D(
					envelopeConstrained + point.value,
					self.bounds.y.min,
					self.bounds.y.max,
					verticalScale
				) - endPosition.Y
				local lastEnvelope = convertTo3D(
					lastEnvelopeConstrained + lastPoint.value,
					self.bounds.y.min,
					self.bounds.y.max,
					verticalScale
				) - startPosition.Y

				local envelopeSquare = cube:Clone()
				envelopeSquare.Color = self.envelopeColor
				envelopeSquare.Parent = line

				local pastSegment = lineData[i - 1]

				envelopeSquare.TopLeft.WorldPosition = pastSegment and pastSegment[1] - Vector3.new(0.001, 0, 0)
					or startPosition + Vector3.new(0, lastEnvelope, 0)
				envelopeSquare.TopRight.WorldPosition = endPosition + Vector3.new(0, verticalSize, 0)

				envelopeSquare.BottomLeft.WorldPosition = pastSegment and pastSegment[2] - Vector3.new(0.001, 0, 0)
					or startPosition - Vector3.new(0, lastEnvelope, 0)
				envelopeSquare.BottomRight.WorldPosition = endPosition - Vector3.new(0, verticalSize, 0)

				lineData[i] = { envelopeSquare.TopRight.WorldPosition, envelopeSquare.BottomRight.WorldPosition }
			end

			line.Parent = self._worldmodel
		end

		lastPoint = point
	end
end

function graphHandler.render(self: graph, frame: GuiObject, resolution: number)
	if self._redrawConnection then
		self._redrawConnection:Disconnect()
	end

	self._worldmodel:ClearAllChildren()
	self._container.Parent = frame
	-- set our graph distance to size / fovConstant (this way we can treat it like 2D space, as in no FOV)
	local rangeWidth = self.bounds.x.max - self.bounds.x.min
	self._camera.CFrame = CFrame.new(0, 0, rangeWidth / fovConstant)

	self._worldmodel.Parent = self._container
	self.instances = {}
	self._updateRender(self, frame, resolution)

	self._redrawConnection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:render(frame, resolution)
	end)
end

function graphHandler.destroy(self: graph)
	self._redrawConnection:Disconnect()
	self._container:Destroy()
	self.bounds = nil :: any
	self.points = nil :: any
end

type bounds = {
	x: {
		min: number,
		max: number,
	},
	y: {
		min: number,
		max: number,
	},
}

type point = {
	index: number,
	value: number,
	envelope: number,
}

export type graph = typeof(setmetatable(
	{} :: {
		points: { point },
		instances: { Instance },
		bounds: bounds,
		color: Color3,
		envelopeColor: Color3,
		pxScale: number,
		_container: ViewportFrame,
		_worldmodel: WorldModel,
		_camera: Camera,
		_redrawConnection: RBXScriptConnection,
	},
	graphHandler
))

return graphHandler
