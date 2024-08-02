local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Spring = fusion.Spring

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Out = fusion.Out

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.common.button
local breadcrumb = fusionComponents.common.breadcrumb
local input = fusionComponents.common.input
local modal = fusionComponents.common.modal
local popover = fusionComponents.common.popover
local contextMenu = fusionComponents.common.contextMenu
local menuEntry = fusionComponents.utility.menuEntry
local text = fusionComponents.base.text
local icon = fusionComponents.base.icon
local frame = fusionComponents.base.frame
local scrollFrame = fusionComponents.common.scrollingFrame

local tailwind = require("@packages/tailwind")

local fusionUtils = require("@packages/fusionUtils")
local awaitLayer = fusionUtils.awaitLayer

local virtualScroller = require("@components/virtualScroller")

local textureImage = require("./textureImage")
local treeButton = require("./treeButton")
local createFolderModal = require("./modals/createFolder")
local modifyTextureModal = require("./modals/modifyTexture")
local moveItemModal = require("./modals/moveItem")
local confirmDeleteModal = require("./modals/confirmDelete")
local copyContentModal = require("./modals/copyContent")
local importInstancesModal = require("./modals/importInstances")
local importJsonModal = require("./modals/importJson")

local settingsManager = require("@src/lib/settingsManager")
local theme = require("@src/theme")

local function traverseTextureList(textureList: { textureList }, path: { string }): { texture | textureList }
	local items = textureList

	for _, label in path do
		if label == "" then
			continue
		end

		for _, item in items do
			if item.name == label then
				items = item.content
				break
			end
		end
	end

	return items
end

local function tableFind(t: { any }, predicate: (any) -> boolean): any?
	for _, value in t do
		if predicate(value) then
			return value
		end
	end

	return nil
end

-- natural sort, from https://stackoverflow.com/questions/27909784
local function stringCompare(a, b)
	a = tostring(a)
	b = tostring(b)
	local patt = "^(.-)%s*(%d+)$"
	local _, _, col1, num1 = a:find(patt)
	local _, _, col2, num2 = b:find(patt)
	if (col1 and col2) and col1 == col2 then
		return tonumber(num1) < tonumber(num2)
	end
	return a < b
end

type texture = {
	name: string,
	id: string,
	flipbookLayout: nil | "2x2" | "4x4" | "8x8",
}

export type textureList = {
	name: string,
	content: { texture | textureList },
}

type props = {
	Value: fusion.Value<{
		Texture: string,
		FlipbookLayout: Enum.ParticleFlipbookLayout,
	}>?,
	Path: fusion.Computed<{ string }>,
	IsSelectingImage: boolean,
}

local SIDEBAR_WIDTH = 200
local EDITOR_BUTTON_SIZE = 96

