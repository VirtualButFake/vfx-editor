local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local selectMenu = fusionComponents.common.selectMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

local function tableEquals(a: { any }, b: { any })
	if #a ~= #b then
		return false
	end

	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

type props = {
	Value: fusion.Value<string | { string }>,
	LayoutOrder: number,
	Disabled: fusion.CanBeState<boolean>?,
	Multiple: boolean?,
	Options: {
		{
			Id: string,
			Label: string?,
			Icon: string?,
		}
	},
}

local function dropdownPropertyField(props: props)
	local selectedOptions = props.Multiple and Value(table.clone(props.Value:get(false)))
		or Value({ props.Value:get(false) })

	local disconnectObserver = Observer(selectedOptions):onChange(function()
		local usedSelectedOptions = selectedOptions:get()

		if props.Multiple then
			if typeof(props.Value:get()) == "table" and tableEquals(usedSelectedOptions, props.Value:get() :: any) then
				return
			end

			props.Value:set(table.clone(usedSelectedOptions))
		else
			props.Value:set(usedSelectedOptions[1])
		end
	end)

	local onPropertyChange = Observer(props.Value):onChange(function()
		if props.Multiple then
			if
				typeof(props.Value:get()) == "table" and tableEquals(selectedOptions:get(), props.Value:get() :: any)
			then
				return
			end

			selectedOptions:set(table.clone(props.Value:get()))
		else
			selectedOptions:set({ props.Value:get() })
		end
	end)

	return selectMenu({
		Color = "gray",
		Variant = "default",
		MaxHeight = 3,
		Disabled = props.Disabled,
		Multiple = props.Multiple,
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
		Options = props.Options,
		SelectedOptions = selectedOptions,
		OnOptionClicked = function(id, isVisible)
			if props.Multiple then
				local index = table.find(selectedOptions:get(), id)

				if index then
					table.remove(selectedOptions:get(), index)
				else
					table.insert(selectedOptions:get(), id)
				end
			else
				selectedOptions:set({ id })
				isVisible:set(false)
			end
		end,
		Size = UDim2.new(1, 0, 0, 20),
		[Cleanup] = function()
			disconnectObserver()
			onPropertyChange()
		end,
	})
end

return dropdownPropertyField
