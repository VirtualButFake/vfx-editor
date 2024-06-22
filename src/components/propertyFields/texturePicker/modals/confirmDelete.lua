local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text
local button = studioComponents.common.button

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local theme = require("@src/theme")

local function concatMultilineString(...: string)
	return table.concat({ ... }, "\n")
end

type props = {
	useColor: theme.useColorFunction,
	OnClick: (confirmed: boolean) -> (),
	ContentCount: {
		Textures: number,
		Folders: number,
	},
}

local function createFolderModal(props: props)
	local operationDone = false

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
			text({
				Appearance = props.useColor("Title", true),
				Text = {
					Label = "Confirm deletion",
					Font = Font.new(use(theme.global.font).Family, Enum.FontWeight.SemiBold),
					TextSize = 18,
				},
				AutomaticSize = Enum.AutomaticSize.XY,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			text({
				Appearance = props.useColor("Description", true),
				Text = {
					Label = concatMultilineString(
						"Are you sure that you want to remove these items and <b>irreversibly</b> remove all of their contents?",
						`\n<b>When deleted, {props.ContentCount.Folders} folder(s) and {props.ContentCount.Textures} texture(s) will be lost.</b>`
					),
					TextSize = 14,
					Font = theme.global.font,
				},
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
			}),
			New("Frame")({
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					button({
						Color = "gray",
						Variant = "ghost",
						ButtonText = "Cancel",
						AutomaticSize = Enum.AutomaticSize.XY,
						Margin = 6,
						OnClick = function()
							if operationDone then
								return
							end

							props.OnClick(false)
							operationDone = true
						end,
					}),
					button({
						Color = "red",
						Variant = "solid",
						ButtonText = "Delete",
						AutomaticSize = Enum.AutomaticSize.XY,
						Margin = 6,
						OnClick = function()
							if operationDone then
								return
							end

							props.OnClick(true)
							operationDone = true
						end,
					}),
				},
			}),
		},
	})
end

return createFolderModal
