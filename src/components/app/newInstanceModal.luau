local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local text = fusionComponents.base.text
local button = fusionComponents.common.button
local selectMenu = fusionComponents.common.selectMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")

local inputPropertyField = require("@components/propertyFields/input")
local modalOptionWrapper = require("@components/modalOptionWrapper")

type props = {
	useColor: theme.useColorFunction,
	OnClose: () -> (),
	OnCreate: (name: string, class: string) -> (),
}

local function newInstanceModal(props: props)
	local selectedOptions = Value({ "ParticleEmitter" })
	local inputValue = Value("")

	local debounce = false

	return New("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 0, 0),
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
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				[Children] = {
					text({
						Appearance = props.useColor("Text", true),
						Text = {
							Label = "New Instance",
							Font = Font.new(theme.global.font.Family, Enum.FontWeight.SemiBold),
							TextSize = 18,
						},
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
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
				Content = inputPropertyField({
					Value = inputValue,
					LayoutOrder = 1,
				}),
			}),
			modalOptionWrapper({
				OptionName = "Class",
				Content = selectMenu({
					Color = "gray",
					Variant = "default",
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
					Size = UDim2.new(0.75, 0, 0, 20),
					SelectedOptions = selectedOptions,
					Options = ForPairs({
						"ParticleEmitter",
						"Beam",
						"Trail",
						"Attachment",
					}, function(index, value)
						return index,
							{
								Id = value,
								Slots = {
									Left = function()
										local classIcon = theme.getClassIcon(value)

										return New("ImageLabel")({
											Name = "ClassIcon",
											BackgroundTransparency = 1,
											Image = Computed(function()
												return classIcon:get().Image
											end),
											ImageRectOffset = Computed(function()
												return classIcon:get().ImageRectOffset
											end),
											ImageRectSize = Computed(function()
												return classIcon:get().ImageRectSize
											end),
											Size = UDim2.new(0, 16, 0, 16),
										})
									end,
								},
							}
					end),
					OnOptionClicked = function(id, visible)
						selectedOptions:set({ id })
						visible:set(false)
					end,
					Slots = {
						LeftInput = function()
							return Computed(function()
								local selectedOptionValue = selectedOptions:get()

								if #selectedOptionValue ~= 0 then
									-- not isolating this in computeds because an update here is not really relevant - it'll update on option change anyways, so this tiny optimization is irrelevant
									local classIcon = theme.getClassIcon(selectedOptionValue[1]):get()

									return New("ImageLabel")({
										Name = "ClassIcon",
										BackgroundTransparency = 1,
										Image = classIcon.Image,
										ImageRectOffset = classIcon.ImageRectOffset,
										ImageRectSize = classIcon.ImageRectSize,
										Size = UDim2.new(0, 16, 0, 16),
									})
								end

								return nil
							end, Clean)
						end,
					},
				}),
			}),
			button({
				Color = "gray",
				Variant = "solid",
				ButtonText = "Create Instance",
				AutomaticSize = Enum.AutomaticSize.XY,
				Disabled = Computed(function()
					local usedInput = inputValue:get()
					local usedOptions = selectedOptions:get()

					if #usedOptions == 0 or not usedInput:match("^[%w%s-()]+$") or usedInput:match("^%s*$") then
						return true
					end

					return false
				end),
				OnClick = function()
					if debounce then
						return
					end

					local usedInput = inputValue:get()
					local usedOptions = selectedOptions:get()

					if #usedOptions == 0 then
						return
					end

					props.OnCreate(usedInput, usedOptions[1])

					selectedOptions:set({})
					inputValue:set("")

					debounce = true

					task.delay(0.25, function()
						debounce = false
					end)
				end,
			}),
		},
	})
end

return newInstanceModal
