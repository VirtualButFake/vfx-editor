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
local menuEntry = studioComponents.utility.menuEntry
local baseText = studioComponents.base.text
local icon = studioComponents.base.icon

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

type textureList = {
	name: string,
	content: textureList?,
}

local function tableEq(a, b)
	if #a ~= #b then
		return false
	end

	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

type props = {
	Name: string,
	CurrentPath: fusion.StateObject<string>,
	Content: fusion.CanBeState<{ textureList }>, -- no need to type it entirely, we're only interested in the folders anyways
	OnClick: ((path: { string }) -> nil)?,
	Path: { string },
	Query: fusion.Value<string>?,
	DisabledPath: { string }?,
	DisabledCascades: boolean?,
	IsSelfDisabled: boolean?,
	Icon: string?,
	IsItem: boolean?, -- the isItem tag is used to determine if the treeButton is a texture or a folder - we want to show treebuttons for textures sometimes, but not always
}

local function treeButton(props: props)
	local isDisabled = props.DisabledPath and tableEq(props.Path, props.DisabledPath) or props.IsSelfDisabled

	local subButtons = Value({})--[[ForPairs(props.Content, function(index, value)
        print("Change")
		if value.content then
			local clonedPath = table.clone(props.Path)
			table.insert(clonedPath, value.name)

			return index,
				treeButton({
					Name = value.name,
					Icon = value.icon,
					CurrentPath = props.CurrentPath,
					Content = value.content,
					OnClick = props.OnClick,
					Path = clonedPath,
					Query = props.Query,
					DisabledPath = props.DisabledPath,
					DisabledCascades = props.DisabledCascades,
					IsSelfDisabled = props.DisabledCascades and isDisabled,
					IsItem = value.isItem,
				})
		end

		return index, nil
	end, Clean)]]

	local function refreshData(content)
		local newSubButtons = {}

		for index, value in content do
			if value.content then
				local clonedPath = table.clone(props.Path)
				table.insert(clonedPath, value.name)

				newSubButtons[index] = treeButton({
					Name = value.name,
					Icon = value.icon,
					CurrentPath = props.CurrentPath,
					Content = value.content,
					OnClick = props.OnClick,
					Path = clonedPath,
					Query = props.Query,
					DisabledPath = props.DisabledPath,
					DisabledCascades = props.DisabledCascades,
					IsSelfDisabled = props.DisabledCascades and isDisabled,
					IsItem = value.isItem,
				})
			end
		end

		subButtons:set(newSubButtons)
	end

	local contentObserver
	if typeof(props.Content) == "table" and (props.Content :: any).get then
		local content = props.Content :: fusion.Value<{ textureList }>
		contentObserver = Observer(props.Content):onChange(function()
			refreshData(content:get())
		end)

		refreshData(content:get())
	else
		refreshData(props.Content)
	end

	local amountOfTextures = Computed(function()
		local count = 0
		local query = props.Query and props.Query:get():lower() or ""

		for _, value in use(props.Content) do
			if not value.content and (query == "" or value.name:lower():find(query)) or value.isItem then
				count += 1
			end
		end

		return count
	end)

	local buttonIcon = typeof(props.Icon) == "string" and {
		Image = props.Icon,
	} or props.Icon or {}

	return New("Frame")({
		Name = props.Name,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = Computed(function()
			-- iterate through ALL children to see if any of them match the query
			-- this is recursive, and also iterates through descendants
			local query = props.Query and props.Query:get():lower() or ""

			local function iterate(content: { textureList }): boolean
				for _, value in content do
					if value.name:lower():find(query) then
						return true
					end

					if value.content and iterate(value.content) then
						return true
					end
				end

				return false
			end

			return query == "" or props.Name:lower():find(query) or iterate(use(props.Content))
		end),
		[Cleanup] = {
			contentObserver,
		},
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = Computed(function()
					if next(subButtons:get()) then
						return UDim.new(0, 4)
					end

					return UDim.new(0, 0)
				end),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			New("Frame")({
				Name = "MenuEntryContainer",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0, 0),
				[Children] = {
					menuEntry({
						Option = {
							Label = props.Name,
							Color = "gray",
							Icon = props.Name == "Home" and "home" or buttonIcon.Image,
							Disabled = isDisabled,
							Slots = {
								Left = buttonIcon.Image and function(useSlotColor)
									return icon({
										Color = useSlotColor("Text", true),
										Icon = props.Name == "Home" and "home" or buttonIcon.Image,
										ImageRectSize = buttonIcon.ImageRectSize,
                                        ImageRectOffset = buttonIcon.ImageRectOffset,
									})
								end or nil,
								Center = function(useSlotColor)
									return baseText({
										Name = "Label",
										Appearance = useSlotColor("Text", true),
										Text = Computed(function()
											return `{props.Name} <font transparency="0.5">({props.IsItem ~= true and amountOfTextures:get() or "+"})</font>`
										end),
										RichText = true,
										AutomaticSize = Enum.AutomaticSize.XY,
										BackgroundTransparency = 1,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextSize = 16,
									})
								end,
							},
						},
						OnClick = function()
							if props.OnClick then
								props.OnClick(props.Path)
							end
						end,
						Selected = Computed(function()
							if props.CurrentPath:get() == "" and props.Name == "Home" then
								return true
							end

							return tableEq(props.Path, props.CurrentPath:get())
						end),
						Size = UDim2.new(1, 0, 0, 0),
					}),
				},
			}),
			New("Frame")({
				Name = "SubContent",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -12, 0, 0),
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					}),
					subButtons,
				},
			}),
		},
	})
end

return treeButton
