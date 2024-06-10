local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs

local appTopbarItem = require("@components/appTopbarItem")

type props = {
	Items: fusion.Value<{ Instance }>,
	SelectedInstance: fusion.Value<Instance>,
}

local function AppTopbar(props: props)
	return New("ScrollingFrame")({
		Name = "Topbar",
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(1, 0, 0, 32),
		[Children] = {
			New("UIFlexItem")({
				FlexMode = Enum.UIFlexMode.Fill,
			}),
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			New("UIPadding")({
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
				PaddingTop = UDim.new(0, 2),
			}),
			ForPairs(props.Items, function(index, item)
				return index,
					appTopbarItem({
						Item = item,
						Selected = Computed(function()
							return props.SelectedInstance:get() == item
						end),
						OnClick = function()
							props.SelectedInstance:set(item)
						end,
						OnClose = function()
							local oldItems = props.Items:get()
							table.remove(oldItems, index)
							props.Items:set(oldItems)

							if props.SelectedInstance:get() == item then
								props.SelectedInstance:set(nil)
							end
						end,
					})
			end, Clean),
		},
	})
end

return AppTopbar
