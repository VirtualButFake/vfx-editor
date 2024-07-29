-- this component exists due to the necessity of rendering components conditionally based on a scrolling frame, while they don't fit into a grid/list/whatever
-- it's important to realize that this component should not be used for just anything, but only things where the tradeoff is significant enough to warrant the extra complexity
-- it's primarily made for property fields that take up a lot of instances and lag the treeview
-- this way, performance is consistent across instances of different sizes
-- this component could probably be optimized further by batching the calculations

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Hydrate = fusion.Hydrate
local New = fusion.New

local Computed = fusion.Computed
local DoNothing = fusion.doNothing
local Observer = fusion.Observer
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local onDestroy = fusionUtils.onDestroy
local use = fusionUtils.use

local MIN_RERENDER_DISTANCE = 8
local POOLED_INSTANCES: {
	[Instance]: {
		[number]: {
			size: fusion.Value<Vector2>,
			position: fusion.Value<Vector2>,
			isRendered: fusion.Value<boolean>,
			enabled: fusion.Value<boolean>?,
			children: fusion.Value<any>,
			render: () -> Instance,
		}, -- table with gaps
	},
} =
	{}

type standaloneScrollerEntryProps = {
	FrameProperties: {
		[string]: any,
	}?,
	Enabled: fusion.CanBeState<boolean>?,
	Visible: fusion.CanBeState<boolean>?,
	Render: () -> Instance,
}

local function standaloneScrollingFrame(frame: ScrollingFrame)
	-- this manages the updating from canvas
	-- other instances will manage for themselves
	local scrollingFrame = frame

	if not scrollingFrame:IsA("ScrollingFrame") then
		scrollingFrame = frame:FindFirstChildWhichIsA("ScrollingFrame", true) :: ScrollingFrame

		if not scrollingFrame then
			warn("standaloneScrollingFrame: no ScrollingFrame found")
			return scrollingFrame
		end
	end

	if not POOLED_INSTANCES[scrollingFrame] then
		POOLED_INSTANCES[scrollingFrame] = {}

		local lastUpdatePosition = nil

		local scrollingFrameAbsolutePosition = Value(Vector2.new())
		local scrollingFrameWindowSize = Value(Vector2.new())
		local scrollingFramePosition = Value(Vector2.new())

		local function updateChildren()
			local windowSize = scrollingFrameWindowSize:get(false)
			local scrollPosition = scrollingFrameAbsolutePosition:get(false)

			for _, instance in POOLED_INSTANCES[scrollingFrame] do
				if instance.enabled and not instance.enabled:get(false) then
					continue
				end

				-- i have no idea if localizing these will make it faster
				local instancePosition = instance.position
				local instanceSize = instance.size
				local isRendered = instance.isRendered

				local selfPositionTopBound = instancePosition:get(false)
				local selfPositionBottomBound = instancePosition:get(false) + instanceSize:get(false)

				local rerenderDist = Vector2.new(MIN_RERENDER_DISTANCE, MIN_RERENDER_DISTANCE)

				local topBound = selfPositionTopBound - scrollPosition - rerenderDist
				local bottomBound = selfPositionBottomBound - scrollPosition + rerenderDist
				local inWindow = (topBound.X >= 0 and topBound.Y >= 0 or bottomBound.X >= 0 and bottomBound.Y >= 0)
					and (
						topBound.X <= windowSize.X and topBound.Y <= windowSize.Y
						or bottomBound.X <= windowSize.X and bottomBound.Y <= windowSize.Y
					)

				if inWindow and not isRendered:get(false) then
					local children = instance.children
					local render = instance.render

					if children:get(false) == nil then
						children:set({ render() })
					end

					isRendered:set(true)
				elseif not inWindow and isRendered:get(false) then
					isRendered:set(false)
				end
			end
		end

		onDestroy(frame, {
			scrollingFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
				scrollingFrameWindowSize:set(scrollingFrame.AbsoluteWindowSize)
				updateChildren()
			end),
			scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				local canvasPosition = scrollingFrame.CanvasPosition

				if lastUpdatePosition and (canvasPosition - lastUpdatePosition).Magnitude < MIN_RERENDER_DISTANCE then
					return
				end

				lastUpdatePosition = canvasPosition
				scrollingFramePosition:set(canvasPosition)
				updateChildren()
			end),
			scrollingFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				scrollingFrameAbsolutePosition:set(scrollingFrame.AbsolutePosition)
				updateChildren()
			end),
			scrollingFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
				task.delay(0.25, updateChildren)
			end),
			function()
				POOLED_INSTANCES[scrollingFrame] = nil
			end,
		})
	end

	return frame
