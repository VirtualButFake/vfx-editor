local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.base.button

local widget = require("@components/widget")
local editor = require("./editor")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<ColorSequence>,
	LayoutOrder: number,
}

local function colorSequencePropertyField(props: props, useColor: theme.useColorFunction)
	local isWidgetEnabled = Value(false)
	local wasEnabled = false

	widget({
		Name = "Color Sequence Editor",
		Id = HttpService:GenerateGUID(),
		InitialDockTo = Enum.InitialDockState.Float,
		InitialEnabled = false,
		ForceInitialEnabled = true,
		MinimumSize = Vector2.new(500, 200),
		Enabled = isWidgetEnabled,
		FloatingSize = Vector2.new(500, 200),
		[Children] = {
			Computed(function()
				local widgetEnabled = isWidgetEnabled:get()

				if widgetEnabled and not wasEnabled then
					wasEnabled = true

					return editor({
						Value = props.Value,
						useColor = useColor,
					})
				end

				if not widgetEnabled then
					wasEnabled = false
				end

				return nil
			end, Clean),
		},
	})

	local colorButton = button({
		Appearance = { color = Color3.new(1, 1, 1), transparency = 1, shadow = 2 },
		Stroke = useColor("Line", true),
		Size = UDim2.new(0, 20, 0, 20),
		LayoutOrder = props.LayoutOrder,
		OnClick = function()
			isWidgetEnabled:set(true)
		end,
		[Cleanup] = {
			function()
				-- not destroying it, see https://devforum.roblox.com/t/2853087
				isWidgetEnabled:set(false)
			end,
		},
		[Children] = {
			New("Frame")({
				Name = "Color",
				Size = UDim2.new(1, 0, 1, 0),
				[Children] = {
					New("UIGradient")({
						Color = props.Value,
					}),
					New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),
				},
			}),
		},
	})

	return colorButton
end

return colorSequencePropertyField
