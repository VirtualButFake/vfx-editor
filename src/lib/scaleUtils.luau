local scaleUtils = {}

function scaleUtils.scaleNumber(number: number, scale: number): number
	return number * scale
end

function scaleUtils.scaleNumberSequence(numberSequence: NumberSequence, scale: number): NumberSequence
	local newKeypoints = {}

	for _, keypoint in numberSequence.Keypoints do
		table.insert(
			newKeypoints,
			NumberSequenceKeypoint.new(
				keypoint.Time,
				scaleUtils.scaleNumber(keypoint.Value, scale),
				scaleUtils.scaleNumber(keypoint.Envelope, scale)
			)
		)
	end

	return NumberSequence.new(newKeypoints)
end

function scaleUtils.scaleInstance(instance: Instance | ParticleEmitter | Beam | Trail, scale: number): nil
	if instance:IsA("ParticleEmitter") then
		instance.Size = scaleUtils.scaleNumberSequence(instance.Size, scale)
	elseif instance:IsA("Beam") then
		instance.Width0 = scaleUtils.scaleNumber(instance.Width0, scale)
		instance.Width1 = scaleUtils.scaleNumber(instance.Width1, scale)
	elseif instance:IsA("Trail") then
		instance.WidthScale = scaleUtils.scaleNumberSequence(instance.WidthScale, scale)
	else
		for _, child in instance:GetChildren() do
			scaleUtils.scaleInstance(child, scale)
		end
	end

	return nil
end

return scaleUtils
