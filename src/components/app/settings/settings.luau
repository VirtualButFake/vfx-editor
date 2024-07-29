local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local checkbox = fusionComponents.common.checkbox
local input = fusionComponents.common.input
local selectMenu = fusionComponents.common.selectMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type settings = {
	{
		name: string,
		fields: {
			[number]: {
				title: string,
				pluginSettingKey: string,
				description: string?,
				default: any,
				render: (value: fusion.Value<any>) -> any,
			},
		},
	}
}

local function checkboxField(value: fusion.Value<any>)
	return checkbox({
		Color = "blue",
		AppearanceOverride = {
			_global = {
				Background = { shadow = 2 },
			},
		},
		State = value,
		Padding = 4,
		Icon = {
			Name = "check",
			Size = 16,
		},
		Size = UDim2.new(0, 24, 0, 24),
	})
end

local function numericInputField(value: fusion.Value<any>)
	local inputDisplay = Value(tostring(value:get() or ""))

	return input({
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
			inputDisplay:set(text)
		end,
		Size = UDim2.new(0.75, 0, 0, 20),
		[Cleanup] = {
			Observer(inputDisplay):onChange(function()
				if inputDisplay:get() == tostring(value:get()) then
					return
				end

				-- check if value is a number
				if tonumber(inputDisplay:get()) then
					value:set(tonumber(inputDisplay:get()))
					return
				end

				inputDisplay:set(tostring(value:get()), true)
			end),
			Observer(value):onChange(function()
				inputDisplay:set(tostring(value:get()))
			end),
		},
	})
end

local function selectMenuField(options: {
	{
		Id: string,
		Label: string?,
		Icon: fusion.CanBeState<string>,
	}
})
	return function(value: fusion.Value<any>)
		local selectedOptions = Value({ value:get() })

		return selectMenu({
			Color = "gray",
			Variant = "default",
			MaxHeight = 4,
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
			Options = options,
			SelectedOptions = selectedOptions,
			OnOptionClicked = function(id, isVisible)
				selectedOptions:set({ id })
				isVisible:set(false)
			end,
			Size = UDim2.new(0.75, 0, 0, 20),
			[Cleanup] = {
				Observer(selectedOptions):onChange(function()
					value:set(selectedOptions:get()[1])
				end),
				Observer(value):onChange(function()
					selectedOptions:set({ value:get() })
				end),
			},
		})
	end
end

local function stringsToOptions(strings: { string })
	local options = {}

	for _, str in ipairs(strings) do
		table.insert(options, {
			Id = str:lower(),
			Label = str,
		})
	end

	return options
end

local settings: settings = {
	{
		name = "General",
		fields = {
			{
				title = "Lightweight Mode",
				description = "Turns the plugin into a practically seamless copy of the original properties window, for a decreased learning curve and seamless drop-in replacement.",
				default = false,
				pluginSettingKey = "lightweight_mode",
				render = checkboxField,
			},
			{
				title = "Max Instance Depth",
				pluginSettingKey = "max_depth",
				default = 3,
				render = numericInputField,
			},
			{
				title = "Max Size",
				description = 'Determines the upper limit for "Size" properties',
				pluginSettingKey = "max_size",
				default = 10,
				render = numericInputField,
			},
			{
				title = "Max Squash",
				description = 'Determines the upper limit for "Squash" properties',
				pluginSettingKey = "max_squash",
				default = 3,
				render = numericInputField,
			},
			{
				title = "Treeview Virtual Scroller",
				pluginSettingKey = "treeview_virtual_scroller",
				description = "Improves average performance by only rendering visible items",
				default = true,
				render = checkboxField,
			},
			{
				title = "Graph Editor Default Style",
				pluginSettingKey = "graph_editor_default_style",
				default = "linear",
				render = selectMenuField(
					stringsToOptions({ "Back", "Bezier", "Cubic", "Expo", "Linear", "Quad", "Sine" })
				),
			},
		},
	},
}

return settings