end

local function standaloneScrollerEntry(props: standaloneScrollerEntryProps)
	local scrollingFrame = Value()
	local scrollerEntryChildren = Value()
	local isRendered = Value(false)
	local scrollerEntry = New("Frame")({
		Name = "ScrollerEntry",
		BackgroundTransparency = 1,
		Size = UDim2.new(),
		Visible = Computed(function()
			return (props.Visible == nil or use(props.Visible)) and (props.Enabled == nil or use(props.Enabled))
		end),
		[Children] = Computed(function()
			if isRendered:get() and (props.Enabled == nil or use(props.Enabled)) then
				return scrollerEntryChildren:get()
			end

			return nil
		end, DoNothing),
	})

	if props.FrameProperties then
		scrollerEntry = Hydrate(scrollerEntry)(props.FrameProperties)
	end

	local selfSize = Value(Vector2.new())
	local selfPosition = Value(Vector2.new())

	local function updateChild()
		if props.Enabled ~= nil and not use(props.Enabled) or not scrollingFrame:get(false) then
			return
		end

		local windowSize = scrollingFrame:get(false).AbsoluteWindowSize
		local scrollPosition = scrollingFrame:get(false).AbsolutePosition

		-- we determine where in the canvas we are ourselves first -- we find this by subtracing the scrollingframe's position from our own position
		local selfPositionTopBound = selfPosition:get(false)
		local selfPositionBottomBound = selfPosition:get(false) + selfSize:get(false)
		local topBound = selfPositionTopBound - scrollPosition
		local bottomBound = selfPositionBottomBound - scrollPosition
		-- see if we are in the window (so if relativeposition is between 0,0 and windowSize)
		local inWindow = (topBound.X >= 0 and topBound.Y >= 0 or bottomBound.X >= 0 and bottomBound.Y >= 0)
			and (
				topBound.X <= windowSize.X and topBound.Y <= windowSize.Y
				or bottomBound.X <= windowSize.X and bottomBound.Y <= windowSize.Y
			)

		if inWindow and not isRendered:get(false) then
			if scrollerEntryChildren:get(false) == nil then
				scrollerEntryChildren:set({ props.Render() })
			end

			isRendered:set(true)
		elseif not inWindow and isRendered:get(false) then
			isRendered:set(false)
		end
	end

	local function updateParent()
		local foundFrame = scrollerEntry:FindFirstAncestorWhichIsA("ScrollingFrame")
		scrollingFrame:set(foundFrame)

		if foundFrame and POOLED_INSTANCES[foundFrame] then
			table.insert(POOLED_INSTANCES[foundFrame], {
				instance = scrollerEntry,
				size = selfSize,
				position = selfPosition,
				isRendered = isRendered,
				enabled = props.Enabled,
				children = scrollerEntryChildren,
				render = props.Render,
			})

			updateChild()
		end
	end

	onDestroy(scrollerEntry, {
		scrollerEntry:GetPropertyChangedSignal("Parent"):Connect(updateParent),
		scrollerEntry:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			selfSize:set(scrollerEntry.AbsoluteSize)
			updateChild()
		end),
		scrollerEntry:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			selfPosition:set(scrollerEntry.AbsolutePosition)
		end),
		props.Enabled and Observer(props.Enabled):onChange(function()
			-- position is not updated immediately; we need to wait for the next frame
			task.delay(0, updateChild)
		end),
		function()
			if POOLED_INSTANCES[scrollingFrame:get(false)] then
				local pooledInstances = POOLED_INSTANCES[scrollingFrame:get(false)]

				-- remove self from pooled instances
				for i, instance in ipairs(pooledInstances) do
					if instance.isRendered == isRendered then
						pooledInstances[i] = nil
						break
					end
				end
			end
		end,
	})

	task.delay(0.1, updateParent)

	return scrollerEntry
end

return {
	frame = standaloneScrollingFrame,
	entry = standaloneScrollerEntry,
}
