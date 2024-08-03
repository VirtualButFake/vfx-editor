local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Value = fusion.Value

local appTopbar = require("@src/components/appTopbar")

return {
	summary = "The app topbar, filled with dummy info",
	controls = {
		Height = 32,
		Width = 350,
	},
	story = storyBase(function(parent)
		local part = Instance.new("Part")
		part.Parent = game:GetService("CoreGui")

		local function cloneWithParent(instance)
			local clone = instance:Clone()
			clone.Parent = instance.Parent
			return clone
		end

		local instances = Value({
			cloneWithParent(part),
			cloneWithParent(part),
			cloneWithParent(part),
			cloneWithParent(part),
		})

		local content = New("Frame")({
			BackgroundTransparency = 1,
			Parent = parent,
			Size = UDim2.new(1, 0, 1, 0),
			[Children] = {
				appTopbar({
					Items = instances,
					SelectedInstance = Value(instances:get()[1]),
					SharedContextMenuState = Value(false),
				}),
			},
		})

		content.Parent = parent

		return function()
			content:Destroy()

			for _, instance in (instances:get()) do
				instance:Destroy()
			end

			part:Destroy()
		end
	end),
}
