return {
	In = function(a, b, t)
		local s = 1.70158
		return a + (b - a) * t * t * ((s + 1) * t - s)
	end,
	Out = function(a, b, t)
		local s = 1.70158
		t = t - 1
		return a + (b - a) * (t * t * ((s + 1) * t + s) + 1)
	end,
	InOut = function(a, b, t)
		local s = 1.70158 * 1.525
		t = t * 2
		if t < 1 then
			return a + (b - a) * 0.5 * (t * t * ((s + 1) * t - s))
		else
			t = t - 2
			return a + (b - a) * 0.5 * (t * t * ((s + 1) * t + s) + 2)
		end
	end,
}
