local tailwind = require("@packages/tailwind")

return function(themeName: string)
	return {
		Base = {
            TopbarBackground = themeName == "Dark" and tailwind.neutral[800] or tailwind.neutral[50],
			TreeBackground = {
				color = themeName == "Dark" and tailwind.neutral[800] or tailwind.neutral[50],
				transparency = 0,
				shadow = 4,
			},
			Stroke = themeName == "Dark" and tailwind.neutral[700] or tailwind.neutral[300],
		},
	}
end
