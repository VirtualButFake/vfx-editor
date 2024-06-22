local flipbook = require("./flipbook")
local texture = require("./texture")

type props = {
	Image: string,
	FlipbookMode: nil | "2x2" | "4x4" | "8x8",
}

local function textureImage(props: props)
	if props.FlipbookMode then
		-- for some reason props.FlipbookMode does not evaluate to not nil after this, so we typecast props to any
		return flipbook(props :: any)
	else
		return texture(props)
	end
end

return textureImage
