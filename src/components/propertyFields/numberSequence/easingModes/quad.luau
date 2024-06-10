return {
	In = function(a, b, t)
		return a + (b - a) * t * t
	end,
	Out = function(a, b, t)
		return a + (b - a) * t * (2 - t)
	end,
	InOut = function(a, b, t)
		if t < 0.5 then
			return a + (b - a) * 2 * t * t
		else
			return a + (b - a) * (1 - 2 * (1 - t) * (1 - t))
		end
	end,
}
