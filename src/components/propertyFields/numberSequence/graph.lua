local fusion = require("@packages/fusion")

local Children = fusion.Children
local Cleanup = fusion.Cleanup
local New = fusion.New
local Ref = fusion.Ref

local Computed = fusion.Computed
local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local use = fusionUtils.use

local graph = require("@src/lib/graph")

type graphKeypoint = {
	index: fusion.CanBeState<number>,
	value: fusion.CanBeState<number>,
	envelope: fusion.CanBeState<number>,
}

type props = {
	points: fusion.CanBeState<{ graphKeypoint }>,
	bounds: {
		x: {
			min: number,
			max: number,
		},
		y: {
			min: number,
			max: number,
		},
	},
	lineColor: Color3,
	envelopeColor: Color3,
	pxScale: number, -- thickness
	resolution: number,
	cornerRadius: number?,
}

local function graphComponent(props: props)
	local graphKeypoints = Computed(function()
		local points = use(props.points)
		local dereferencedKeypoints = {}

		for _, point in ipairs(points) do
			table.insert(dereferencedKeypoints, {
				index = use(point.index),
				value = use(point.value),
				envelope = use(point.envelope),
			})
		end

		return dereferencedKeypoints
	end)

	local oldGraphKeypoints = graphKeypoints:get(false)
	local graphContainer = Value(nil)
	local graphHandler = graph.new(
		oldGraphKeypoints,
		props.bounds,
		props.lineColor,
		props.envelopeColor,
		props.pxScale,
		props.cornerRadius
	)

	return New("Frame")({
		Name = "GraphContainer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		[Ref] = graphContainer,
        [Cleanup] = {
            function()
                graphHandler:destroy()
            end,
        },
		[Children] = {
			Computed(function()
				local newKeypoints = graphKeypoints:get()

				if graphContainer:get() == nil then
					return
				end

				if not graphHandler._redrawConnection then
					graphHandler:render(graphContainer:get(), props.resolution)
				else
					graphHandler.points = newKeypoints
					graphHandler:_updateRender(graphContainer:get(), props.resolution)
				end
			end),
		},
	})
end

return graphComponent
