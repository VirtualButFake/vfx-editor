local tailwind = require("@packages/tailwind")

return function(themeName: string)
	return {
		Base = {
			ScrollBar = themeName == "Dark" and tailwind.neutral[700] or tailwind.neutral[300],
			ScrollBarBackground = themeName == "Dark" and tailwind.neutral[785] or tailwind.neutral[50],
			Stroke = themeName == "Dark" and tailwind.neutral[700] or tailwind.neutral[300],
		},
	}
end
