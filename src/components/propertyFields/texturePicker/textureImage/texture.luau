local fusion = require("@packages/fusion")
local Hydrate = fusion.Hydrate
local New = fusion.New

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

type props = {
	Image: string,
	FlipbookMode: nil | "2x2" | "4x4" | "8x8",
}

local function texture(props: props)
	local component = New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = props.Image,
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "ImageLabel"))
end

return texture
