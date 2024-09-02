local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local text = fusionComponents.base.text
local button = fusionComponents.common.button
local tooltip = fusionComponents.common.tooltip

local theme = require("@src/theme")

local inputPropertyField = require("@components/propertyFields/input")
local dropdownPropertyField = require("@components/propertyFields/enumDropdown")
local modalOptionWrapper = require("@components/modalOptionWrapper")
local textureImage = require("../textureImage")

local getImageResolution = require("../getImageResolution")

type folder = {}

type props = {
	useColor: theme.useColorFunction,
	OnCreate: (name: string, id: string?, flipbookLayout: string?) -> (),
	OnClose: () -> (),
	IsFolder: boolean?,
	VerbUsed: string,
	OverwriteDefaults: {
		Name: string?,
		ID: string?,
		FlipbookLayout: Enum.ParticleFlipbookLayout?,
	}?,
}

local inputs = {
	{
		Name = "Name",
		Render = inputPropertyField,
		Placeholder = "Name",
		Default = "",
		Validate = function(value)
			-- the value must be alphanumeric, spaces, or hyphens and cannot be empty
			local usedValue = value:get(false)
			return usedValue:match("^[%w%s-()]+$") ~= nil and not usedValue:match("^%s*$")
		end,
	},
	{
		Name = "ID",
		Render = inputPropertyField,
		Placeholder = "Texture ID",
		Default = "",
		NeedsTexture = true,
		Validate = function(value)
			local usedValue = value:get(false)

			if usedValue:match("^rbxassetid://[0-9]+$") == nil then
				value:set("rbxassetid://" .. (usedValue:match("%d+") or "0"))
			end

			return true
		end,
	},
	{
		Name = "Flipbook Layout",
		NeedsTexture = true,
		Render = function(props)
			return tooltip(
				dropdownPropertyField({
					Value = props.Value,
					LayoutOrder = props.LayoutOrder,
					Disabled = props.Disabled,
				}),
				{
					Enabled = props.Disabled,
					FollowMouse = true,
					Variant = "default",
					Slots = {
						Content = function(useColor)
							return {
								New("UISizeConstraint")({
									MaxSize = Vector2.new(200, math.huge),
								}),
								text({
									Name = "TooltipText",
									Appearance = useColor("Text", true),
									Text = "This image resolution does not support flipbooks. Only 8x8, 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, and 1024x1024 are supported.",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									RichText = true,
									TextWrapped = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Top,
								}),
							}
						end,
					},
				}
			)
		end,
		Default = Enum.ParticleFlipbookLayout.None,
		Disabled = function(inputValues)
			local imageDimensions = getImageResolution(inputValues["ID"]:get(false))

			-- allowed dimenisons are 8x8, 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024
			if imageDimensions.X % 8 == 0 and imageDimensions.Y % 8 == 0 then
				return false
			end

			inputValues["Flipbook Layout"]:set(Enum.ParticleFlipbookLayout.None)
			return true
		end,
	},
}

local function createTextureModal(props: props)
	local hasCreated = false
	local inputValues: { [string]: fusion.Value<any> } = {}
	local areInputsValid: fusion.Value<{ [string]: fusion.Value<boolean> }> = Value({})
	local isConfirmDisabled = Computed(function()
		for _, value in areInputsValid:get() do
			if not value:get() then
				return true
			end
		end

		return false
	end)

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
						Appearance = props.useColor("Title", true),
						Text = {
							Label = `{props.VerbUsed} {props.IsFolder and "Folder" or "Texture"}`,
							Font = Font.new(theme.global.font.Family, Enum.FontWeight.SemiBold),
							TextSize = 18,
						},
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
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
			ForPairs(inputs, function(index, value)
				if value.NeedsTexture and props.IsFolder then
					return index
				end

				local default = if props.OverwriteDefaults and props.OverwriteDefaults[value.Name] ~= nil
					then props.OverwriteDefaults[value.Name]
					else value.Default
				local inputValue = Value(default)
				local validateResponse = value.Validate and value.Validate(inputValue)
				local isInputValid = Value(if validateResponse ~= nil then validateResponse else true)

				inputValues[value.Name] = inputValue

				local oldValidInputs = areInputsValid:get(false)
				oldValidInputs[value.Name] = isInputValid
				areInputsValid:set(oldValidInputs)

				local cleanup = {
					Observer(inputValue):onChange(function()
						if value.Validate then
							local isValid = value.Validate(inputValue)
							isInputValid:set(isValid)
						else
							isInputValid:set(true)
						end
					end),
				}

				return index,
					modalOptionWrapper({
						OptionName = value.Name,
						Content = {
							value.Render({
								Value = inputValue,
								LayoutOrder = 1,
								Disabled = value.Disabled and Computed(function()
									return value.Disabled(inputValues, areInputsValid)
								end) or false,
							}),
						},
					}),
					cleanup
			end, Clean),
			Computed(function()
				if inputValues["Flipbook Layout"] == nil then
					return nil
				end

				local flipbookMode: Enum.ParticleFlipbookLayout = inputValues["Flipbook Layout"]:get()
				local withoutGrid = flipbookMode.Name:gsub("Grid", "")

				if areInputsValid:get().ID:get() == false then
					return nil
				end

				return textureImage({
					Image = inputValues["ID"]:get(),
					FlipbookMode = flipbookMode ~= Enum.ParticleFlipbookLayout.None and withoutGrid or nil,
					LayoutOrder = 4,
					Size = UDim2.new(0, 96, 0, 96),
					[Children] = {
						New("UICorner")({
							CornerRadius = UDim.new(0, 4),
						}),
					},
				})
			end, Clean),
			button({
				Color = "gray",
				Variant = "solid",
				ButtonText = `{props.VerbUsed} texture`,
				AutomaticSize = Enum.AutomaticSize.XY,
				Disabled = isConfirmDisabled,
				OnClick = function()
					if hasCreated then
						return
					end

					if inputValues["ID"] then
						local flipbookMode: Enum.ParticleFlipbookLayout = inputValues["Flipbook Layout"]:get(false)
						local withoutGrid = flipbookMode.Name:gsub("Grid", "")

						props.OnCreate(
							inputValues["Name"]:get(false),
							inputValues["ID"]:get(false),
							flipbookMode ~= Enum.ParticleFlipbookLayout.None and withoutGrid or nil
						)
					else
						props.OnCreate(inputValues["Name"]:get(false))
					end

					hasCreated = true
				end,
				LayoutOrder = 5,
			}),
		},
	})
end

return createTextureModal
