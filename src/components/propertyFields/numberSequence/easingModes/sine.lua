return {
	In = function(a, b, t)
		return a + (b - a) * (1 - math.cos(t * math.pi / 2))
	end,
	Out = function(a, b, t)
		return a + (b - a) * math.sin(t * math.pi / 2)
	end,
	InOut = function(a, b, t)
		return a + (b - a) * (1 - math.cos(t * math.pi)) / 2
	end,    
}
