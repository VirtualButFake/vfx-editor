local AssetService = game:GetService("AssetService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Hydrate = fusion.Hydrate
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

type props = {
	Image: string,
	FlipbookMode: nil | "2x2" | "4x4" | "8x8",
}

local function texture(props: props)
	local editableImage = Value(nil)
	local didFinish = Value(false)

	task.spawn(function()
		pcall(function()
			editableImage:set(AssetService:CreateEditableImageAsync(props.Image))
		end)

		didFinish:set(true)
	end)

	local component = New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = Computed(function()
			if didFinish:get() and editableImage:get() == nil then
				return props.Image
			end

			return ""
		end),
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		[Children] = {
			editableImage,
		},
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "ImageLabel"))
end

return texture
