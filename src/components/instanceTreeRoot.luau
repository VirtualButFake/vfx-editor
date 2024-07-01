local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup
local Hydrate = fusion.Hydrate
local New = fusion.New

local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local propertyProvider = fusionUtils.propertyProvider

local getPropertiesForInstance = require("@src/lib/getPropertiesForInstance")

local instanceTreeItem = require("@src/components/instanceTreeItem")

type childMap = {
	[Instance]: {
		[Instance]: childMap,
	},
}

type props = {
	RootInstance: Instance,
	Query: fusion.Value<string>,
	SearchMode: fusion.Value<{ string }>,
	MaxDepth: number,
	OnPlusClicked: (instance: Instance) -> (),
	SharedContextMenuState: fusion.Value<boolean | fusion.Value<boolean>>,
	AddTab: (instance: Instance) -> (),
}

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

		for _, child in ipairs(children) do
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

	local function buildInstanceMap(
		instance: Instance,
		depth: number,
		parent: { instanceTreeItem.instanceMapEntry },
		childrenList: { Instance },
		childMap: childMap,
		cascadingLines: { [number]: { instanceTreeItem.line } }
	): nil
		local properties = getPropertiesForInstance(instance)
		local children = instance:GetChildren()
		local newChildren = table.clone(children)
		local queryFilteredChildren = {}

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
					local foundMatch = false

					local function findInChildMap(map: childMap): nil
						for childInstance, mapContents in pairs(map) do
							if childInstance.Name:lower():find(props.Query:get():lower()) then
								if not table.find(queryFilteredChildren, child) then
									table.insert(queryFilteredChildren, child)
								end

								foundMatch = true
								return
							end

							if not foundMatch then
								findInChildMap(mapContents)
							end
						end

                        return nil
					end

					findInChildMap(childMap[instance][child])
				end
			else
				table.insert(queryFilteredChildren, child)
			end
		end

		local linesStart: { instanceTreeItem.line } = {}

		local selfIndex = table.find(childrenList, instance)

		if selfIndex then
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

			if not isLast then
				previousLines[depth] = { "Vertical" }
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

		for _, child in ipairs(children) do
			buildInstanceMap(
				child,
				depth + 1,
				entry.children,
				queryFilteredChildren,
				childMap[instance],
				cascadingLines
			)
		end

        return nil
	end

	local mapChanged = Value(false)
	local instanceMap: fusion.Computed<{ instanceTreeItem.instanceMapEntry }> = Computed(function()
		if mapChanged:get() then
			mapChanged:set(false)
		end

		local map = {}
		local childMap = {}

		buildChildMap(props.RootInstance, childMap)
		buildInstanceMap(props.RootInstance, 0, map, {}, childMap, {})

		return map[1]
	end)

	local component = New("Frame")({
		Name = "InstanceTreeRoot",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		[Cleanup] = {
			props.RootInstance.DescendantAdded:Connect(function()
				mapChanged:set(true, true)
			end),
			props.RootInstance.DescendantRemoving:Connect(function()
				mapChanged:set(true, true)
			end),
		},
		[Children] = {
			instanceTreeItem({
				LayoutOrder = 0,
				Instance = props.RootInstance,
				Query = props.Query,
				SearchMode = props.SearchMode,
				AddTab = props.AddTab,
				Depth = 0,
				InstanceMap = instanceMap,
				MaxDepth = props.MaxDepth,
				OnPlusClicked = props.OnPlusClicked,
				OpenedContextMenu = props.SharedContextMenuState,
			}),
		},
	})

	return Hydrate(component)(propertyProvider.getPropsAndSpecialKeys(props, "Frame"))
end

return instanceTree
