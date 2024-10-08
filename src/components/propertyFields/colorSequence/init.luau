local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.base.button

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

	local createdWidget

	local colorButton = button({
		Appearance = { color = Color3.new(1, 1, 1), transparency = 1, shadow = 2 },
		Stroke = useColor("Line", true),
		Size = UDim2.new(0, 20, 0, 20),
		LayoutOrder = props.LayoutOrder,
		OnClick = function()
			if createdWidget == nil then
				createdWidget = widget({
					Name = `Color Sequence Editor ({props.Instance}.{props.PropertyName})`,
					Id = HttpService:GenerateGUID(),
					InitialDockTo = Enum.InitialDockState.Float,
					InitialEnabled = false,
					ForceInitialEnabled = true,
					FloatingSize = Vector2.new(500, 200),
					MinimumSize = Vector2.new(500, 200),
					Enabled = isWidgetEnabled,
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
			end

			isWidgetEnabled:set(true)
		end,
		[Cleanup] = {
			function()
				-- https://devforum.roblox.com/t/2853087 causes issues while using flipbook here
				isWidgetEnabled:set(false)

				if createdWidget then
					createdWidget:Destroy()
				end
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
