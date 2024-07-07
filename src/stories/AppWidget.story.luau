local fusion = require("@packages/fusion")
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
	story = function(prnt)
        local instances = Value({
            historyHandler("Create story instance", generateInstance),
        })

		local component = app({
            Items = instances
        })

        component.Parent = prnt

        return function()
            component:Destroy()
            Clean(instances:get())
            theme.destroy()
        end
	end,
}
