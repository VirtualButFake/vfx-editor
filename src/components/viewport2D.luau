local fusion = require("@packages/fusion")
local Children = fusion.Children
local Hydrate = fusion.Hydrate
local New = fusion.New
local Out = fusion.Out
local Ref = fusion.Ref

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForValues = fusion.ForValues
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use
local propertyProvider = fusionUtils.propertyProvider

local function convertTo3D(value: number, minBound: number, maxBound: number, offset: number): number
	return (-offset / 2) + ((offset / 2 - (-offset / 2)) * (value - minBound) / (maxBound - minBound))
end

local function convertToVectorBase(value1: number, value2: number, bounds: bounds, offset: Vector2): Vector3
	local xPos = convertTo3D(value1, bounds.x.min, bounds.x.max, offset.X)
	local yPos = convertTo3D(value2, bounds.y.min, bounds.y.max, offset.Y)
	return Vector3.new(xPos, yPos, 0)
end

export type convertToVector = ((value: Vector2) -> Vector3) & ((value: number) -> number)

export type bounds = {
	x: {
		min: number,
		max: number,
	},
	y: {
		min: number,
		max: number,
	},
}

type boundsReactive = {
	x: {
		min: fusion.CanBeState<number>,
		max: fusion.CanBeState<number>,
	},
	y: {
		min: fusion.CanBeState<number>,
		max: fusion.CanBeState<number>,
	},
}

type props = {
	BackgroundColor: Color3,
	Bounds: boundsReactive,
	Corner: fusion.CanBeState<UDim>,
	Children: fusion.CanBeState<
		{
			(
				convertToVector: convertToVector,
				bounds: fusion.Computed<bounds>,
				containerSize: fusion.Value<Vector2>
			) -> { Instance }
		}
	>,
}

local FOV_CONSTANT = 0.017454177141189575
--local CAMERA_ORIENTATION = CFrame.new(Vector3.new(), Vector3.new(0, 0, -1))

local function viewport2D(props: props)
	local containerSize = Value(Vector2.new(0, 0))
	local processedBounds = Computed(function()
		return {
			x = {
				min = use(props.Bounds.x.min),
				max = use(props.Bounds.x.max),
			},
			y = {
				min = use(props.Bounds.y.min),
				max = use(props.Bounds.y.max),
			},
		}
	end)

	local component = New("ViewportFrame")({
		Name = "Viewport2D",
		Ambient = Color3.new(1, 1, 1),
		BackgroundColor3 = props.BackgroundColor,
		BackgroundTransparency = 1,
		CurrentCamera = New("Camera")({
			CFrame = Computed(function()
				local rangeWidth = use(props.Bounds.x.max) - use(props.Bounds.x.min)
				return CFrame.new(0, 0, rangeWidth / FOV_CONSTANT)
			end),
			FieldOfView = 1,
		}),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(1, 1, 1),
		[Out("AbsoluteSize")] = containerSize,
		[Children] = {
			if props.Corner
				then New("UICorner")({
					CornerRadius = use(props.Corner),
				})
				else nil,
			New("WorldModel")({
				[Children] = {
					ForValues(props.Children, function(value)
						if containerSize:get() == nil then
							return
						end

						return use(value)(function(position)
							local rangeWidth = use(props.Bounds.x.max) - use(props.Bounds.x.min)
							local absoluteSize = containerSize:get()

							local aspectRatio = absoluteSize.X / absoluteSize.Y
							local horizontalScale = rangeWidth * aspectRatio
							local verticalScale = rangeWidth / 2 * 2

							local offset = Vector2.new(horizontalScale, verticalScale)

							local bounds = processedBounds:get()
							local usedPosition = use(position)

							if typeof(usedPosition) == "number" then
								return convertTo3D(usedPosition, bounds.y.min, bounds.y.max, offset.Y)
							end

							return convertToVectorBase(usedPosition.X, usedPosition.Y, bounds, offset)
						end, processedBounds, containerSize)
					end, Clean),
				},
			}),
		},
	})

	props.BackgroundColor = (nil :: any) :: Color3 -- i love this language

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "ViewportFrame"))
end

return viewport2D
