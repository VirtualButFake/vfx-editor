local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local text = fusionComponents.base.text
local button = fusionComponents.common.button
local frame = fusionComponents.base.frame
local scrollFrame = fusionComponents.common.scrollingFrame

local theme = require("@src/theme")

local treeButton = require("../treeButton")

local classDataHandler = require("@src/lib/classDataHandler")

type texture = {
	name: string,
	id: string,
	flipbookLayout: nil | "2x2" | "4x4" | "8x8",
}

export type textureList = {
	name: string,
	content: { texture | textureList },
}

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

local function deepCopy<T>(t: T & {}): T
	local copy = {}

	for k, v in t :: { any } do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end

	return copy :: any
end

local function concatMultilineString(...: string)
	return table.concat({ ... }, "\n")
end

type props = {
	useColor: theme.useColorFunction,
	BaseTextures: { textureList },
	Path: { string },
	OnConfirm: (textures: { textureList }) -> (),
	OnClose: () -> (),
}

local function importInstancesModal(props: props)
	local operationHandled = false
	local selectedItems = Value(Selection:Get())

	local visualizedTextures = Value({}) -- same as textures, but the new textures are visualized here

	local currentTextures = Computed(function()
		local textures = deepCopy(props.BaseTextures)
		local visualizationTextures = deepCopy(textures)

		--[[

            If it is an instance that has properties, and one of those is Texture, then add it to the list
            If the item is a folder, nest it's children
            If the instance name is it's classname, use the parent name instead

        ]]

		local function insertIntoTable(t, content)
			for _, v in content do
				-- if t contains an item whose name is the item that we're trying to insert, we need to add a suffix of (x) to the name
				local newName = v.name
				local i = 1

				while true do
					local found = false

					for _, item in t do
						if item.name == newName then
							found = true
							break
						end
					end

					if not found then
						break
					end

					i = i + 1
					newName = v.name .. " (" .. i .. ")"
				end

				v.name = newName

				table.insert(t, v)
			end
		end

		local function iterateChildren(children: { Instance }): { texture | textureList }
			local result: { texture | textureList } = {}
			local visualizationResult: { texture | textureList } = {}

			for _, child in children do
				local categories = classDataHandler.getProperties(child)
				local hasInserted = false

				if categories then
					for _, category in categories do
						local properties = category.properties and category.properties or { category }

						for _, property in properties do
							if property.name == "Texture" then
								local name = child.Name

								if name == child.ClassName then
									name = child.Parent.Name
								end

								name = name:gsub("[^%w%s%-()]", "")

								table.insert(result, {
									name = name,
									id = child.Texture,
									flipbookLayout = child:IsA("ParticleEmitter") and child.FlipbookLayout.Name:split(
										"Grid"
									)[2] or nil,
								})

								table.insert(visualizationResult, {
									name = name,
									content = {},
									isItem = true,
									icon = theme.getClassIcon(child.ClassName):get(),
								})

								hasInserted = true
							end
						end
					end
				end

				-- if nothing has been found yet, then iterate through the children
				if not hasInserted then
					if child:IsA("Folder") then
						local data, visualizationData = iterateChildren(child:GetChildren())

						if #data > 0 then
							table.insert(result, {
								name = child.Name,
								content = data,
							})

							table.insert(visualizationResult, {
								name = child.Name,
								content = visualizationData,
							})
						end
					else
						local data, visualizationData = iterateChildren(child:GetChildren())

						if #data > 0 then
							insertIntoTable(result, data)
							insertIntoTable(visualizationResult, visualizationData)
						end
					end
				end
			end

			return result, visualizationResult
		end

		local targetTable = traverseTextureList(textures, props.Path)
		local targetVisualizationTable = traverseTextureList(visualizationTextures, props.Path)

		local newContent, visualizationContent = iterateChildren(selectedItems:get())

		if #newContent > 0 then
			if targetTable.content then
				insertIntoTable(targetTable.content, newContent)
				insertIntoTable(targetVisualizationTable, visualizationContent)
			else
				insertIntoTable(targetTable, newContent)
				insertIntoTable(targetVisualizationTable, visualizationContent)
			end
		end

		visualizedTextures:set(traverseTextureList(visualizationTextures, props.Path))
		return textures
	end)

	local isConfirmDisabled = Computed(function()
		-- compare basetextures with currentTextures
		-- if they match, then disable the confirm button
		-- they are both tables however, so compare their contents recursively
		local function compareTables(a, b)
			if type(a) ~= type(b) then
				return false
			end
			if type(a) ~= "table" then
				return a == b
			end
			for k, v in a do
				if not compareTables(v, b[k]) then
					return false
				end
			end
			return true
		end

		return compareTables(currentTextures:get(), props.BaseTextures)
	end)

	if props.Path[1] == "" then
		props.Path[1] = "Home"
	end

	return New("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 0, 0),
		[Cleanup] = {
			Selection.SelectionChanged:Connect(function()
				selectedItems:set(Selection:Get())
			end),
		},
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
							Label = "Import from Selection",
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
			text({
				Appearance = props.useColor("Description", true),
				Text = {
					Label = concatMultilineString(
						"This feature attempts to import instances that are selected in the explorer into the texture picker.",
						"Please note that this feature is experimental and may not work as expected.",
						"\n<b>Double-check the imported textures before confirming.</b>"
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
			frame({
				Appearance = props.useColor("LighterBackground", true),
				Stroke = props.useColor("Line", true),
				Size = UDim2.new(0, 200, 0, 200),
				Content = {
					New("UIPadding")({
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 4),
					}),
					scrollFrame({
						Content = {
							New("UIPadding")({
								PaddingRight = UDim.new(0, 4),
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
								Name = props.Path[#props.Path],
								CurrentPath = Value(props.Path),
								Content = visualizedTextures,
								Path = table.clone(props.Path),
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
				ButtonText = "Import Items",
				AutomaticSize = Enum.AutomaticSize.XY,
				Disabled = isConfirmDisabled,
				OnClick = function()
					if operationHandled then
						return
					end

					operationHandled = true

					props.OnConfirm(currentTextures:get())
				end,
			}),
		},
	})
end

return importInstancesModal
