local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local Hydrate = fusion.Hydrate
local New = fusion.New
local Out = fusion.Out

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

local studioComponents = require("@packages/studioComponents")
local frame = studioComponents.base.frame

local theme = require("@src/theme")

type props = {
	Content: fusion.CanBeState<{ GuiObject }>,
	ScrollingFrameProps: {
		[string]: any,
	}?,
}

local function scrollingFrame(props: props)
	local useColor = theme:get("ScrollingFrame", "gray", "default", "Base")

	local scrollingFrameCanvasSize = Value(Vector2.new(0, 0))
	local scrollingFrameAbsoluteSize = Value(Vector2.new(0, 0))

	local scroller = New("ScrollingFrame")({
		BackgroundTransparency = 1,
		BottomImage = "rbxassetid://17569049896",
		CanvasSize = UDim2.fromScale(0, 0),
		MidImage = "rbxassetid://17568857612",
		ScrollBarImageColor3 = Computed(function()
			return useColor("ScrollBar").color
		end),
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 1, 0),
		TopImage = "rbxassetid://17569049728",
		[Children] = props.Content,
		[Out("AbsoluteCanvasSize")] = scrollingFrameCanvasSize,
		[Out("AbsoluteSize")] = scrollingFrameAbsoluteSize,
	})

	local component = New("Frame")({
		Name = "ScrollingFrameContainer",
		BackgroundTransparency = 1,
		[Cleanup] = { props.Content, scroller },
		[Children] = {
			Computed(function()
				if not scrollingFrameCanvasSize:get() or not scrollingFrameAbsoluteSize:get() then
					return false
				end

				local objects = {}

				local isXScrollable = scrollingFrameCanvasSize:get().X > scrollingFrameAbsoluteSize:get().X
				local isYScrollable = scrollingFrameCanvasSize:get().Y > scrollingFrameAbsoluteSize:get().Y

				if isYScrollable then
					table.insert(
						objects,
						frame({
							Name = "ScrollbarBackground",
							Appearance = useColor("ScrollBarBackground", true),
							Stroke = useColor("Stroke", true),
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, 0),
							Size = UDim2.new(0, 6, 1, isXScrollable and -6 or 0),
							ZIndex = 0,
						})
					)
				end

				if isXScrollable then
					table.insert(
						objects,
						frame({
							Name = "ScrollbarBackground",
							Appearance = useColor("ScrollBarBackground", true),
							Stroke = useColor("Stroke", true),
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, 0, 1, 0),
							Size = UDim2.new(1, isYScrollable and -6 or 0, 0, 6),
							ZIndex = 0,
						})
					)
				end

				return objects
			end, Clean),
			Hydrate(scroller)(props.ScrollingFrameProps or {}),
		},
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "ScrollingFrame"))
end

return scrollingFrame
