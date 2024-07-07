local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local contextMenu = studioComponents.common.contextMenu

local appTopbarItem = require("@components/appTopbarItem")

type props = {
	Items: fusion.Value<{ Instance }>,
	SelectedInstance: fusion.Value<Instance>,
	SharedContextMenuState: fusion.Value<boolean>,
}

local function AppTopbar(props: props)
	local visualSelectedInstance = Value(props.SelectedInstance:get())

	return New("ScrollingFrame")({
		Name = "Topbar",
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(1, 0, 0, 32),
		[Cleanup] = {
			Observer(props.SelectedInstance):onChange(function()
				visualSelectedInstance:set(props.SelectedInstance:get())
			end),
		},
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
				if not game:IsAncestorOf(item) then
					return
				end

				local isContextMenuVisible = Value(false)

				local function closeSelf()
					isContextMenuVisible:set(false)

					if props.SharedContextMenuState:get() == isContextMenuVisible then
						props.SharedContextMenuState:set(false)
					end
				end

				return index,
					contextMenu(
						appTopbarItem({
							Item = item,
							Selected = Computed(function()
								return visualSelectedInstance:get() == item
							end),
							LayoutOrder = index,
							OnClick = function()
								task.spawn(function()
									props.SelectedInstance:set(item)
								end)

								visualSelectedInstance:set(item)
							end,
							OnClose = function()
								local oldItems = props.Items:get()
								table.remove(oldItems, index)
								props.Items:set(oldItems)

								if props.SelectedInstance:get() == item then
									visualSelectedInstance:set(nil)
									props.SelectedInstance:set(nil)
								end
							end,
						}),
						{
							Color = "gray",
							Variant = "default",
							Visible = isContextMenuVisible,
							EnabledLogic = function(isEnabled)
								local currentState = props.SharedContextMenuState:get()

								if isEnabled then
									if typeof(currentState) ~= "boolean" then
										currentState:set(false)
									end

									isContextMenuVisible:set(true)
									props.SharedContextMenuState:set(isContextMenuVisible)
								elseif currentState:get() == isContextMenuVisible then
									isContextMenuVisible:set(false)
									props.SharedContextMenuState:set(false)
								end

								return true
							end,
							Options = {
								{
									{
										Label = "Select in Explorer",
										Icon = "list-tree",
										Callback = function()
											Selection:Set({ item })
											closeSelf()
										end,
									},
								},
								{
									{
										Label = "Close",
										Icon = "x",
										Callback = function()
											local oldItems = props.Items:get()
											table.remove(oldItems, index)
											props.Items:set(oldItems)

											closeSelf()
										end,
									},
									{
										Label = "Close to right",
										Icon = "panel-right-close",
										Callback = function()
											local oldItems = props.Items:get()
											local newItems = {}

											for i = 1, index do
												table.insert(newItems, oldItems[i])
											end

											props.Items:set(newItems)

											closeSelf()
										end,
									},
									{
										Label = "Close others",
										Icon = "copy-x",
										Callback = function()
											props.Items:set({ item })

											closeSelf()
										end,
									},
									{
										Label = "Close all",
										Icon = "list-x",
										Callback = function()
											props.Items:set({})
											closeSelf()
										end,
									},
								},
							},
						}
					),
					item.AncestryChanged:Connect(function()
						if not game:IsAncestorOf(item) then
							local oldItems = props.Items:get()
							table.remove(oldItems, index)
							props.Items:set(oldItems)

							if props.SelectedInstance:get() == item then
								visualSelectedInstance:set(nil)
								props.SelectedInstance:set(nil)
							end
						end
					end)
			end, Clean),
		},
	})
end

return AppTopbar
