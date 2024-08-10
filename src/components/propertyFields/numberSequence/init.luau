local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.common.button
local input = fusionComponents.common.input

local tailwind = require("@packages/tailwind")

local widget = require("@components/widget")
local editor = require("./editor")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<NumberSequence>,
	LayoutOrder: number,
	SupportsEnvelope: boolean,
	Min: number,
	Max: number,
}

local function numberSequencePropertyField(props: props, useColor: theme.useColorFunction)
	local maxValueInSequence = props.Max

	for _, keypoint in props.Value:get(false).Keypoints do
		if keypoint.Value > maxValueInSequence then
			maxValueInSequence = keypoint.Value
		end
	end

	props.Max = math.max(maxValueInSequence, props.Max)

	local isWidgetEnabled = Value(false)
	local wasEnabled = false

	local createdWidget

	local function getInputText()
		-- if the value is a number sequence that only has 2 keypoints, we can represent it as a number
		local value = props.Value:get(false)
		local keypoints = value.Keypoints

		if #keypoints == 2 then
			local keypoint1 = keypoints[1]
			local keypoint2 = keypoints[2]

			if keypoint1.Time == 0 and keypoint2.Time == 1 and keypoint1.Value == keypoint2.Value then
				return tostring(keypoint1.Value)
			end
		end

		return "<sequence>"
	end

	local inputDisplay = Value(getInputText())

	local onPropertyChange = Observer(props.Value):onChange(function()
		inputDisplay:set(getInputText())
	end)

	local buttons = New("Frame")({
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(1, 0, 0, 16),
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				Padding = UDim.new(0, 4),
			}),
			button({
				Color = "white",
				Variant = "solid",
				Icon = {
					Name = "line-chart",
					Size = 16,
				},
				Padding = 2,
				Size = UDim2.new(0, 16, 0, 16),
				LayoutOrder = props.LayoutOrder,
				OnClick = function()
					if createdWidget == nil then
						createdWidget = widget({
							Name = `Number Sequence Editor ({props.Instance}.{props.PropertyName})`,
							Id = HttpService:GenerateGUID(),
							InitialDockTo = Enum.InitialDockState.Float,
							InitialEnabled = false,
							ForceInitialEnabled = true,
							FloatingSize = Vector2.new(500, 250),
							MinimumSize = Vector2.new(500, 250),
							Enabled = isWidgetEnabled,
							[Children] = {
								Computed(function()
									local widgetEnabled = isWidgetEnabled:get()

									if widgetEnabled and not wasEnabled then
										wasEnabled = true

										return editor({
											Value = props.Value,
											useColor = useColor,
											Instance = props.Instance,
											PropertyName = props.PropertyName,
											SupportsEnvelope = props.SupportsEnvelope,
											Min = props.Min,
											Max = props.Max,
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
						-- https://devforum.roblox.com/t/2853087
						isWidgetEnabled:set(false)

						if createdWidget then
							createdWidget:Destroy()
						end
					end,
				},
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
				Text = inputDisplay,
				OnFocusLost = function(text)
					-- value has to be a number, so we can convert it to a number sequence
					local value = tonumber(text)

					if value then
						props.Value:set(NumberSequence.new(value))
					end

					inputDisplay:set(getInputText())
				end,
				Size = UDim2.new(1, -24, 0, 20),
				LayoutOrder = props.LayoutOrder,
				[Cleanup] = { onPropertyChange },
			}),
		},
	})

	return buttons
end

return numberSequencePropertyField