local function editor(props: props)
	local useColor = theme:get("TexturePicker", "gray", "default", "Base")

	local searchQuery = Value("")
	local currentPath = Value(props.Path:get(false) or { "Home" })

	local textures = settingsManager.getReactiveWithFallback("textures", {})

	local currentItems: fusion.Computed<{ texture | textureList }> = Computed(function()
		local path = currentPath:get() or ""
		local usedTextures = textures and textures:get()

		if not usedTextures then
			return {}
		end

		if path == "" then
			return usedTextures
		end

		local items = traverseTextureList(usedTextures, path)

		-- sort items; we want folders first, then textures
		local query = searchQuery:get():lower()

		table.sort(items, function(a, b)
			if not a then
				return false
			elseif not b then
				return true
			end

			if query ~= "" then
				local aMatchesQuery = string.lower(a.name):find(query)
				local bMatchesQuery = string.lower(b.name):find(query)

				if aMatchesQuery and not bMatchesQuery then
					return true
				elseif not aMatchesQuery and bMatchesQuery then
					return false
				elseif aMatchesQuery and bMatchesQuery then
					return aMatchesQuery < bMatchesQuery
				end
			end

			if a.id == nil and b.id == nil then
				return stringCompare(a.name, b.name)
			elseif a.id == nil then
				return true
			elseif b.id == nil then
				return false
			end

			return stringCompare(a.name, b.name)
		end)

		return items
	end)

	local breadcrumbLabels = Value({
		{
			Text = "Home",
			Icon = "home",
			OnClick = function()
				currentPath:set({ "Home" })
			end,
		},
	})

	local breadcrumbSize = Value(Vector2.new())
	local containerSize = Value(Vector2.new())
	local contentSize = Value(Vector2.new())

	local isContextMenuVisible = Value(false)
	local isModalVisible = Value(false)
	local isPopoverVisible = Value(false)
	local modalContent = Value({})

	local selectedIndices = Value({})
	local isCtrlHeld = Value(false)
	local isShiftHeld = Value(false)

	local connections = {}

	local function deleteIds(textureList: { texture })
		local path = currentPath:get() or ""
		local usedTextures = textures and textures:get(false)

		if not usedTextures then
			return
		end

		local items = traverseTextureList(usedTextures, path)

		for _, texture in textureList do
			for i, item in items do
				if item.name == texture.name then
					table.remove(items, i)
					break
				end
			end
		end

		settingsManager.set("textures", usedTextures)
	end

	local component = New("Frame")({
		Name = "TexturePicker",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Cleanup] = {
			connections,
			Observer(currentPath):onChange(function()
				local path = currentPath:get() or {}
				local iteratedPath = {}

				local labels = breadcrumbLabels:get()

				-- Remove labels that are not in the path
				for i = #labels, 1, -1 do
					local label = labels[i]
					local labelPath = label.Text

					if not table.find(path, labelPath) and labelPath ~= "Home" then
						table.remove(labels, i)
					end
				end

				-- Add paths that are not in the labels
				for _, label in path do
					if label == "" then
						continue
					end

					table.insert(iteratedPath, label)

					local found = false
					for _, existingLabel in labels do
						if existingLabel.Text == label then
							found = true
							break
						end
					end

					if not found then
						table.insert(labels, {
							Text = label,
							OnClick = function()
								currentPath:set(iteratedPath)
							end,
						})
					end
				end

				breadcrumbLabels:set(labels)
			end),
		},
		[Children] = {
			frame({
				Name = "Sidebar",
				Appearance = useColor("SidebarBackground", true),
				Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
				CornerRadius = UDim.new(0, 0),
				Content = {
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 4),
					}),
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					input({
						Color = "gray",
						Variant = "default",
						Placeholder = "Search..",
						Icon = "search",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, 0, 0, 24),
						OnTextChanged = function(inputText)
							searchQuery:set(inputText)
						end,
					}),
					scrollFrame({
						Name = "FolderList",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, -28),
						ScrollingFrameProps = {
							VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
						},
						Content = {
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
								Content = textures,
								CurrentPath = currentPath,
								OnClick = function(path)
									selectedIndices:set({})
									currentPath:set(path)
								end,
								Path = { "Home" },
								Query = searchQuery,
							}),
						},
					}),
				},
			}),
			New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0),
				Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 2),
					}),
					New("Frame")({
						Name = "Topbar",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(1, 0, 0, 28),
						ClipsDescendants = true,
						[Children] = {
							New("UIPadding")({
								PaddingLeft = UDim.new(0, 2),
								PaddingRight = UDim.new(0, 2),
								PaddingTop = UDim.new(0, 2),
								PaddingBottom = UDim.new(0, 2),
							}),
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 4),
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							New("ScrollingFrame")({
								Name = "BreadcrumbContainer",
								AutomaticCanvasSize = Enum.AutomaticSize.X,
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								CanvasPosition = Spring(
									Computed(function()
										-- this tries to scroll as far right as possible
										local canvasSize = containerSize:get()
										local viewportSize = breadcrumbSize:get()

										if canvasSize == nil or viewportSize == nil then
											return Vector2.new(0, 0)
										end

										return Vector2.new(viewportSize.X - canvasSize.X, 0)
									end),
									30,
									1
								),
								CanvasSize = UDim2.new(0, 0, 0, 0),
								ClipsDescendants = true,
								ScrollBarThickness = 0,
								ScrollingEnabled = false,
								Size = UDim2.new(1, 0, 0, 24),
								[Out("AbsoluteSize")] = containerSize,
								[Children] = {
									New("UIFlexItem")({
										FlexMode = Enum.UIFlexMode.Fill,
									}),
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										[Out("AbsoluteContentSize")] = breadcrumbSize,
									}),
									breadcrumb({
										Color = "blue",
										Labels = breadcrumbLabels,
									}),
								},
							}),
							(function()
								local isThisPopoverVisible = Value(false)

								local createdButton = button({
									Color = "gray",
									Variant = "solid",
									Icon = "plus",
									AutomaticSize = Enum.AutomaticSize.XY,
									OnClick = function()
										local currentPopoverVisible = isPopoverVisible:get()

										if
											currentPopoverVisible ~= false
											and currentPopoverVisible ~= isThisPopoverVisible
										then
											isPopoverVisible:get():set(false)
										end

										isThisPopoverVisible:set(not isThisPopoverVisible:get())
										isPopoverVisible:set(isThisPopoverVisible)

										if isContextMenuVisible:get() then
											isContextMenuVisible:get():set(false)
										end
									end,
								})

								local lastContent = nil
								local contentObserver = Observer(modalContent):onChange(function()
									if lastContent then
										lastContent:destroy()
									end

									lastContent = modalContent:get()
								end)

								return modal(
									popover(createdButton, {
										Variant = "default",
										Visible = isThisPopoverVisible,
										Placement = "bottom",
										RelativePosition = UDim2.new(0, -50, 0, 0),
										Content = {
											New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												HorizontalFlex = Enum.UIFlexAlignment.Fill,
												Padding = UDim.new(0, 4),
												SortOrder = Enum.SortOrder.LayoutOrder,
												VerticalAlignment = Enum.VerticalAlignment.Top,
											}),
											menuEntry({
												Option = {
													Label = "Create Folder",
													Icon = "folder-plus",
													Color = "gray",
												},
												OnClick = function()
													isModalVisible:set(true)
													isThisPopoverVisible:set(false)
													isPopoverVisible:set(false)

													modalContent:set(createFolderModal({
														useColor = useColor,
														OnCreate = function(name: string)
															local path = currentPath:get() or ""
															local usedTextures = textures and textures:get(false)

															if not usedTextures then
																return
															end

															local items = traverseTextureList(usedTextures, path)

															-- if there is already a folder with this name, add (x) to the end
															local newName = name
															local i = 1

															while
																tableFind(items, function(item)
																	return item.name == newName
																end)
															do
																i = i + 1
																newName = name .. " (" .. i .. ")"
															end

															table.insert(items, {
																name = newName,
																content = {},
															})

															settingsManager.set("textures", usedTextures)
															isModalVisible:set(false)
														end,
														OnClose = function()
															isModalVisible:set(false)
														end,
													}))
												end,
											}),
											menuEntry({
												Option = {
													Label = "Create Texture",
													Icon = "image-plus",
													Color = "gray",
												},
												OnClick = function()
													isModalVisible:set(true)
													isThisPopoverVisible:set(false)

													modalContent:set(modifyTextureModal({
														VerbUsed = "Create",
														useColor = useColor,
														OnCreate = function(name, id, flipbookLayout)
															local path = currentPath:get() or ""
															local usedTextures = textures and textures:get(false)

															if not usedTextures then
																return
															end

															local items = traverseTextureList(usedTextures, path)

															-- prevent duplicate names, duplicate names will be suffixed with (x)
															local newName = name
															local i = 1

															while
																tableFind(items, function(item)
																	return item.name == newName
																end)
															do
																i = i + 1
																newName = name .. " (" .. i .. ")"
															end

															table.insert(items, {
																name = newName,
																id = id,
																flipbookLayout = flipbookLayout,
															})

															settingsManager.set("textures", usedTextures)
															isModalVisible:set(false)
														end,
														OnClose = function()
															isModalVisible:set(false)
														end,
													}))
												end,
											}),
										},
										[Cleanup] = contentObserver,
									}),
									{
										Visible = isModalVisible,
										Padding = UDim.new(0, 8),
										OnClickBesides = function()
											isModalVisible:set(false)
										end,
										Content = modalContent,
									}
								)
							end)(),
							(function()
								local isThisPopoverVisible = Value(false)

								return popover(
									button({
										Color = "gray",
										Variant = "solid",
										Icon = "download",
										AutomaticSize = Enum.AutomaticSize.XY,
										OnClick = function()
											local currentPopoverVisible = isPopoverVisible:get()

											if
												currentPopoverVisible ~= false
												and currentPopoverVisible ~= isThisPopoverVisible
											then
												isPopoverVisible:get():set(false)
											end

											isThisPopoverVisible:set(not isThisPopoverVisible:get())
											isPopoverVisible:set(isThisPopoverVisible)

											if isContextMenuVisible:get() then
												isContextMenuVisible:get():set(false)
											end
										end,
									}),
									{
										Variant = "default",
										Visible = isThisPopoverVisible,
										Placement = "bottom",
										RelativePosition = UDim2.new(0, -50, 0, 0),
										Content = {
											New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												HorizontalFlex = Enum.UIFlexAlignment.Fill,
												Padding = UDim.new(0, 4),
												SortOrder = Enum.SortOrder.LayoutOrder,
												VerticalAlignment = Enum.VerticalAlignment.Top,
											}),
											menuEntry({
												Option = {
													Label = "Import instances",
													Icon = "image-up",
													Color = "gray",
												},
												OnClick = function()
													isModalVisible:set(true)
													modalContent:set(importInstancesModal({
														useColor = useColor,
														BaseTextures = textures:get(false),
														OnClose = function()
															isModalVisible:set(false)
														end,
														OnConfirm = function(newTextures)
															settingsManager.set("textures", newTextures)
															isModalVisible:set(false)
														end,
														Path = currentPath:get(false),
													}))
												end,
											}),
											menuEntry({
												Option = {
													Label = "Import JSON data",
													Icon = "file-json",
													Color = "gray",
												},
												OnClick = function()
													isModalVisible:set(true)
													modalContent:set(importJsonModal({
														useColor = useColor,
														BaseTextures = textures:get(false),
														OnClose = function()
															isModalVisible:set(false)
														end,
														OnConfirm = function(newTextures)
															settingsManager.set("textures", newTextures)
															isModalVisible:set(false)
														end,
														Path = currentPath:get(false),
													}))
												end,
											}),
										},
									}
								)
							end)(),
							(function()
								local isThisPopoverVisible = Value(false)

								return popover(
									button({
										Color = "gray",
										Variant = "solid",
										Icon = "upload",
										AutomaticSize = Enum.AutomaticSize.XY,
										OnClick = function()
											local currentPopoverVisible = isPopoverVisible:get()

											if
												currentPopoverVisible ~= false
												and currentPopoverVisible ~= isThisPopoverVisible
											then
												isPopoverVisible:get():set(false)
											end

											isThisPopoverVisible:set(not isThisPopoverVisible:get())
											isPopoverVisible:set(isThisPopoverVisible)

											if isContextMenuVisible:get() then
												isContextMenuVisible:get():set(false)
											end
										end,
									}),
									{
										Variant = "default",
										Visible = isThisPopoverVisible,
										Placement = "bottom",
										RelativePosition = UDim2.new(0, -50, 0, 0),
										Content = {
											New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												HorizontalFlex = Enum.UIFlexAlignment.Fill,
												Padding = UDim.new(0, 4),
												SortOrder = Enum.SortOrder.LayoutOrder,
												VerticalAlignment = Enum.VerticalAlignment.Top,
											}),
											menuEntry({
												Option = {
													Label = "Export folder",
													Icon = "file-down",
													Color = "gray",
												},
												OnClick = function()
													local path = currentPath:get() or ""
													local usedTextures = textures and textures:get(false)

													if not usedTextures then
														return
													end

													local items = traverseTextureList(usedTextures, path)
													isModalVisible:set(true)
													modalContent:set(copyContentModal({
														useColor = useColor,
														ClipboardContent = HttpService:JSONEncode(items),
														OnClose = function()
															isModalVisible:set(false)
														end,
													}))
												end,
											}),
											menuEntry({
												Option = {
													Label = "Export all",
													Icon = "folder-down",
													Color = "gray",
												},
												OnClick = function()
													isModalVisible:set(true)
													modalContent:set(copyContentModal({
														useColor = useColor,
														ClipboardContent = HttpService:JSONEncode(textures:get()),
														OnClose = function()
															isModalVisible:set(false)
														end,
													}))
												end,
											}),
											Computed(function()
												if #selectedIndices:get() == 0 then
													return nil
												end

												return menuEntry({
													Option = {
														Label = "Export selected",
														Icon = "image-down",
														Color = "gray",
													},
													OnClick = function()
														local path = currentPath:get() or ""
														local usedTextures = textures and textures:get(false)

														if not usedTextures then
															return
														end

														local items = traverseTextureList(usedTextures, path)
														local selectedItems = {}

														for i, isSelected in (selectedIndices:get()) do
															if isSelected then
																table.insert(selectedItems, items[i])
															end
														end

														isModalVisible:set(true)
														modalContent:set(copyContentModal({
															useColor = useColor,
															ClipboardContent = HttpService:JSONEncode(selectedItems),
															OnClose = function()
																isModalVisible:set(false)
															end,
														}))
													end,
												})
											end, Clean),
										},
									}
								)
							end)(),
						},
					}),
					New("Frame")({
						Name = "Content",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(1, 0, 1, -34),
						[Out("AbsoluteSize")] = contentSize,
						[Children] = {
							virtualScroller({
								Size = UDim2.new(1, 0, 1, 0),
								ItemCount = Computed(function()
									return #currentItems:get()
								end),
								ItemHeight = Value(EDITOR_BUTTON_SIZE + 4), -- +4 for padding
								ItemWidth = Value(EDITOR_BUTTON_SIZE + 4),
								CanvasPosition = Value(Vector2.new()),
								RenderItem = function(index: number)
									local item = currentItems:get()[index]

									if item == nil then
										return
									end

									local isThisContextMenuVisible = Value(false)
									local options = {
										{
											Label = "Edit",
											Icon = "pencil",
											Color = "gray",
											Disabled = Computed(function()
												return next(selectedIndices:get()) ~= nil
											end),
											Callback = function()
												if isModalVisible:get() then
													return
												end

												isThisContextMenuVisible:set(false)
												modalContent:set(modifyTextureModal({
													OverwriteDefaults = {
														ID = item.id,
														Name = item.name,
														["Flipbook Layout"] = item.flipbookLayout
																and Enum.ParticleFlipbookLayout["Grid" .. item.flipbookLayout]
															or Enum.ParticleFlipbookLayout.None,
													},
													IsFolder = item.id == nil,
													VerbUsed = "Edit",
													useColor = useColor,
													OnCreate = function(name, id, flipbookLayout)
														local path = currentPath:get() or ""
														local usedTextures = textures and textures:get(false)

														if not usedTextures then
															return
														end

														local items = traverseTextureList(usedTextures, path)

														-- make sure this is not a duplicate name, suffix with (x). filter on whether it's the current item though
														local newName = name
														local count = 1

														while
															tableFind(items, function(texture)
																return texture.name == newName and texture.id ~= id
															end)
														do
															count = count + 1
															newName = name .. " (" .. count .. ")"
														end

														for idx, texture in items do
															if texture.name == item.name then
																item.name = newName
																item.id = id
																item.flipbookLayout = flipbookLayout

																items[idx] = item
																break
															end
														end

														settingsManager.set("textures", usedTextures)
														isModalVisible:set(false)
													end,
													OnClose = function()
														isModalVisible:set(false)
													end,
												}))
												isModalVisible:set(true)
											end,
										} or nil,
										{
											Label = "Move",
											Icon = "folder-tree",
											Color = "gray",
											Callback = function()
												isModalVisible:set(true)
												isThisContextMenuVisible:set(false)
												modalContent:set(moveItemModal({
													IsFolder = item.content ~= nil,
													useColor = useColor,
													CurrentPath = currentPath:get() or { "Home" },
													Textures = Value(textures:get()),
													OnClose = function()
														isModalVisible:set(false)
													end,
													OnMove = function(newPath: { string })
														local usedTextures = textures and textures:get(false)

														if not usedTextures then
															return
														end

														local items =
															traverseTextureList(usedTextures, currentPath:get() or "")

														if selectedIndices:get()[index] then
															local selectedItems = {}

															for i, isSelected in (selectedIndices:get()) do
																if isSelected then
																	table.insert(selectedItems, items[i])
																end
															end

															deleteIds(selectedItems)

															local newItems = traverseTextureList(usedTextures, newPath)

															for _, selectedItem in selectedItems do
																table.insert(newItems, selectedItem)
															end

															selectedIndices:set({})
														else
															deleteIds({ item })

															local newItems = traverseTextureList(usedTextures, newPath)

															table.insert(newItems, item)
														end

														settingsManager.set("textures", usedTextures)
														isModalVisible:set(false)

														-- remove self from selected indices, and if we're in between any selected indices, move them forward by 1
														local newSelectedIndices = selectedIndices:get()

														for i, isSelected in newSelectedIndices do
															if isSelected then
																if i == index then
																	newSelectedIndices[i] = nil
																elseif i > index then
																	newSelectedIndices[i - 1] = true
																	newSelectedIndices[i] = nil
																end
															end
														end

														selectedIndices:set(newSelectedIndices)
													end,
												}))
											end,
										},
										{
											Label = "Delete",
											Icon = "trash",
											Color = "gray",
											Callback = function()
												local function delete()
													local path = currentPath:get() or ""
													local usedTextures = textures and textures:get(false)

													if not usedTextures then
														return
													end

													local items = traverseTextureList(usedTextures, path)

													if selectedIndices:get()[index] then
														local selectedItems = {}

														for i, isSelected in (selectedIndices:get()) do
															if isSelected then
																table.insert(selectedItems, items[i])
															end
														end

														deleteIds(selectedItems)
														selectedIndices:set({})
													else
														deleteIds({ item })
													end

													settingsManager.set("textures", usedTextures)
												end

												if
													(item.content and #item.content > 0)
													or selectedIndices:get()[index]
												then
													local textureChildren, folderChildren = 0, 0

													local function iterateItem(subItem)
														for _, child in subItem do
															if child.id then
																textureChildren += 1
															else
																folderChildren += 1
																iterateItem(child.content)
															end
														end
													end

													local items = currentItems:get(false)

													for _, v in items do
														if v.name == item.name then
															iterateItem(v.content)
														end
													end

													for idx, _ in selectedIndices:get() do
														local child = items[idx]

														if child.id then
															textureChildren += 1
														else
															folderChildren += 1
															iterateItem(child.content)
														end
													end

													if folderChildren > 0 or textureChildren > 1 then
														isModalVisible:set(true)
														isThisContextMenuVisible:set(false)
														modalContent:set(confirmDeleteModal({
															useColor = useColor,
															ContentCount = {
																Folders = folderChildren,
																Textures = textureChildren,
															},
															OnClick = function(confirmed)
																isModalVisible:set(false)

																if confirmed then
																	delete()
																end
															end,
														}))

														return
													end
												end

												delete()
											end,
										},
									}
									local function customVisibleLogic(toOpen)
										if toOpen then
											if isContextMenuVisible:get() then
												isContextMenuVisible:get():set(false)
											end

											isContextMenuVisible:set(isThisContextMenuVisible)
											isThisContextMenuVisible:set(true)
										else
											if isContextMenuVisible:get() == isThisContextMenuVisible then
												isContextMenuVisible:set(false)
											end

											isThisContextMenuVisible:set(false)
										end
									end

									local appearanceOverride = Computed(function()
										local color = theme.global.isDark:get() and tailwind.neutral[700]
											or tailwind.neutral[200]

										if selectedIndices:get()[index] then
											color = tailwind.blue[500]
										end

										return {
											_global = {
												Stroke = color,
											},
										}
									end)

									return contextMenu(
										button({
											Color = "gray",
											Variant = "solid",
											AppearanceOverride = appearanceOverride,
											LayoutOrder = index,
											Size = UDim2.new(1, -4, 1, -4), -- -4 for padding
											AutomaticSize = Enum.AutomaticSize.None,
											Position = UDim2.new(0, 2, 0, 2), -- +2 to center
											OnClick = function()
												if isCtrlHeld:get() then
													local newSelectedIndices = selectedIndices:get()
													newSelectedIndices[index] = not newSelectedIndices[index] or nil
													selectedIndices:set(newSelectedIndices)
												elseif isShiftHeld:get() then
													local newSelectedIndices = selectedIndices:get()
													local lastSelectedIndex = index

													for i, isSelected in newSelectedIndices do
														if isSelected then
															lastSelectedIndex = i
														end
													end

													if lastSelectedIndex then
														for i = math.min(index, lastSelectedIndex), math.max(index, lastSelectedIndex) do
															newSelectedIndices[i] = true
														end
													end

													selectedIndices:set(newSelectedIndices)
												elseif selectedIndices:get()[index] then
													selectedIndices:set({})
												else
													if item.id then
														-- texture
														if props.Value and props.IsSelectingImage then
															local flipbookLayout = item.flipbookLayout
																	and "Grid" .. item.flipbookLayout
																or "None"
															props.Value:set(`{item.id},{flipbookLayout}`)
														end
													else
														-- folder
														local oldPath = table.clone(currentPath:get())
														table.insert(oldPath, item.name)

														currentPath:set(oldPath)
													end
												end
											end,
											Content = {
												New("UIListLayout")({
													FillDirection = Enum.FillDirection.Vertical,
													HorizontalAlignment = Enum.HorizontalAlignment.Center,
													Padding = UDim.new(0, 4),
													SortOrder = Enum.SortOrder.LayoutOrder,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												}),
												item.id and textureImage({
													Image = item.id,
													FlipbookMode = item.flipbookLayout,
													Size = UDim2.new(0, 48, 0, 48),
													[Children] = {
														New("UICorner")({
															CornerRadius = UDim.new(0, 4),
														}),
													},
												}) or icon({
													Icon = {
														Name = "folder",
														Size = 48,
													},
													Color = useColor("Title", true),
												}),
												text({
													Appearance = useColor("Title", true),
													Text = {
														Label = item.name,
														Font = theme.global.font,
														TextSize = 14,
													},
													Size = UDim2.new(1, 0, 1, -56),
													TextWrapped = true,
													ClipsDescendants = true,
												}),
											},
										}),
										{
											Color = "gray",
											Variant = "default",
											Enabled = true,
											Visible = isThisContextMenuVisible,
											VisibleLogic = customVisibleLogic,
											Options = {
												options,
											},
										}
									)
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	if not props.IsSelectingImage then
		awaitLayer(component, function(layer)
			local inputFrame = layer.contentFrame

			table.insert(
				connections,
				inputFrame.InputBegan:Connect(function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.Keyboard then
						if
							inputObject.KeyCode == Enum.KeyCode.LeftControl
							or inputObject.KeyCode == Enum.KeyCode.RightControl
						then
							isCtrlHeld:set(true)
						elseif
							inputObject.KeyCode == Enum.KeyCode.LeftShift
							or inputObject.KeyCode == Enum.KeyCode.RightShift
						then
							isShiftHeld:set(true)
						end
					end
				end)
			)

			table.insert(
				connections,
				inputFrame.InputEnded:Connect(function(inputObject)
					if inputObject.UserInputType == Enum.UserInputType.Keyboard then
						if
							inputObject.KeyCode == Enum.KeyCode.LeftControl
							or inputObject.KeyCode == Enum.KeyCode.RightControl
						then
							isCtrlHeld:set(false)
						elseif
							inputObject.KeyCode == Enum.KeyCode.LeftShift
							or inputObject.KeyCode == Enum.KeyCode.RightShift
						then
							isShiftHeld:set(false)
						end
					end
				end)
			)
		end)
	end

	return component
end

return editor
