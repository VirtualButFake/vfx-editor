local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local slider = fusionComponents.common.slider
local input = fusionComponents.common.input

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

local function roundDecimals(value: number, decimals: number): number
	local multiplier = 10 ^ decimals
	return math.floor(value * multiplier + 0.5) / multiplier
end

type props = {
	Value: fusion.Value<number>,
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

	local textValue = Value(tostring(roundToStep(props.Value:get(false))))
	local sliderValue = Value(props.Value:get(false))

	local connections = {
		Observer(sliderValue):onChange(function()
			-- propagate value to text
			textValue:set(tostring(roundToStep(sliderValue:get())))
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
		Size = UDim2.new(1, 0, 0, 20),
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
				AppearanceOverride = {
					Background = Computed(function()
						return {
							color = theme.global.isDark:get() and tailwind.neutral[815] or tailwind.white,
							shadow = 1,
						}
					end),
				},
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
				Size = UDim2.new(0, 28, 0, 20),
				Text = textValue,
				OnFocusLost = function(text)
					-- filter value, then propagate to slider
					local value = tonumber(text)

					if not value then
						textValue:set(tostring(roundToStep(sliderValue:get())), true)
						return
					end

					sliderValue:set(value)
					props.Value:set(value)
				end,
			}),
		},
	})
end

return sliderPropertyField
