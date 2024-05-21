local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local instanceTreeItem = require("@src/components/instanceTreeItem")

type props = {
	RootInstance: Instance,
	Query: fusion.CanBeState<string>,
	MaxDepth: number,
}

local function instanceTree(props: props)
	return New("Frame")({
        Name = "InstanceTreeRoot",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
		[Children] = {
			instanceTreeItem({
				Instance = props.RootInstance,
				Query = props.Query,
				Depth = 0,
				MaxDepth = props.MaxDepth,
			}),
		},
	})
end

return instanceTree
