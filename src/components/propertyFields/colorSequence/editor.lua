local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local widget = require("@components/widget")

type props = {
	Value: fusion.Value<ColorSequence>,
}

local function editor(props: props)
	local isWidgetEnabled = Value(false)

	widget({
		Name = "Color Picker",
		Id = HttpService:GenerateGUID(),
		InitialDockTo = Enum.InitialDockState.Float,
		InitialEnabled = false,
		ForceInitialEnabled = true,
		FloatingSize = Vector2.new(400, 300),
		Enabled = isWidgetEnabled,
		MinimumSize = Vector2.new(300, 200),
	})

	return New("Frame")({
		Name = "ColorSequenceEditor",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Children] = {
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
			}),
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
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
			New("Frame")({
				Name = "ColorTimeline",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				[Children] = {
                    Computed(function()
                        
                    end)
                },
			}),
		},
	})
end

return editor
