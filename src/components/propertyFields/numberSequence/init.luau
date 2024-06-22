local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button

local widget = require("@components/widget")
local editor = require("./editor")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<NumberSequence>,
	LayoutOrder: number,
}

local function numberSequencePropertyField(props: props, useColor: theme.useColorFunction)
	local isWidgetEnabled = Value(false)
	local wasEnabled = false

	local createdWidget = widget({
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
					})
				end

				if not widgetEnabled then
					wasEnabled = false
				end

				return nil
			end, Clean),
		},
	})

	local graphButton = button({
		Color = "white",
		Variant = "solid",
		Icon = {
			Name = "line-chart",
			Size = 16,
		},
		Margin = 2,
		Size = UDim2.new(0, 16, 0, 16),
		LayoutOrder = props.LayoutOrder,
		OnClick = function()
			isWidgetEnabled:set(true)
		end,
		[Cleanup] = {
			function()
				-- https://devforum.roblox.com/t/2853087
				isWidgetEnabled:set(false)
				createdWidget:Destroy()
			end,
		},
	})

	return graphButton
end

return numberSequencePropertyField
