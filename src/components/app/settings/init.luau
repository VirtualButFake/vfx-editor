local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local ForPairs = fusion.ForPairs
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.common.button
local baseText = fusionComponents.base.text
local frame = fusionComponents.base.frame
local input = fusionComponents.common.input
local scrollingFrame = fusionComponents.common.scrollingFrame
local contextMenu = fusionComponents.common.contextMenu

local tailwind = require("@packages/tailwind")

local theme = require("@src/theme")
local settingsManager = require("@src/lib/settingsManager")

local settings = require("./settings")
local settingsListOption = require("./settingsListOption")

type props = {
	SettingsVisible: fusion.Value<boolean>,
	useColor: theme.useColorFunction,
}

local function settingsMenu(props: props)
	local searchQuery = Value("")
	local sharedContextState = Value(false)

	return New("Frame")({
		Name = "SettingsMenu",
		BackgroundColor3 = theme.global.background,
		Size = UDim2.new(1, 0, 1, 0),
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
			New("Frame")({
				Name = "TopContent",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					button({
						Variant = "solid",
						Color = "white",
						AppearanceOverride = {
							_global = {
								Background = Computed(function()
									return theme.global.isDark:get() and tailwind.neutral[800]
										or Color3.fromRGB(255, 255, 255)
								end),
							},
						},
						Icon = "chevron-left",
						Position = UDim2.new(0, 0, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						OnClick = function()
							props.SettingsVisible:set(false)
						end,
					}),
					input({
						Color = "gray",
						Variant = "default",
						AppearanceOverride = {
							_global = {
								Background = Computed(function()
									return theme.global.isDark:get() and tailwind.neutral[800]
										or Color3.fromRGB(255, 255, 255)
								end),
							},
						},
						Placeholder = "Search settings..",
						Icon = "search",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.new(0, 0, 1, 0),
						Text = searchQuery,
						OnTextChanged = function(text)
							searchQuery:set(text)
						end,
						[Children] = {
							New("UIFlexItem")({
								FlexMode = Enum.UIFlexMode.Fill,
							}),
						},
					}),
				},
			}),
			frame({
				Name = "Settings",
				Size = UDim2.new(1, 0, 1, -28),
				Appearance = props.useColor("TreeBackground", true),
				Stroke = props.useColor("Stroke", true),
				Padding = UDim.new(0, 4),
				Content = {
					scrollingFrame({
						Content = {
							New("UIPadding")({
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 4),
							}),
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 4),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Top,
							}),
							ForPairs(settings, function(index, category)
								return index,
									New("Frame")({
										Name = category.name,
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										LayoutOrder = index,
										Size = UDim2.new(1, 0, 0, 18),
										Visible = Computed(function()
											if searchQuery:get() == "" then
												return true
											end

											for _, field in category.fields do
												if field.title:lower():find(searchQuery:get():lower()) then
													return true
												end
											end

											return false
										end),
										[Children] = {
											New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Right,
												Padding = UDim.new(0, 6),
												SortOrder = Enum.SortOrder.LayoutOrder,
												VerticalAlignment = Enum.VerticalAlignment.Top,
											}),
											baseText({
												Appearance = props.useColor("SecondaryText", true),
												Text = {
													Label = category.name,
													Font = Font.new(theme.global.font.Family, Enum.FontWeight.Bold),
													TextSize = 18,
												},
												Size = UDim2.new(1, 0, 0, 18),
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
											}),
											ForPairs(category.fields, function(idx, field)
												local fieldValue =
													Value(settingsManager.get(field.pluginSettingKey) or field.default)

												local isContextMenuVisible = Value(false)

												return idx,
													contextMenu(
														button({
															Color = "neutral",
															Variant = "ghost",
															DisableHoverLighting = true,
															AutomaticSize = Enum.AutomaticSize.Y,
															Size = UDim2.new(1, -8, 0, 24),
															Content = {
																settingsListOption({
																	Title = field.title,
																	Description = field.description,
																	Content = field.render(fieldValue),
																	Visible = Computed(function()
																		return field.title
																			:lower()
																			:find(searchQuery:get():lower()) ~= nil
																	end),
																}),
															},
														}),
														{
															Color = "gray",
															Variant = "default",
															Visible = isContextMenuVisible,
															VisibleLogic = function(isEnabled)
																local currentState = sharedContextState:get()

																if isEnabled then
																	if typeof(currentState) ~= "boolean" then
																		currentState:set(false)
																	end

																	isContextMenuVisible:set(true)
																	sharedContextState:set(isContextMenuVisible)
																elseif currentState:get() == isContextMenuVisible then
																	isContextMenuVisible:set(false)
																	sharedContextState:set(false)
																end

																return true
															end,
															Options = {
																{
																	{
																		Label = "Reset to default",
																		Icon = "list-restart",
																		Callback = function()
																			fieldValue:set(field.default)
																			-- close self
																			isContextMenuVisible:set(false)
																			sharedContextState:set(false)
																		end,
																	},
																},
															},
														}
													),
													Observer(fieldValue):onChange(function()
														local value = fieldValue:get()

														settingsManager.set(
															field.pluginSettingKey,
															field.set and field.set(value) or value
														)
													end)
											end, Clean),
										},
									})
							end, Clean),
						},
						ScrollingFrameProps = {
							VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
						},
						Size = UDim2.new(1, 0, 1, 0),
					}),
				},
			}),
		},
	})
end

return settingsMenu
