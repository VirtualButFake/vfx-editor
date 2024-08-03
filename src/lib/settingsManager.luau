-- primarily exists to wrap around Get/SetSetting so we don't have to get a new plugin each time
-- and also turns its values into reactive values
local PluginDebugService = game:GetService("PluginDebugService")

local settingsManager = {}

local fusion = require("@packages/fusion")
local Value = fusion.Value

local plugin = script:FindFirstAncestorWhichIsA("Plugin") or PluginDebugService:FindFirstChild("plugin") :: Plugin?

local SETTING_PREFIX = "vfxEditor_"

settingsManager._localStorage = {}

function settingsManager.get<T>(key: string): T?
	local value = plugin:GetSetting(SETTING_PREFIX .. key)

	if settingsManager._localStorage[key] == nil and value ~= nil then
		settingsManager._localStorage[key] = Value(value)
	end

	return value
end

function settingsManager.getReactive<T>(key: string): fusion.Value<T>?
	local value = settingsManager.get(key)

	if value == nil and settingsManager._localStorage[key] == nil then
		return nil
	end

	return settingsManager._localStorage[key]
end

function settingsManager.set(key: string, value: any)
	plugin:SetSetting(SETTING_PREFIX .. key, value)

	if settingsManager._localStorage[key] then
		settingsManager._localStorage[key]:set(value, true)
	else
		settingsManager._localStorage[key] = Value(value)
	end
end

function settingsManager.getReactiveWithFallback(key: string, default: any)
	local value = settingsManager.getReactive(key)

	if value == nil then
		settingsManager.set(key, default)
		return settingsManager.getReactive(key)
	end

	return value
end

return settingsManager
