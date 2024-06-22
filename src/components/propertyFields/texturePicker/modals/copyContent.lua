local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New
local Cleanup = fusion.Cleanup

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text
local input = studioComponents.common.input
local button = studioComponents.common.button

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local theme = require("@src/theme")

type props = {
	useColor: theme.useColorFunction,
	ClipboardContent: string,
	OnClose: () -> (),
}

local function copyContentModal(props: props)
	local connections = {}

	local component = New("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 0, 0),
		[Cleanup] = connections,
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
							Label = "Copy to clipboard",
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
			text({
				Appearance = props.useColor("Description", true),
				Text = {
					Label = "Click the text box below and press <b>Ctrl+C</b> to copy the following content:",
					TextSize = 14,
					Font = theme.global.font,
				},
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
			}),
			input({
				Color = "gray",
				Variant = "default",
				Size = UDim2.new(0, 200, 0, 24),
				Text = props.ClipboardContent,
			}),
			--[[ button({
				Color = "gray",
				Variant = "solid",
				ButtonText = "Close menu",
				AutomaticSize = Enum.AutomaticSize.XY,
                OnClick = props.OnClose
            })]]
		},
	})

	-- there is *no* reason for this to be as hard as it is but roblox for some reason requires active input in order to copy text
	local box: TextBox = component:FindFirstChild("InputBox", true)
	box.TextEditable = false

	table.insert(
		connections,
		box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			box.SelectionStart = 1
			box.CursorPosition = #props.ClipboardContent + 1
		end)
	)

	table.insert(
		connections,
		box:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			box.SelectionStart = 1
			box.CursorPosition = #props.ClipboardContent + 1
		end)
	)

	box:CaptureFocus()

	return component
end

return copyContentModal
