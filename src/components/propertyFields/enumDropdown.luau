local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local selectMenu = fusionComponents.common.selectMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type props = {
	Value: fusion.Value<EnumItem>,
	LayoutOrder: number,
	Disabled: fusion.CanBeState<boolean>?,
}

local function enumDropdownPropertyField(props: props)
	local parentEnum = props.Value:get(false).EnumType
	local selectedOptions = Value({ props.Value:get(false).Name })

	local disconnectObserver = Observer(selectedOptions):onChange(function()
		props.Value:set(parentEnum[selectedOptions:get()[1]])
	end)

	local onPropertyChange = Observer(props.Value):onChange(function()
		selectedOptions:set({ props.Value:get().Name })
	end)

	return selectMenu({
		Color = "gray",
		Variant = "default",
		MaxHeight = 3,
		Disabled = props.Disabled,
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
		Options = Computed(function()
			local options = {}
			for _, enumItem in props.Value:get().EnumType:GetEnumItems() do
				table.insert(options, {
					Id = enumItem.Name,
				})
			end

			return options
		end),
		SelectedOptions = selectedOptions,
		OnOptionClicked = function(id, isVisible)
			selectedOptions:set({ id })
			isVisible:set(false)
		end,
		Size = UDim2.new(1, 0, 0, 20),
		[Cleanup] = function()
			disconnectObserver()
			onPropertyChange()
		end,
	})
end

return enumDropdownPropertyField
