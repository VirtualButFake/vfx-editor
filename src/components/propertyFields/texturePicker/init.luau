local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup

local Clean = fusion.cleanup
local Computed = fusion.Computed
local Value = fusion.Value

local fusionComponents = require("@packages/fusionComponents")
local button = fusionComponents.common.button

local fusionUtils = require("@packages/fusionUtils")
local topLayerProvider = fusionUtils.topLayerProvider

local widget = require("@components/widget")
local editor = require("./editor")

local settingsManager = require("@src/lib/settingsManager")

type props = {
	Instance: Instance,
	PropertyName: string,
	Value: fusion.Value<{
		Texture: string,
		FlipbookLayout: Enum.ParticleFlipbookLayout,
	}>,
	LayoutOrder: number,
}

local function texturePickerPropertyField(props: props)
	local isWidgetEnabled = Value(false)
	local wasEnabled = false
	local lastReturn = nil

	local textures: fusion.Value<editor.textureList>? = settingsManager.getReactiveWithFallback("textures", {})

	local texturePath = Computed(function()
		local data = props.Value:get()
		local id = data and data:split(",")[1]

		if textures and textures:get() then
			local function iterate(textureList: editor.textureList, path: { string }): { string }?
				for key, texture in textureList do
					if texture.id == nil then
						local result = iterate(texture.content, { unpack(path), key })

						if result then
							return result
						end
					elseif texture.id == id then
						return { unpack(path), texture.name }
					end
				end

				return nil
			end

			return iterate(textures:get(), {}) or { "Home" }
		end

		return nil
	end)

	local createdWidget

	local imageButton = button({
		Color = "white",
		Variant = "solid",
		Icon = {
			Name = "image",
			Size = 16,
		},
		ButtonText = Computed(function()
			local path = texturePath:get()

			if path and path[#path] == "Home" then
				path = nil
			end

			if not props.Value:get() or props.Value:get().Texture == "" then
				return "None"
			end

			if not path then
				return "Unknown"
			end

			return path[#path]
		end),
		Padding = 2,
		Size = UDim2.new(0, 16, 0, 16),
		LayoutOrder = props.LayoutOrder,
		OnClick = function()
			if createdWidget == nil then
				createdWidget = widget({
					Name = `Texture Picker ({props.Instance}.{props.PropertyName})`,
					Id = HttpService:GenerateGUID(),
					InitialDockTo = Enum.InitialDockState.Float,
					InitialEnabled = false,
					ForceInitialEnabled = true,
					FloatingSize = Vector2.new(575, 408),
					MinimumSize = Vector2.new(400, 300),
					Enabled = isWidgetEnabled,
					[Children] = {
						Computed(function()
							local widgetEnabled = isWidgetEnabled:get()

							if widgetEnabled and not wasEnabled then
								wasEnabled = true

								lastReturn = ({
									topLayerProvider.new(editor({
										Value = props.Value,
										Instance = props.Instance,
										IsSelectingImage = true,
										Path = texturePath,
									})),
								})[1]
							end

							if not widgetEnabled then
								wasEnabled = false
							end

							return { lastReturn }
						end, Clean),
					},
				})
			end

			isWidgetEnabled:set(true)
		end,
		[Cleanup] = {
			function()
				-- https://devforum.roblox.com/t/2853087
				isWidgetEnabled:set(false)

				if createdWidget then
					createdWidget:Destroy()
				end
			end,
		},
	})

	return imageButton
end

return texturePickerPropertyField
