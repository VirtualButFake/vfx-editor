local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local selectMenu = studioComponents.common.selectMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<EnumItem>,
	LayoutOrder: number,
}

local function dropdownPropertyField(props: props)
	local parentEnum = props.Value:get().EnumType
	local selectedOptions = Value({ props.Value:get().Name })

	local disconnectObserver = Observer(selectedOptions):onChange(function()
		props.Value:set(parentEnum[selectedOptions:get()[1]])
	end)

	return selectMenu({
		Color = "gray",
		Variant = "default",
		MaxHeight = 3,
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
		Size = UDim2.new(1, 0, 0, 20),
		[Cleanup] = function()
			disconnectObserver()
		end,
	})
end

return dropdownPropertyField
