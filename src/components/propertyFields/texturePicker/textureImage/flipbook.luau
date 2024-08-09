local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local Hydrate = fusion.Hydrate
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

local requestImage = require("../getImageResolution")

type props = {
	Image: string,
	FlipbookMode: "2x2" | "4x4" | "8x8",
}

local FLIPBOOK_MAPS = {
	["2x2"] = Vector2.new(2, 2),
	["4x4"] = Vector2.new(4, 4),
	["8x8"] = Vector2.new(8, 8),
}

local function flipbook(props: props)
	local imageSize = Vector2.new(0, 0)

	local resolution = FLIPBOOK_MAPS[props.FlipbookMode].X * FLIPBOOK_MAPS[props.FlipbookMode].Y
	local cleanup = {}

	local editableImage = Value(nil)
	local didFinish = Value(false)

	local component

	component = New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = Computed(function()
			if didFinish:get() and editableImage:get() == nil then
				return props.Image
			end

			return ""
		end),
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		[Cleanup] = cleanup,
		[Children] = {
			editableImage,
		},
	})

	task.spawn(function()
		pcall(function()
			editableImage:set(AssetService:CreateEditableImageAsync(props.Image))
		end)

		didFinish:set(true)

		if editableImage:get(false) == nil then
			imageSize = requestImage(props.Image)

			if imageSize == nil then
				return
			end

			component.ImageRectSize = Vector2.new(
				imageSize.X / FLIPBOOK_MAPS[props.FlipbookMode].X,
				imageSize.Y / FLIPBOOK_MAPS[props.FlipbookMode].Y
			)
		else
			imageSize = editableImage:get(false).Size

			component.ImageRectSize = Vector2.new(
				imageSize.X / FLIPBOOK_MAPS[props.FlipbookMode].X,
				imageSize.Y / FLIPBOOK_MAPS[props.FlipbookMode].Y
			)
		end
	end)

	local timer = 0
	table.insert(
		cleanup,
		RunService.RenderStepped:Connect(function(dt)
			if imageSize == nil then
				return
			end

			timer += dt

			local frame = math.floor(timer * resolution) % resolution
			local x = frame % FLIPBOOK_MAPS[props.FlipbookMode].X
			local y = math.floor(frame / FLIPBOOK_MAPS[props.FlipbookMode].X)

			local offset = Vector2.new(
				x * imageSize.X / FLIPBOOK_MAPS[props.FlipbookMode].X,
				y * imageSize.Y / FLIPBOOK_MAPS[props.FlipbookMode].Y
			)

			component.ImageRectOffset = offset
		end)
	)

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "ImageLabel"))
end

return flipbook
