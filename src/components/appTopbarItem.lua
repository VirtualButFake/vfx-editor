local StudioService = game:GetService("StudioService")

local fusion = require("@packages/fusion")
local Spring = fusion.Spring
local Tween = fusion.Tween

local Children = fusion.Children
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local baseButton = studioComponents.base.button
local baseText = studioComponents.base.text
local baseIcon = studioComponents.base.icon
local button = studioComponents.common.button

local theme = require("@src/theme")

local function interpolate(a, b, t)
	return a + (b - a) * t
end

type props = {
	Item: Instance,
	Selected: fusion.Computed<boolean>,
	OnClick: () -> nil,
	OnClose: () -> nil,
}

local function AppTopbarItem(props: props)
	local isHovering = Value(false)
	local isPressing = Value(false)

	local useColor = theme:get(
		"AppTopbarItem",
		"gray",
		"default",
		Computed(function()
			local selected = props.Selected:get()
			local pressing = isPressing:get()
			local hovering = isHovering:get()

			if selected then
				return "Selected"
			elseif pressing then
				return "Pressing"
			elseif hovering then
				return "Hover"
			else
				return "Base"
			end
		end)
	)

	return New("Frame")({
        Name = "AppTopbarItemWrapper",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
		[Children] = {
			baseButton({
				Name = "AppTopbarItem",
				AutomaticSize = Enum.AutomaticSize.XY,
				Appearance = useColor("Background", true),
				Stroke = useColor("Stroke", true),
				OnHover = function(state)
					isHovering:set(state)
				end,
				OnMouseButton1Changed = function(isPressed)
					isPressing:set(isPressed)
				end,
				OnClick = props.OnClick,
				DisableHoverLighting = true,
				Size = Spring(
					Computed(function()
						if props.Selected:get() then
							return UDim2.new(0, 0, 1, 0)
						else
							return UDim2.new(0, 0, 0.8, 0)
						end
					end),
					40,
					1
				),
				[Children] = {
					-- this REALLY shouldnt be necessary
					New("Frame")({
						Name = "StrokeFiller",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Tween(
							Computed(function()
								return useColor("Background").color
							end),
							TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						BackgroundTransparency = Tween(
							Computed(function()
								return useColor("Background").transparency
							end),
							TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(1, 0, 0.1, 0),
						ZIndex = 0,
					}),
					New("Frame")({
						Name = "CornerFiller",
						AnchorPoint = Vector2.new(0.5, 1),
						AutomaticSize = Enum.AutomaticSize.None,
						BackgroundColor3 = Tween(
							Computed(function()
								return useColor("Background").color
							end),
							TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						BackgroundTransparency = Tween(
							Computed(function()
								if props.Selected:get() then
									return useColor("Background").transparency
								else
									return 1
								end
							end),
							TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						Position = UDim2.new(0.5, 0, 1, 0),
						Size = UDim2.new(1, 0, 0.5, 0),
						ZIndex = -1,
						[Children] = {
							New("UIStroke")({
								Color = Tween(
									Computed(function()
										return useColor("Stroke").color
									end),
									TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
								),
								Transparency = Tween(
									Computed(function()
										return useColor("Stroke").transparency or 1
									end),
									TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
								),
							}),
						},
					}),
				},
				Content = {
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 4),
					}),
					New("Frame")({
						Name = "Header",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							baseText({
								Name = "Text",
								Appearance = useColor("Text", true),
								Text = props.Item.Name,
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								LayoutOrder = 1,
							}),
							baseIcon({
								Name = "Icon",
								Icon = StudioService:GetClassIcon(props.Item.ClassName).Image,
								Color = useColor("Text", true),
								LayoutOrder = 0,
							}),
						},
					}),
					button({
						Name = "Close",
						Icon = { Name = "x", Size = 16 },
						Color = "gray",
						Variant = "ghost",
						Margin = 1,
						LayoutOrder = 2,
						OnClick = props.OnClose,
					}),
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
				},
			}),
		},
	})
end

return AppTopbarItem
