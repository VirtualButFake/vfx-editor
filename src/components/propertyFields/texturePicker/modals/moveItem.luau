local fusion = require("@packages/fusion")
local New = fusion.New
local Children = fusion.Children

local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local text = fusionComponents.base.text
local button = fusionComponents.common.button
local frame = fusionComponents.base.frame
local scrollFrame = fusionComponents.common.scrollingFrame

local theme = require("@src/theme")

local treeButton = require("../treeButton")

type props = {
	useColor: theme.useColorFunction,
	OnMove: (path: { string }) -> (),
	OnClose: () -> (),
	Textures: fusion.Value<any>, -- no need to type this, it's just to pass to a child component
	CurrentPath: { string },
	IsFolder: boolean,
}

local function moveItemModal(props: props)
	local selectedPath = Value(props.CurrentPath)
	local isConfirmDisabled = Value(true)

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
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				[Children] = {
					text({
						Appearance = props.useColor("Title", true),
						Text = {
							Label = "Move Item",
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
			frame({
				Appearance = props.useColor("LighterBackground", true),
				Stroke = props.useColor("Line", true),
				Size = UDim2.new(0, 200, 0, 200),
				Content = {
					scrollFrame({
						Content = {
							New("UIPadding")({
								PaddingBottom = UDim.new(0, 4),
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 4),
								PaddingTop = UDim.new(0, 4),
							}),
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								HorizontalFlex = Enum.UIFlexAlignment.Fill,
								Padding = UDim.new(0, 2),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Top,
							}),
							treeButton({
								Name = "Home",
								CurrentPath = selectedPath,
								Content = props.Textures,
								DisabledCascades = props.IsFolder,
								DisabledPath = props.CurrentPath,
								OnClick = function(path)
									selectedPath:set(path)
									isConfirmDisabled:set(false)
								end,
								Path = { "Home" },
							}),
						},
						ScrollingFrameProps = {
							VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
						},
						Size = UDim2.new(1, 0, 1, 0),
					}),
				},
			}),
			button({
				Color = "gray",
				Variant = "solid",
				ButtonText = "Move item",
				AutomaticSize = Enum.AutomaticSize.XY,
				Disabled = isConfirmDisabled,
				OnClick = function()
					props.OnMove(selectedPath:get())
				end,
			}),
		},
	})
end

return moveItemModal
