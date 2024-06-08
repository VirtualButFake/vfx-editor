local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Computed = fusion.Computed

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

type props = {
	color: fusion.CanBeState<Color3>,
	spacingX: fusion.CanBeState<number>,
	spacingY: fusion.CanBeState<number>,
}

local function grid(props: props)
	return New("Frame")({
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = -1,
		[Children] = Computed(function()
			local children = {}

			for i = 1, 1 / use(props.spacingX) - 1 do
				table.insert(
					children,
					New("Frame")({
						BackgroundColor3 = props.color,
						Position = UDim2.new(use(props.spacingX) * i, 0, 0, 0),
						Size = UDim2.new(0, 1, 1, 0),
					})
				)
			end

			for i = 1, 1 / use(props.spacingY) - 1 do
				table.insert(
					children,
					New("Frame")({
						BackgroundColor3 = props.color,
						Position = UDim2.new(0, 0, use(props.spacingY) * i, 0),
						Size = UDim2.new(1, 0, 0, 1),
					})
				)
			end

			return children
		end),
	})
end

return grid
