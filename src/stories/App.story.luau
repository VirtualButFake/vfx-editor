local fusionComponents = require("@packages/fusionComponents")
local storyBase = fusionComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New
local Clean = fusion.cleanup

local Value = fusion.Value

local theme = require("@src/theme")
local historyHandler = require("@src/lib/historyHandler")

local generateInstance = require("./generateInstance")

local app = require("@src/components/app")

return {
	summary = "A full representation of the plugin",
	controls = {
		Height = 550,
		Width = 350,
	},
	story = function(prnt, props)
		if props.controls.Height == "" or props.controls.Width == "" then
			props.controls.Height = 550
			props.controls.Width = 350
		end

		return storyBase(function(parent)
			local backgroundColor = theme.global.isDark:get() and Color3.fromRGB(46, 46, 46)
				or Color3.fromRGB(255, 255, 255)

			local instances = Value({
				historyHandler("Create story instance", generateInstance),
			})

			local background = New("Frame")({
				BackgroundColor3 = backgroundColor,
				Parent = parent,
				Size = UDim2.new(1, 0, 1, 0),
				[Children] = {
					app({
						Items = instances,
					}),
				},
			})

			background.Parent = parent

			return function()
				background:Destroy()
				Clean(instances:get())
			end
		end)(prnt, props)
	end,
}
