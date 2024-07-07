local fusion = require("@packages/fusion")
local Cleanup = fusion.Cleanup
local New = fusion.New

local Computed = fusion.Computed
local Observer = fusion.Observer
local Value = fusion.Value

local studioComponents = require("@packages/studioComponents")
local button = studioComponents.common.button
local imageLabel = studioComponents.base.imageLabel
local text = studioComponents.base.text

local tailwind = require("@packages/tailwind")

local fusionUtils = require("@packages/fusionUtils")
local awaitLayer = fusionUtils.awaitLayer
local onDestroy = fusionUtils.onDestroy

local theme = require("@src/theme")

type props = {
	Value: fusion.Value<Instance>,
	LayoutOrder: number,
	Filter: (instance: Instance) -> boolean,
	Events: { [string]: BindableEvent },
}

local sharedSelectState = Value(nil)

local function objectPropertyField(props: props, useColor: theme.useColorFunction)
	local instanceClassIcon = Computed(function()
		if props.Value:get() then
			return theme.getClassIcon(props.Value:get().ClassName):get()
		end

		return {}
	end)

	local isSelectingItem = Value(false)
    local selectionConnection

	local instanceName = Value()
	local lastConnection

	local function updateName()
		if lastConnection then
			lastConnection:Disconnect()
		end

		if props.Value:get(false) then
			instanceName:set(props.Value:get(false).Name)
			lastConnection = props.Value:get(false):GetPropertyChangedSignal("Name"):Connect(function()
				instanceName:set(props.Value:get().Name)
			end)
		else
			instanceName:set("None")
		end
	end

	updateName()

	local component = button({
		Variant = "solid",
		Color = "white",
		DisableHoverLighting = true,
		AppearanceOverride = {
			Pressing = {
				Stroke = theme.global.isDark:get() and tailwind.blue[400] or tailwind.blue[500],
			},
		},
		LayoutOrder = props.LayoutOrder,
		[Cleanup] = {
			Observer(props.Value):onChange(updateName),
			selectionConnection
		},
		OnClick = function()
			local currentState = isSelectingItem:get()
			local usedSharedSelectState = sharedSelectState:get()

			if usedSharedSelectState == isSelectingItem and currentState then
				sharedSelectState:set(nil)
				isSelectingItem:set(false)
			else
				if usedSharedSelectState ~= nil and usedSharedSelectState ~= isSelectingItem then
					usedSharedSelectState:set(false)
				end

				sharedSelectState:set(isSelectingItem)
				isSelectingItem:set(true)

                selectionConnection = props.Events.OnItemClicked.Event:Connect(function(instance)
                    if isSelectingItem:get() then
                        props.Value:set(instance)
                        sharedSelectState:set(nil)
                        isSelectingItem:set(false)
                    end
                end)
			end
		end,
		Margin = 3,
		Content = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			imageLabel({
				Size = UDim2.new(0, 16, 0, 16),
				Image = Computed(function()
					return instanceClassIcon:get().Image or ""
				end),
				ImageRectSize = Computed(function()
					return instanceClassIcon:get().ImageRectSize or Vector2.new(0, 0)
				end),
				ImageRectOffset = Computed(function()
					return instanceClassIcon:get().ImageRectOffset or Vector2.new(0, 0)
				end),
				Visible = Computed(function()
					return not isSelectingItem:get() and instanceClassIcon:get().Image ~= nil
				end),
				BackgroundTransparency = 1,
			}),
			text({
				Name = "Text",
				AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.new(0, 0, 0, 16),
				Appearance = useColor("Text", true),
				Text = Computed(function()
					return isSelectingItem:get() and "Select instance.." or instanceName:get()
				end),
				LayoutOrder = 2,
			}),
		},
	})

	awaitLayer(component, function(layer)
		onDestroy(component, {
			Observer(layer.state.mouseDown):onChange(function()
				if isSelectingItem:get() and not layer.state.mouseDown:get() then
					isSelectingItem:set(false)
					sharedSelectState:set(nil)
                    selectionConnection:Disconnect()
				end
			end),
		})
	end)

	return component
end

return objectPropertyField
