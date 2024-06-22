local tailwind = require("@packages/tailwind")

return function(themeName: string)
	return {
		Base = {
			Title = themeName == "Dark" and tailwind.neutral[100] or tailwind.neutral[900],
			Description = themeName == "Dark" and tailwind.neutral[200] or tailwind.neutral[700],
			Line = themeName == "Dark" and tailwind.neutral[750] or tailwind.neutral[200],
			SidebarBackground = {
				color = themeName == "Dark" and tailwind.neutral[800] or tailwind.white,
				transparency = 0,
				shadow = 2,
			},
			LighterBackground = {
				color = themeName == "Dark" and tailwind.neutral[825] or tailwind.white,
				transparency = 0,
				shadow = 2,
			},
		},
	}
end
