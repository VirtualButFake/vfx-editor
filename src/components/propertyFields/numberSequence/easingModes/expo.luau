return {
	In = function(a, b, t)
		return a + (b - a) * 2 ^ (10 * (t - 1))
	end,
	Out = function(a, b, t)
		return a + (b - a) * (1 - 2 ^ (-10 * t))
	end,
	InOut = function(a, b, t)
		if t < 0.5 then
			return a + (b - a) * 0.5 * 2 ^ (20 * t - 10)
		else
			return a + (b - a) * (1 - 0.5 * 2 ^ (-20 * t + 10))
		end
	end,
}
