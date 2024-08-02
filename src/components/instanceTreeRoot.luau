local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local Hydrate = fusion.Hydrate
local New = fusion.New

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

local classDataHandler = require("@src/lib/classDataHandler")

local instanceTreeItem = require("@src/components/instanceTreeItem")

type childMap = {
	[Instance]: {
		[Instance]: childMap,
	},
}

type props = {
	RootInstance: Instance,
	Query: fusion.Value<string>,
	ChildrenReplacement: fusion.Value<{ Instance }>,
	SearchMode: fusion.Value<{ string }>,
	MaxDepth: number,
	IsSelfSelected: fusion.Value<boolean>,
	SharedContextMenuState: fusion.Value<boolean | fusion.Value<boolean>>,
	Events: instanceTreeItem.events,
}

export type events = instanceTreeItem.events

local ALLOWED_CLASSNAMES = {
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Attachment",
}

local function instanceTree(props: props)
	-- recursively iterate through the instance and its children to build the instance map
	-- cascading lines are lines that "cascade" through children of an instance, for example for parents. the index is the depth, the value is an array of lines
	-- both instanceMap as a variable and the children of a parent should be populated
	local function buildChildMap(rootInstance: Instance, parent: childMap): nil
		local children = rootInstance:GetChildren()

		for _, child in children do
			if not table.find(ALLOWED_CLASSNAMES, child.ClassName) then
				continue
			end

			if not parent[rootInstance] then
				parent[rootInstance] = {}
			end

			parent[rootInstance][child] = {}
			buildChildMap(child, parent[rootInstance])
		end

		return nil
	end

	local instanceMapConnections = {}
	local mapChanged = Value(false)

	local function buildInstanceMap(
		instance: Instance,
		depth: number,
		parent: { instanceTreeItem.instanceMapEntry },
		childrenList: { Instance },
		childMap: childMap,
		cascadingLines: { [number]: { instanceTreeItem.line } }
	): nil
		local properties = classDataHandler.getProperties(instance) or {}
		local children = instance:GetChildren()
		local newChildren = table.clone(children)
		local queryFilteredChildren = {}

		if depth < props.MaxDepth then
			for i, child in children do
				if not table.find(ALLOWED_CLASSNAMES, child.ClassName) then
					table.remove(newChildren, i)
				elseif props.SearchMode:get()[1] == "instance" and props.Query:get() ~= "" then
					-- build queryfilteredchildren list. how this works is as simple:
					-- iterate through the children of the instance. if the instance name or any of its descendants match the query, add it to the list
					if child.Name:lower():find(props.Query:get():lower()) then
						table.insert(queryFilteredChildren, child)
					else
						-- we recursively iterate through the child map to find any descendants that match the query
						local function findInChildMap(map: childMap): nil
							for childInstance, mapContents in map do
								if childInstance.Name:lower():find(props.Query:get():lower()) then
									if not table.find(queryFilteredChildren, child) then
										table.insert(queryFilteredChildren, child)
									end

									return
								end

								findInChildMap(mapContents)
							end

							return nil
						end

						findInChildMap(childMap[instance][child])
					end
				elseif props.SearchMode:get()[1] == "properties" and props.Query:get() ~= "" then
					-- search our own properties
					local foundMatch = false
					local childProperties = classDataHandler.getProperties(child)

					if childProperties then
						for _, category in childProperties do
							local foundValidProperty = false
							local propertyList = category.properties or { category }

							for _, property in propertyList do
								if property.name:lower():find(props.Query:get():lower()) then
									if not table.find(queryFilteredChildren, child) then
										table.insert(queryFilteredChildren, child)
									end

									foundValidProperty = true
									foundMatch = true
									break
								end
							end

							if foundValidProperty then
								break
							end
						end

						if foundMatch then
							continue
						end
					end

					local function findInChildMap(map: childMap): nil
						for childInstance, mapContents in map do
							local childInstanceProperties = classDataHandler.getProperties(childInstance)

							if childInstanceProperties == nil then
								continue
							end

							for _, category in childInstanceProperties do
								local foundValidProperty = false
								local propertyList = category.properties or { category }

								for _, property in propertyList do
									if property.name:lower():find(props.Query:get():lower()) then
										if not table.find(queryFilteredChildren, child) then
											if not table.find(queryFilteredChildren, child) then
												table.insert(queryFilteredChildren, child)
											end

											foundValidProperty = true
											break
										end
									end
								end

								if foundValidProperty then
									break
								end
							end

							findInChildMap(mapContents)
						end

						return nil
					end

					findInChildMap(childMap[instance][child])
				else
					table.insert(queryFilteredChildren, child)
				end
			end
		end

		local linesStart: { instanceTreeItem.line } = {}

		local selfIndex = table.find(childrenList, instance)

		if selfIndex or depth == 0 then
			local isLast = selfIndex == #childrenList
			local isFirst = selfIndex == 1

			local lines: { instanceTreeItem.line } = {}

			if not isLast then
				table.insert(lines, isFirst and "StartVertical" or "Vertical")
			else
				table.insert(lines, "Horizontal")
				table.insert(lines, "HalfVertical")
			end

			if not isLast and not isFirst then
				table.insert(lines, "Horizontal")
			end

			if isFirst then
				table.insert(lines, "Horizontal")
				table.insert(lines, isLast and "HalfVertical" or "Vertical")
			end

			-- remove duplicates
			local seen = {}

			for i = #lines, 1, -1 do
				if seen[lines[i]] then
					table.remove(lines, i)
				else
					seen[lines[i]] = true
				end
			end

			linesStart = lines

			local previousLines = table.clone(cascadingLines)

			if #properties > 0 and #queryFilteredChildren > 0 then
				previousLines[depth + 1] = { "StartVertical" }
			end

			if not isLast and (depth ~= 0 or #queryFilteredChildren > 0) then
				previousLines[depth] = { "Vertical" }
			else
				previousLines[depth] = nil
				previousLines[depth - 1] = nil
			end

			cascadingLines = previousLines
		end

		local entry: instanceTreeItem.instanceMapEntry = {
			instance = instance,
			children = {},
			properties = properties,
			linesStart = linesStart,
			linesCascading = cascadingLines,
		}

		table.insert(parent, entry)

		if childMap and childMap[instance] then
			for _, child in children do
				buildInstanceMap(
					child,
					depth + 1,
					entry.children,
					queryFilteredChildren,
					childMap[instance],
					cascadingLines
				)

				if table.find(queryFilteredChildren, child) then
					table.insert(
						instanceMapConnections,
						child:GetPropertyChangedSignal("Parent"):Connect(function()
							mapChanged:set(true, true)
						end)
					)

					table.insert(
						instanceMapConnections,
						child.DescendantAdded:Connect(function()
							mapChanged:set(true, true)
						end)
					)

					table.insert(
						instanceMapConnections,
						child.DescendantRemoving:Connect(function()
							mapChanged:set(true, true)
						end)
					)
				end
			end
		end

		return nil
	end

	local instanceMap: fusion.Computed<instanceTreeItem.instanceMapEntry> = Computed(function()
		if mapChanged:get() then
			mapChanged:set(false)
		end

		if props.ChildrenReplacement then
			print("Found replacement", props.ChildrenReplacement)
			local maps = {}

			for _, child in props.ChildrenReplacement:get() do
				local map = {}
				local childMap = {}

				buildChildMap(child, childMap)
				buildInstanceMap(child, 0, map, {}, childMap, {})

				table.insert(maps, map[1])
			end

			return maps :: instanceTreeItem.instanceMapEntry
		else
			local map = {}
			local childMap = {}

			Clean(instanceMapConnections)
			buildChildMap(props.RootInstance, childMap)
			buildInstanceMap(props.RootInstance, 0, map, {}, childMap, {})

			return map[1]
		end
	end)

	local component = New("Frame")({
		Name = "InstanceTreeRoot",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		[Cleanup] = {
			props.ChildrenReplacement == nil and props.RootInstance.DescendantAdded:Connect(function()
				mapChanged:set(true, true)
			end),
			props.ChildrenReplacement == nil and props.RootInstance.DescendantRemoving:Connect(function()
				mapChanged:set(true, true)
			end),
			props.Events,
		},
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Computed(function()
				if props.ChildrenReplacement == nil then
					return instanceTreeItem({
						LayoutOrder = 0,
						Instance = props.RootInstance,
						Query = props.Query,
						Depth = 0,
						Events = props.Events,
						InstanceMap = instanceMap,
						IsRootInstanceSelected = props.IsSelfSelected,
						MaxDepth = props.MaxDepth,
						SearchMode = props.SearchMode,
						SharedState = {
							OpenedContextMenu = props.SharedContextMenuState,
							SelectedProperty = Value({}),
							CopiedValue = Value(),
						},
					})
				end

				local instanceTreeItemList = {}

				local sharedState = {
					OpenedContextMenu = props.SharedContextMenuState,
					SelectedProperty = Value({}),
					CopiedValue = Value(),
				}

				local usedMaps = instanceMap:get(false)

				for i, instance in props.ChildrenReplacement:get() do
					table.insert(
						instanceTreeItemList,
						instanceTreeItem({
							LayoutOrder = 0,
							Instance = instance,
							SearchMode = props.SearchMode,
							Depth = 0,
							Events = props.Events,
							HideMainContent = #props.ChildrenReplacement:get() == 1,
							InstanceMap = Value(usedMaps[i]),
							IsRootInstanceSelected = props.IsSelfSelected,
							MaxDepth = props.MaxDepth,
							Query = props.Query,
							SharedState = sharedState,
						})
					)
				end

				return instanceTreeItemList
			end, Clean),
		},
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "Frame"))
end

return instanceTree
