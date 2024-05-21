local studioComponents = require("@packages/studioComponents")
local storyBase = studioComponents.utility.storyBase

local fusion = require("@packages/fusion")
local Children = fusion.Children
local New = fusion.New

local Value = fusion.Value

local theme = require("@src/theme")

local app = require("@src/components/app")

local function generateInstance()
	local ice = Instance.new("Part")
	ice.Name = "Ice"
	ice.Anchored = true
	ice.BottomSurface = Enum.SurfaceType.Smooth
	ice.CFrame = CFrame.new(273.922516, 4.19997025, -437.61142, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	ice.CanCollide = false
	ice.CanTouch = false
	ice.CastShadow = false
	ice.Size = Vector3.new(1, 1, 1)
	ice.TopSurface = Enum.SurfaceType.Smooth
	ice.Transparency = 1

	local attachment = Instance.new("Attachment")
	attachment.Name = "Attachment"
	attachment.WorldCFrame = CFrame.new(273.922516, 4.19997025, -437.61142, 1, 0, 0, 0, 1, 0, 0, 0, 1)

	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Brightness = 4
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(127, 217, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(127, 217, 255)),
	})
	trail.FaceCamera = true
	trail.Lifetime = 0.65
	trail.MinLength = 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = attachment

	attachment.Parent = ice

	local a1 = Instance.new("Attachment")
	a1.Name = "A1"
	a1.CFrame = CFrame.new(0, 0, 1.00308228, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	a1.WorldCFrame = CFrame.new(273.922516, 4.19997025, -436.608337, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	a1.Parent = ice

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "PointLight"
	pointLight.Brightness = 3
	pointLight.Color = Color3.fromRGB(157, 223, 255)
	pointLight.Parent = ice

	local particles = Instance.new("Attachment")
	particles.Name = "Particles"
	particles.WorldCFrame = CFrame.new(273.922516, 4.19997025, -437.61142, 1, 0, 0, 0, 1, 0, 0, 0, 1)

	local specs = Instance.new("ParticleEmitter")
	specs.Name = "Specs"
	specs.Brightness = 4
	specs.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 191, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(128, 191, 255)),
	})
	specs.Lifetime = NumberRange.new(0.65, 1)
	specs.Rate = 50
	specs.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.155, 0.938, 0.938),
		NumberSequenceKeypoint.new(1, 0),
	})
	specs.Speed = NumberRange.new(5, 8.5)
	specs.SpreadAngle = Vector2.new(-360, 360)
	specs.Texture = "rbxassetid://8030760338"
	specs.ZOffset = 2
	specs.Parent = particles

	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Drops"
	drops.Acceleration = Vector3.new(0, -15, 0)
	drops.Brightness = 4
	drops.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 191, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(128, 191, 255)),
	})
	drops.Lifetime = NumberRange.new(0.65, 1)
	drops.Orientation = Enum.ParticleOrientation.VelocityParallel
	drops.Rate = 25
	drops.Rotation = NumberRange.new(-90)
	drops.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, 0.562, 0.562),
		NumberSequenceKeypoint.new(1, 0),
	})
	drops.Speed = NumberRange.new(5, 8.5)
	drops.SpreadAngle = Vector2.new(-360, 360)
	drops.Texture = "rbxassetid://8271975883"
	drops.ZOffset = 2
	drops.Parent = particles

	particles.Parent = ice

	return ice
end

return {
	summary = "A full representation of the plugin",
	controls = {
		Height = 550,
		Width = 350,
	},
	story = function(prnt, props)
		if props.controls.Height == "" or props.controls.Width == "" then
			props.controls.Height = 550
			props.controls.Width = 350
		end

		return storyBase(function(parent)
			local backgroundColor = theme.global.isDark:get() and Color3.fromRGB(46, 46, 46)
				or Color3.fromRGB(255, 255, 255)

			local instances = Value({
				generateInstance(),
			})

			local background = New("Frame")({
				BackgroundColor3 = backgroundColor,
				Parent = parent,
				Size = UDim2.new(1, 0, 1, 0),
				[Children] = {
					app({
						Items = instances,
					}),
				},
			})

			background.Parent = parent

			return function()
				background:Destroy()
			end
		end)(prnt, props)
	end,
}
