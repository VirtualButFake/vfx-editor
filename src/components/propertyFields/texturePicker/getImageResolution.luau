local HttpService = game:GetService("HttpService")

local cachedImages = {}

-- Function to get the width and height from a PNG buffer
local function getPngDimensions(pngBuffer)
	local header = pngBuffer:sub(1, 8)
	if header == "\137PNG\r\n\26\n" then
		local width = pngBuffer:byte(17) * 256 ^ 3
			+ pngBuffer:byte(18) * 256 ^ 2
			+ pngBuffer:byte(19) * 256
			+ pngBuffer:byte(20)
		local height = pngBuffer:byte(21) * 256 ^ 3
			+ pngBuffer:byte(22) * 256 ^ 2
			+ pngBuffer:byte(23) * 256
			+ pngBuffer:byte(24)
		return Vector2.new(width, height)
	end

	return nil
end

local function requestImage(id)
	if cachedImages[id] then
		return cachedImages[id]
	end

	local rawId = id:match("rbxassetid://(%d+)")

	if not rawId then
		return Vector2.new(0, 0)
	end

	local image = HttpService:RequestAsync({
		Url = "https://assetdelivery.roproxy.com/v1/asset?id=" .. rawId,
		Method = "GET",
	})

	if image.Success then
		local dimensions = getPngDimensions(image.Body)
		if dimensions then
			cachedImages[id] = dimensions
		end

		return cachedImages[id]
	else
		return Vector2.new(0, 0)
	end
end

return requestImage
