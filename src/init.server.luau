local Selection = game:GetService("Selection")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Value = fusion.Value

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

local app = require("@components/app")

--[[
local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("VFXEditor")
app({ Items = Value({require("@src/stories/generateInstance")()}) }).Parent = screenGui.Frame

leaving this code in here in case I need to find memory leaks again
]]

local toolbar = plugin:CreateToolbar("VFX Editor")
local button =
	toolbar:CreateButton("Toggle VFX Editor", "Open/close the editor", "rbxassetid://18834248930", "VFX Editor")
button.ClickableWhenViewportHidden = true

local widget

button.Click:Connect(function()
	if widget == nil then
		widget = plugin:CreateDockWidgetPluginGui(
			"VFXEditor",
			DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 350, 550, 150, 150)
		)

		widget.Title = "VFX Editor"
		widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local layer = topLayerProvider.new(New("Frame")({
			BackgroundTransparency = 1,
			Parent = widget,
			Size = UDim2.new(1, 0, 1, 0),
			[Children] = {
				app({ Items = Value(Selection:Get()) }),
			},
		}))

		layer.Parent = widget
	else
		widget.Enabled = not widget.Enabled
	end
end)
