local StudioService = game:GetService("StudioService")
local Studio = settings().Studio

local themeFramework = require("@packages/themeFramework")
local fusion = require("@packages/fusion")
local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

export type color = themeFramework.color
export type colorTable = themeFramework.colorTable
export type useColorFunction = themeFramework.useColorFunction

local globals = {
	font = Font.fromEnum(Enum.Font.SourceSans),
	isDark = Value(false),
	background = Value(Color3.fromRGB(250, 250, 250)),
}

local theme = themeFramework.new(script.components, function(self, themeName)
	local isDark = themeName == "Dark"
	local background = isDark and Color3.fromRGB(46, 46, 46) or Color3.fromRGB(250, 250, 250) -- roblox default backgrounds

	globals.isDark:set(isDark)
	globals.background:set(background)

	self:setFallback(background)
end)

local currentTheme = Value(Studio.Theme.Name)

local connections = {
	Studio.ThemeChanged:Connect(function()
		if theme == nil then
			return
		end

		theme:load(theme:build(Studio.Theme.Name))
		currentTheme:set(Studio.Theme.Name)
	end),
	script.Destroying:Connect(function()
		theme.destroy()
	end),
}

theme:load(theme:build(Studio.Theme.Name))

local wasDestroyed = false

-- this is suboptimal, but types refused to work if i did it the other way around
return setmetatable({
	global = globals,
	getClassIcon = function(className)
		return Computed(function()
			currentTheme:get() -- register dependency so it updates when the theme changes. the overhead isn't significant enough to explore other solutions
			return StudioService:GetClassIcon(className)
		end)
	end,
	destroy = function()
		if not wasDestroyed then
			wasDestroyed = true
		end

		Clean(connections)
		theme = nil
	end,
}, {
	__index = theme,
}) :: themeFramework.themeFramework & {
	global: {
		font: Font,
		isDark: fusion.Value<boolean>,
		background: fusion.Value<Color3>,
	},
	destroy: () -> (),
	getClassIcon: (
		className: string
	) -> fusion.Computed<{
		Image: string,
		ImageRectSize: Vector2,
		ImageRectOffset: Vector2,
	}>,
}
