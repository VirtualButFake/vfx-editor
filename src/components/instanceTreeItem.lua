local StudioService = game:GetService("StudioService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs

local theme = require("@src/theme")

local studioComponents = require("@packages/studioComponents")
local baseIcon = studioComponents.base.icon
local baseText = studioComponents.base.text
local button = studioComponents.common.button

type props = {
	Instance: Instance,
	Query: fusion.CanBeState<string>,
	Depth: number,
	MaxDepth: number,
	TreeContext: {
		Children: { Instance },
		Lines: { [number]: string },
	}?,
}
local TREE_TAB_SIZE = 24
local ALLOWED_CLASSNAMES = {
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Attachment",
}

local function instanceTreeItem(props: props)
	local useColor = theme:get("InstanceTreeItem", "gray", "default", "Base")
	local lineState = {}
	local cascadingLines = {}

	if props.TreeContext then
		local selfIndex = table.find(props.TreeContext.Children, props.Instance)

		if selfIndex then
			local isLastChild = selfIndex == #props.TreeContext.Children
			local isFirstChild = selfIndex == 1

			if not isLastChild then
				table.insert(lineState, isFirstChild and "StartVertical" or "Vertical")
			else
				table.insert(lineState, "Horizontal")
				table.insert(lineState, "HalfVertical")
			end

			if not isLastChild and not isFirstChild then
				table.insert(lineState, "Horizontal")
			end

			if isFirstChild then
				table.insert(lineState, "Horizontal")
				table.insert(lineState, isLastChild and "HalfVertical" or "StartVertical")
			end

			local lineContext = table.clone(props.TreeContext.Lines)

			if not isLastChild then
				lineContext[props.Depth] = { "Vertical" }
			end

			cascadingLines = lineContext
		end
	end

	local function makeLine(type: string): GuiObject?
		if type == "Vertical" then
			return New("Frame")({
				Name = "Vertical",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0.5, -2),
				Size = UDim2.new(0, 1, 1, 4),
			})
		elseif type == "StartVertical" then
			return New("Frame")({
				Name = "StartVertical",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0, 1, 1, 2),
			})
		elseif type == "Horizontal" then
			return New("Frame")({
				Name = "Horizontal",
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.new(1, -4, 0, 1),
			})
		elseif type == "HalfVertical" then
			return New("Frame")({
				Name = "HalfVertical",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Computed(function()
					return useColor("Line").color
				end),
				Position = UDim2.new(0, 0, 0, -2),
				Size = UDim2.new(0, 1, 0.5, 2),
			})
		end

		return nil
	end

	return New("Frame")({
		Name = "InstanceTreeItem",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("Frame")({
				Name = "MainContent",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				[Children] = {
					New("Frame")({
						Name = "LineContainer",
						BackgroundTransparency = 1,
						Size = UDim2.new(0, props.Depth * TREE_TAB_SIZE, 1, 0),
						[Children] = {
							if #lineState > 0
								then New("Frame")({
									Name = tostring(props.Depth),
									BackgroundTransparency = 1,
									Position = UDim2.new(
										0,
										math.clamp((props.Depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 8,
										0,
										0
									),
									Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
									[Children] = {
										--[[table.find(lineState, "Vertical") and New("Frame")({
											Name = "Vertical",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundColor3 = Computed(function()
												return useColor("Line").color
											end),
											Position = UDim2.new(0, 0, 0.5, -2),
											Size = UDim2.new(0, 1, 1, 4),
										}),
										table.find(lineState, "Horizontal") and New("Frame")({
											Name = "Horizontal",
											AnchorPoint = Vector2.new(1, 0.5),
											BackgroundColor3 = Computed(function()
												return useColor("Line").color
											end),
											Position = UDim2.new(1, -4, 0.5, 0),
											Size = UDim2.new(1, -4, 0, 1),
										}),
										table.find(lineState, "HalfVertical") and New("Frame")({
											Name = "HalfVertical",
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundColor3 = Computed(function()
												return useColor("Line").color
											end),
											Position = UDim2.new(0, 0, 0, -2),
											Size = UDim2.new(0, 1, 0.5, 2),
										}),]]
										ForPairs(lineState, function(index, value)
											return index, makeLine(value)
										end, Clean),
									},
								})
								else nil,
							ForPairs(cascadingLines, function(depth, states)
								if depth == props.Depth then
									return depth, nil
								end

								return depth,
									New("Frame")({
										Name = tostring(depth),
										BackgroundTransparency = 1,
										Position = UDim2.new(
											0,
											math.clamp((depth - 1) * TREE_TAB_SIZE, 0, math.huge) + 8,
											0,
											0
										),
										Size = UDim2.new(0, TREE_TAB_SIZE - 8, 1, 0),
										[Children] = {
											ForPairs(states, function(index, value)
												return index, makeLine(value)
											end, Clean),
										},
									})
							end, Clean),
						},
					}),
					New("Frame")({
						Name = "Header",
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.new(1, -props.Depth * TREE_TAB_SIZE, 1, 0),
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								Padding = UDim.new(0, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							New("Frame")({
								Name = "Content",
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Size = UDim2.new(0, 0, 1, 0),
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, 2),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									baseIcon({
										Name = "Icon",
										Icon = StudioService:GetClassIcon(props.Instance.ClassName).Image,
										Color = useColor("Text", true),
										LayoutOrder = 0,
									}),
									baseText({
										Name = "Text",
										Appearance = useColor("Text", true),
										Text = props.Instance.Name,
										AutomaticSize = Enum.AutomaticSize.XY,
										BackgroundTransparency = 1,
										LayoutOrder = 1,
									}),
								},
							}),
							New("Frame")({
								Name = "Arrow",
								BackgroundTransparency = 1,
								Size = UDim2.new(0, 0, 1, 0),
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Right,
										Padding = UDim.new(0, 2),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									New("UIFlexItem")({
										FlexMode = Enum.UIFlexMode.Fill,
									}),
									-- emit
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "play",
									}),
									-- hide other contents
									button({
										Color = "white",
										Variant = "ghost",
										Icon = "chevron-down",
									}),
								},
							}),
						},
					}),
				},
			}),
			if props.Depth ~= props.MaxDepth
				then New("Frame")({
					Name = "SubContent",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					[Children] = {
						New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 2),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						}),
						ForPairs(props.Instance:GetChildren(), function(index, value)
							if not table.find(ALLOWED_CLASSNAMES, value.ClassName) then
								return index, nil
							end

							return index,
								instanceTreeItem({
									Instance = value,
									Query = props.Query,
									Depth = props.Depth + 1,
									MaxDepth = props.MaxDepth,
									TreeContext = {
										Children = props.Instance:GetChildren(),
										Lines = cascadingLines,
									},
								})
						end, Clean),
					},
				})
				else nil,
		},
	})
end

return instanceTreeItem
