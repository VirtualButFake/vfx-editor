local Studio = settings().Studio

local themeFramework = require("@packages/themeFramework")
local tailwind = require("@packages/tailwind")
local fusion = require("@packages/fusion")
local Value = fusion.Value

local globals = {
	font = Font.fromEnum(Enum.Font.SourceSans),
	isDark = Value(false),
	background = Value(Color3.fromRGB(255, 255, 255)),
}

local theme = themeFramework.new(script.components, function(_, themeName) 
    local isDark = themeName == "Dark"
    local background = isDark and tailwind.neutral[900] or tailwind.neutral[100]
    
    globals.isDark:set(isDark)
    globals.background:set(background)
end)

Studio.ThemeChanged:Connect(function(studioTheme: StudioTheme)
	theme:load(theme:build(studioTheme.Name))
end)

theme:load(theme:build(Studio.Theme.Name))

-- this is suboptimal, but types refused to work if i did it the other way around
return setmetatable(theme, {
	__index = function(_, key)
		if key == "global" then
			return globals
		end

		return themeFramework[key]
	end,
}) :: themeFramework.themeFramework & { global: {
	font: Font,
	isDark: fusion.Value<boolean>,
    background: fusion.Value<Color3>,
} }
