return function()
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Transparency = 1
	part.CFrame = CFrame.new(0, 2, 0)
	part.Size = Vector3.new(1, 1, 1)
	part.CanCollide = false
	part.BrickColor = BrickColor.new("Institutional white")

	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Lifetime = NumberRange.new(0.25, 0.25)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.new(1.00, 0.85, 0.45)),
		ColorSequenceKeypoint.new(1.00, Color3.new(1.00, 0.85, 0.45)),
	})
	emitter.LightEmission = 1
	emitter.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.50, 0.25),
		NumberSequenceKeypoint.new(1.00, 0.00, 0.00),
	})
	emitter.Speed = NumberRange.new(0.00, 0.00)
	emitter.Texture = "rbxassetid://6865222957"
	emitter.Rotation = NumberRange.new(-36.00, 360.00)
	emitter.Rate = 25
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1.00, 0.00),
		NumberSequenceKeypoint.new(0.50, 0.00, 0.00),
		NumberSequenceKeypoint.new(1.00, 1.00, 0.00),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 2.00, 0.00),
		NumberSequenceKeypoint.new(1.00, 0.00, 0.00),
	})
	emitter.Parent = attachment

	part.Parent = workspace
    part.Anchored = true
	return part
end
