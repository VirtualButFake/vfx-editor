local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text
local button = studioComponents.common.button

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local theme = require("@src/theme")

local inputPropertyField = require("@components/propertyFields/input")
local modalOptionWrapper = require("./modalOptionWrapper")

type folder = {}

type props = {
	useColor: theme.useColorFunction,
	OnCreate: (name: string) -> (),
	OnClose: () -> (),
}

local function createFolderModal(props: props)
	local hasCreated = false

	local inputValue = Value("")
	local isConfirmDisabled = Computed(function()
		return not inputValue:get():match("^[%w%s-()]+$") or inputValue:get():match("^%s*$")
	end)

	return New("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 0, 0),
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("Frame")({
				Name = "TopItems",
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				[Children] = {
					text({
						Appearance = props.useColor("Title", true),
						Text = {
							Label = "Create Folder",
							Font = Font.new(use(theme.global.font).Family, Enum.FontWeight.SemiBold),
							TextSize = 18,
						},
						AutomaticSize = Enum.AutomaticSize.XY,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
					button({
						Color = "gray",
						Variant = "ghost",
						Icon = "x",
						AutomaticSize = Enum.AutomaticSize.XY,
						Position = UDim2.new(1, -24, 0, 0),
						OnClick = props.OnClose,
					}),
				},
			}),
			modalOptionWrapper({
				OptionName = "Name",
				Content = {
					inputPropertyField({
						Value = inputValue,
						LayoutOrder = 1,
					}),
				},
			}),
			button({
				Color = "gray",
				Variant = "solid",
				ButtonText = "Create folder",
				AutomaticSize = Enum.AutomaticSize.XY,
				Disabled = isConfirmDisabled,
				OnClick = function()
					if hasCreated then
						return
					end

					props.OnCreate(inputValue:get())
					hasCreated = true
				end,
			}),
		},
	})
end

return createFolderModal
