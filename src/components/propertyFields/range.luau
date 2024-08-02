local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local range = fusionComponents.common.range
local input = fusionComponents.common.input

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

local function roundDecimals(value: number, decimals: number): number
	local multiplier = 10 ^ decimals
	return math.floor(value * multiplier + 0.5) / multiplier
end

type props = {
	Value: fusion.Value<NumberRange>,
	LayoutOrder: number,
	Min: number,
	Max: number,
	Step: number,
}

local function rangePropertyField(props: props)
	local function roundToStep(value: number): number
		local closestStep = math.round((value - props.Min) / props.Step) * props.Step + props.Min

		if closestStep <= props.Max and closestStep >= props.Min then
			return roundDecimals(closestStep, 3)
		else
			local roundingFunction = closestStep < props.Min and math.ceil or math.floor
			return roundDecimals(roundingFunction((value - props.Min) / props.Step) * props.Step + props.Min, 3)
		end
	end

	local textValue = Value(`{roundToStep(props.Value:get(false).Min)}, {roundToStep(props.Value:get(false).Max)}`)
	local sliderValue = Value(props.Value:get(false))

	local connections = {
		Observer(sliderValue):onChange(function()
			-- propagate value to text
			textValue:set(`{roundToStep(sliderValue:get().Min)}, {roundToStep(sliderValue:get().Max)}`)
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
			range({
				Color = "blue",
				Width = UDim.new(1, -48),
				Min = props.Min,
				Max = props.Max,
				Tooltip = true,
				Value = Computed(function()
					local value = sliderValue:get()
					return { value.Min, value.Max }
				end),
				LayoutOrder = props.LayoutOrder,
				Step = props.Step,
				BarHeight = UDim.new(0, 6),
				HandleSize = UDim2.new(0, 12, 0, 12),
				OnValueChanged = function(index, value)
					local currentValue = sliderValue:get()
					sliderValue:set(
						index == 1 and NumberRange.new(value, currentValue.Max)
							or NumberRange.new(currentValue.Min, value)
					)
				end,
				OnDrag = function(isDragging, values)
					if not isDragging then
						props.Value:set(NumberRange.new(values[1], values[2]))
					end
				end,
			}),
			input({
				Variant = "default",
				Color = "gray",
				AppearanceOverride = {
					_global = {
						Background = {
							color = Computed(function()
								return theme.global.isDark:get() and tailwind.neutral[850] or tailwind.white
							end),
							shadow = 1,
						},
					},
					Focus = {
						Stroke = Computed(function()
							return theme.global.isDark:get() and tailwind.blue[400] or tailwind.blue[500]
						end),
					},
				},
				Size = UDim2.new(0, 48, 0, 20),
				Text = textValue,
				OnFocusLost = function(text)
					local values = text:split(",")

					for _, value in values do
						if not tonumber(value) then
							local currentSliderValue = sliderValue:get()
							textValue:set(
								`{roundToStep(currentSliderValue.Min)}, {roundToStep(currentSliderValue.Max)}`
							)
							return
						end
					end

					local newValue = NumberRange.new(tonumber(values[1]) :: number, tonumber(values[2]) :: number)

					sliderValue:set(newValue)
					props.Value:set(newValue)
				end,
			}),
		},
	})
end

return rangePropertyField
