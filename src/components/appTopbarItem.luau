local fusion = require("@packages/fusion")
local Spring = fusion.Spring
local Tween = fusion.Tween

local Children = fusion.Children
local New = fusion.New
local Event = fusion.OnEvent

local Computed = fusion.Computed
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local baseFrame = fusionComponents.base.frame
local baseText = fusionComponents.base.text
local baseImageLabel = fusionComponents.base.imageLabel
local button = fusionComponents.common.button

local theme = require("@src/theme")

type props = {
	Item: Instance,
	Selected: fusion.Computed<boolean>,
	LayoutOrder: number,
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

	local classIcon = theme.getClassIcon(props.Item.ClassName)

	return New("TextButton")({
		Name = "AppTopbarItemWrapper",
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		[Event("MouseButton1Down")] = function()
			isPressing:set(true)
		end,
		[Event("MouseEnter")] = function()
			isHovering:set(true)
		end,
		[Event("MouseButton1Up")] = function()
			isPressing:set(false)
			props.OnClick()
		end,
		[Event("MouseLeave")] = function()
			isHovering:set(false)
			isPressing:set(false)
		end,
		[Children] = {
			baseFrame({
				Name = "AppTopbarItem",
				AutomaticSize = Enum.AutomaticSize.XY,
				Appearance = useColor("Background", true),
				Stroke = useColor("Stroke", true),
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
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = Tween(
							Computed(function()
								return useColor("Background").color
							end),
							TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						),
						BackgroundTransparency = Spring(
							Computed(function()
								if props.Selected:get() then
									return 0
								else
									return 1
								end
							end),
							30,
							1
						),
						Position = UDim2.new(0, 0, 1, 0),
						Size = UDim2.new(1, 0, 0.1, 0),
						ZIndex = 2,
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
							baseImageLabel({
								Name = "Icon",
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
								Appearance = useColor("Text", true),
								LayoutOrder = 0,
							}),
						},
					}),
					button({
						Name = "Close",
						Icon = { Name = "x", Size = 16 },
						Color = "gray",
						Variant = "ghost",
						Padding = 1,
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
