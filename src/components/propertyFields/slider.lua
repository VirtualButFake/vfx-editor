local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local slider = studioComponents.common.slider
local input = studioComponents.common.input

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<number>,
	LayoutOrder: number,
	Min: number,
	Max: number,
	Step: number,
}

local function sliderPropertyField(props: props)
	local textValue = Value(tostring(props.Value:get()))
	local sliderValue = Value(props.Value:get())

	local connections = {
		Observer(sliderValue):onChange(function()
			-- propagate value to text
			textValue:set(tostring(sliderValue:get()))
		end),
		Observer(props.Value):onChange(function()
			if props.Value:get() ~= sliderValue:get() then
				sliderValue:set(props.Value:get())
			end
		end),
	}

	return New("Frame")({
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 24),
		[Cleanup] = connections,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			slider({
				Color = "blue",
				Width = UDim.new(1, -32),
				Min = props.Min,
				Max = props.Max,
				Tooltip = true,
				Value = sliderValue,
				LayoutOrder = props.LayoutOrder,
				Step = props.Step,
				BarHeight = UDim.new(0, 6),
				HandleSize = UDim2.new(0, 12, 0, 12),
				OnValueChanged = function(value)
					sliderValue:set(value)
				end,
				OnDrag = function(isDragging, value)
					if not isDragging then
						props.Value:set(value)
					end
				end,
			}),
			input({
				Variant = "default",
				Color = "gray",
				AppearanceOverride = {
					_global = {
						Background = {
							color = theme.global.isDark:get() and tailwind.neutral[850] or tailwind.white,
							shadow = 1,
						},
					},
					Focus = {
						Stroke = theme.global.isDark:get() and tailwind.blue[400] or tailwind.blue[500],
					},
				},
				Size = UDim2.new(0, 28, 0, 20),
				Text = textValue,
				OnFocusLost = function(text)
					-- filter value, then propagate to slider
					local value = tonumber(text)

					if not value then
						textValue:set(tostring(sliderValue:get()))
						return
					end

					if value < props.Min then
						value = props.Min
					elseif value > props.Max then
						value = props.Max
					end

					sliderValue:set(value)
				end,
			}),
		},
	})
end

return sliderPropertyField
