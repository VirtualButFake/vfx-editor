local HttpService = game:GetService("HttpService")

local fusion = require("@packages/fusion")
local Children = fusion.Children
local Cleanup = fusion.Cleanup

local Computed = fusion.Computed
local DoNothing = fusion.doNothing
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

	local textureName = Value()
	local texturePath = Computed(function()
		textureName:set(nil)

		local data = props.Value:get()
		local id = data and data:split(",")[1]

		if textures and textures:get() then
			local function iterate(textureList: editor.textureList, path: { string }): boolean?
				for _, texture in textureList do
					if texture.id == nil then
						local result = iterate(texture.content, path)

						if result then
							-- push down into table
							table.insert(path, texture.name)
							return result
						end
					elseif texture.id == id then
						textureName:set(texture.name)
						return true
					end
				end

				return nil
			end

			local path = {}
			iterate(textures:get(), path)

			-- invert path
			local newPath = { "Home" }

			for i = #path, 1, -1 do
				table.insert(newPath, path[i])
			end

			return newPath
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

			if not props.Value:get() or props.Value:get().Texture == "" or not textureName:get() then
				return "None"
			end

			if not path then
				return "Unknown"
			end

			return textureName:get()
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
										Path = texturePath:get(false),
									})),
								})[1]
							end

							if not widgetEnabled then
								wasEnabled = false
							end

							return { lastReturn }
						end, DoNothing),
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
