local tailwind = require("@packages/tailwind")

return function(themeName: string)
	return {
		Base = {
			Title = themeName == "Dark" and tailwind.neutral[100] or tailwind.neutral[900],
			Description = themeName == "Dark" and tailwind.neutral[200] or tailwind.neutral[700],
			Line = themeName == "Dark" and tailwind.neutral[750] or tailwind.neutral[200],
			Dot = themeName == "Dark" and tailwind.neutral[400] or tailwind.neutral[700],
			SelectedDot = themeName == "Dark" and tailwind.red[400] or tailwind.red[500],
		},
	}
end
