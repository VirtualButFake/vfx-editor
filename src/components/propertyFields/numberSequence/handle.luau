local fusion = require("@packages/fusion")

local viewport2D = require("@components/viewport2D")

type props = {
	HandlePosition: Vector2,
	PointPosition: Vector2,
	Color: Color3,
}

-- This component only *renders* the bezier handles. The actual handle functionality is in editor.lua
local function bezierHandle(props: props)
	return function(
		convertToVector: viewport2D.convertToVector,
		bounds: fusion.Computed<viewport2D.bounds>,
		size: fusion.Value<Vector2>
	)
		if size:get() == nil then
			return {}
		end

		local usedBounds = bounds:get()
		local rangeWidth = usedBounds.x.max - usedBounds.x.min
		local verticalScale = rangeWidth / 2 * 2

		local circleSize = verticalScale * (8 / size:get().Y)
		local lineSize = verticalScale * (2 / size:get().Y)

		local handlePosition = convertToVector(props.HandlePosition)
		local pointPosition = convertToVector(props.PointPosition)
		local inbetweenPosition = (handlePosition + pointPosition) / 2

		local circle = Instance.new("Part")
		circle.Size = Vector3.new(circleSize, circleSize, circleSize)
		circle.Shape = Enum.PartType.Ball
		circle.Color = props.Color
		circle.Position = handlePosition

		local rot = math.atan2(handlePosition.Y - pointPosition.Y, handlePosition.X - pointPosition.X)
		local distance = (handlePosition - pointPosition).Magnitude

		local line = Instance.new("Part")
		line.Color = props.Color
		line.Size = Vector3.new(distance, lineSize, circleSize)
		line.CFrame = CFrame.new(inbetweenPosition) * CFrame.Angles(0, 0, rot)
		line.Parent = circle

		return circle
	end
end

return bezierHandle
