local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Value = fusion.Value

local tailwind = require("@packages/tailwind")
local theme = require("@src/theme")

local appTopbar = require("@src/components/appTopbar")

return {
	summary = "The app topbar, filled with dummy info",
	controls = {
		Height = 28,
		Width = 350,
	},
	story = storyBase(function(parent)
		local instances = Value({
			Instance.new("Part"),
			Instance.new("Part"),
			Instance.new("Part"),
			Instance.new("Part"),
			Instance.new("Part"),
		})

		local content = New("Frame")({
            BackgroundTransparency = 1,
			Parent = parent,
			Size = UDim2.new(1, 0, 1, 0),
			[Children] = {
				appTopbar({
					Items = instances,
					SelectedInstance = Value(instances[1]),
				}),
			},
		})

		content.Parent = parent

		return function()
			content:Destroy()
		end
	end),
}
