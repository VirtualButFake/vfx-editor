local PluginDebugService = game:GetService("PluginDebugService")

local settingsManager = {}

local plugin = script:FindFirstAncestorWhichIsA("Plugin") or PluginDebugService:FindFirstChild("plugin") :: Plugin?
