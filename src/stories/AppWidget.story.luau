local fusion = require("@packages/fusion")

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
	story = function(prnt)
		local generatedInstance = historyHandler("Create story instance", generateInstance)

		local instances = Value({
			generatedInstance,
		})

		local component = app({
			Items = instances,
		})

		component.Parent = prnt

		return function()
			component:Destroy()
			generatedInstance:Destroy()
			theme.destroy()
		end
	end,
}
