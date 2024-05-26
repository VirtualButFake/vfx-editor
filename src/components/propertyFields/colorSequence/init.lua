local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

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

local function colorSequencePropertyField(props: props, _, useColor: theme.useColorFunction)
	local isWidgetEnabled = Value(false)

    -- no idea if this causes a memory leak, maybe it gets gc'ed? but doubtful
	widget({
		Name = "Color Sequence Editor",
		Id = HttpService:GenerateGUID(),
		InitialDockTo = Enum.InitialDockState.Float,
		InitialEnabled = false,
		FloatingSize = Vector2.new(500, 200),
		MinimumSize = Vector2.new(500, 200),
		Enabled = isWidgetEnabled,
		ForceInitialEnabled = true,
        [Children] = {
            editor({
                Value = props.Value,
            }),
        }
	})

	local colorButton = button({
		Appearance = { color = Color3.new(1, 1, 1), transparency = 1 },
		Stroke = useColor("Line", true),
		Size = UDim2.new(0, 20, 0, 20),
		LayoutOrder = props.LayoutOrder,
		OnClick = function()
			isWidgetEnabled:set(not isWidgetEnabled:get())
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
