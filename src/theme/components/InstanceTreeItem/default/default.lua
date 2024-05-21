local tailwind = require("@packages/tailwind")

return function(themeName: string)
	return {
		Base = {
			Text = themeName == "Dark" and tailwind.neutral[100] or tailwind.neutral[900],
            ToggleButton = themeName == "Dark" and tailwind.neutral[400] or tailwind.neutral[500],
            Line = themeName == "Dark" and tailwind.neutral[750] or tailwind.neutral[200],
		},
	}
end
