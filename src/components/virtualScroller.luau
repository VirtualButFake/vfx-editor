--!nonstrict
-- From https://github.com/bkmazefe/VirtualScroller
local Fusion = require("@packages/fusion")
local Children = Fusion.Children
local New = Fusion.New
local OnChange = Fusion.OnChange
local Ref = Fusion.Ref

local Clean = Fusion.cleanup
local Computed = Fusion.Computed
local ForPairs = Fusion.ForPairs
local Value = Fusion.Value

--[[
see also:
- https://blog.logrocket.com/virtual-scrolling-core-principles-and-basic-implementation-in-react/
- https://github.com/WICG/virtual-scroller
--]]

--[[
	Grid layout implementation of the original demo made by BoatBomber

    - with a few modifications for this plugin, such as using offset width values and a custom scrollingframe wrapper for visual consistency
]]

local fusionComponents = require("@packages/fusionComponents")
local scrollFrame = fusionComponents.common.scrollingFrame

export type props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	Visible: boolean?,
	ItemCount: Fusion.Value<number>,
	ItemHeight: Fusion.Value<number>,
	ItemWidth: Fusion.Value<number>,
	CanvasPosition: Fusion.Value<Vector2>,
	Deviation: number?,
	RenderItem: (index: number) -> Instance?,
	_debug: boolean?,
}

return function(props: props)
	local WindowSize = Value(Vector2.new())
	local CanvasPosition = props.CanvasPosition

	local numItems = props.ItemCount
	local itemHeight = props.ItemHeight
	local itemWidth = props.ItemWidth

	local deviation = props.Deviation or 1

	local Items = Computed(function()
		local numberOfItems = numItems:get()
		local canvasPos, windowSize, height, width =
			CanvasPosition:get(), WindowSize:get(), itemHeight:get(), itemWidth:get()
		local horizontalFit = math.clamp(windowSize.X / width, 1, math.huge)

		local minIndex = 0
		local maxIndex = -1
		if numberOfItems > 0 then
			minIndex = 1 + math.floor((canvasPos.y / height) * horizontalFit)
			maxIndex = math.ceil(((canvasPos.y + windowSize.y) / height) * horizontalFit)
			-- Add extra on either side for seamless load
			local diff = (maxIndex - minIndex) * deviation
			minIndex = math.clamp(minIndex - diff, 1, numberOfItems)
			maxIndex = math.clamp(maxIndex + diff, 1, numberOfItems)
		end

		local items = {}
		for i = minIndex, maxIndex do
			items[i] = true
		end

		return items
	end)

	local fullCanvasSize = Computed(function()
		local horizontalFit = (WindowSize:get().X / itemWidth:get())
		return UDim2.fromOffset(0, math.ceil(numItems:get() / horizontalFit) * itemHeight:get())
	end)

	local scrollRef = Value()
	local component = scrollFrame({
		Content = {
			ForPairs(Items, function(i)
				return i,
					New("Frame")({
						Name = "Index_" .. i,
						BackgroundColor3 = Color3.fromRGB(
							math.random(10, 255),
							math.random(10, 255),
							math.random(10, 255)
						),
						BackgroundTransparency = props._debug and 0.5 or 1,
						LayoutOrder = i,
						Position = Computed(function()
							local width = itemWidth:get()
							local scale = math.clamp(WindowSize:get().X / width, 1, math.huge) -- render at least 1 item per line

							return UDim2.new(
								0,
								width * ((i - 1) % math.floor(scale)),
								0,
								math.floor((i - 1) / math.floor(scale)) * itemHeight:get()
							)
						end),
						Size = Computed(function()
							return UDim2.new(0, itemWidth:get(), 0, itemHeight:get())
						end),
						[Children] = Computed(function()
							return props.RenderItem(i)
						end, Clean),
					})
			end, Clean),
		},
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.new(),
		ScrollingFrameProps = {
			CanvasPosition = CanvasPosition,
			CanvasSize = fullCanvasSize,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			[Ref] = scrollRef,
			[OnChange("AbsoluteWindowSize")] = function()
				if scrollRef:get() == nil then
					return
				end

				WindowSize:set(scrollRef:get().AbsoluteWindowSize)
			end,

			[OnChange("CanvasPosition")] = function()
				if scrollRef:get() == nil then
					return
				end

				-- Exit if the canvas hasn't moved enough to warrant rendering new items
				local distance = (CanvasPosition:get(false) - scrollRef:get().CanvasPosition).Magnitude
				local minimum = itemHeight:get(false)

				if distance < minimum then
					return
				end

				CanvasPosition:set(scrollRef:get().CanvasPosition)
			end,
		},

		Size = props.Size or UDim2.fromScale(1, 1),

		Visible = props.Visible == nil and true or props.Visible,
	})

	return component
end
