local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local range = studioComponents.common.range
local input = studioComponents.common.input

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

local function sliderPropertyField(props: props)
    local function roundToStep(value: number): number
        local closestStep = math.round((value - props.Min) / props.Step) * props.Step + props.Min
    
        if closestStep <= props.Max and closestStep >= props.Min then
            return roundDecimals(closestStep, 3)
        else
            local roundingFunction = closestStep < props.Min and math.ceil or math.floor
            return roundDecimals(roundingFunction((value - props.Min) / props.Step) * props.Step + props.Min, 3)
        end
    end

	local textValue = Value(
		`{roundToStep(props.Value:get().Min)}, {roundToStep(props.Value:get().Max)}`
	)
	local sliderValue = Value(props.Value:get())

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
						props.Value:set(NumberRange.new(values[1]:get(false), values[2]:get(false)))
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
				Size = UDim2.new(0, 48, 0, 20),
				Text = textValue,
				OnFocusLost = function(text)
					local values = text:split(",")

					for _, value in ipairs(values) do
						if not tonumber(value) then
							local currentSliderValue = sliderValue:get()
							textValue:set(`{roundToStep(currentSliderValue.Min)}, {roundToStep(currentSliderValue.Max)}`)
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

return sliderPropertyField
