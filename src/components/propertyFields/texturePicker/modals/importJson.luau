local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local text = studioComponents.base.text
local button = studioComponents.common.button
local frame = studioComponents.base.frame

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local theme = require("@src/theme")

local treeButton = require("../treeButton")
local modalOptionWrapper = require("@components/modalOptionWrapper")
local inputPropertyField = require("@components/propertyFields/input")
local scrollFrame = require("@components/scrollingFrame")

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

	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end

	return copy :: any
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
	local inputValue = Value("")

	local visualizedTextures = Value({}) -- same as textures, but the new textures are visualized here

	local currentTextures = Computed(function()
		local textures = deepCopy(props.BaseTextures)
		local visualizationTextures = deepCopy(textures)

		local function insertIntoTable(t, content: { textureList | texture })
			for _, v in ipairs(content) do
				-- if t contains an item whose name is the item that we're trying to insert, we need to add a suffix of (x) to the name
				local newName = v.name
				local i = 1

				while true do
					local found = false

					for _, item in ipairs(t) do
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

		local targetTable = traverseTextureList(textures, props.Path)
		local targetvisualizationTable = traverseTextureList(visualizationTextures, props.Path)

		-- parse json
		local succ, parsed = pcall(function()
			return HttpService:JSONDecode(inputValue:get())
		end)

		if succ and typeof(parsed) == "table" then
			-- this is an array of textures or texture lists.
			-- we need to insert them into the target table
			insertIntoTable(targetTable, parsed)

			-- for visualization, we need to tag all texture ITEMS (so the ones that have .id) with .isItem = true. this should be recursive
			local function tagItems(content)
				for _, v in ipairs(content) do
					if v.id then
						v.isItem = true
					else
						tagItems(v.content)
					end
				end
			end

			tagItems(parsed)

			-- now we need to insert the visualization textures into the visualization table
			insertIntoTable(targetvisualizationTable, parsed)
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
							Label = "Import from JSON",
							Font = Font.new(use(theme.global.font).Family, Enum.FontWeight.SemiBold),
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
					Label = Computed(function()
						local baseString =
							"Insert JSON in the text box below. You can see the new file structure below the text box."

						if isConfirmDisabled:get() and #inputValue:get() > 0 then
							return baseString
								.. ' \n\n<font color="#ef4444" weight="semibold">The JSON is invalid, or the file structure is unchanged.</font>'
						end

						return baseString .. "\n\nMake sure the changes are correct before importing."
					end),
					TextSize = 14,
					Font = theme.global.font,
				},
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
			}),
			modalOptionWrapper({
				OptionName = "JSON",
				Content = inputPropertyField({
					Value = inputValue,
					LayoutOrder = 1,
				}),
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
								Name = props.Path[#props.Path],
								CurrentPath = Value(props.Path),
								Content = visualizedTextures,
								Path = props.Path,
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
