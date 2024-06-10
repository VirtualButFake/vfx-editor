local function getCubicBezier(t: number, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2): Vector2
	return (1 - t) ^ 3 * p0 + 3 * (1 - t) ^ 2 * t * p1 + 3 * (1 - t) * t ^ 2 * p2 + t ^ 3 * p3
end

local function fixedBezier(n, t, p0, p1, p2, p3)
	local length, ranges, sums = 0, {}, {}

	for i = 0, n - 1 do
		local startPoint, endPoint = getCubicBezier(i / n, p0, p1, p2, p3), getCubicBezier((i + 1) / n, p0, p1, p2, p3)
		local dist = (endPoint - startPoint).Magnitude

		ranges[length] = { dist, startPoint, endPoint }

		table.insert(sums, length)
		length = length + dist
	end

	-- find how far along the length we should be
	local T, near = t * length, 0
	-- get the nearest point we calculated
	for _, element in next, sums do
		if (T - element) < 0 then
			break
		end
		near = element
	end
	local set = ranges[near]
	-- linearly interpolate between that point and its neighbor
	local percent = (T - near) / set[1]
	return set[2] + (set[3] - set[2]) * percent
end

return {
	Ease = function(t, p0, p1, p2, p3)
		-- there is optimization to be done here, but there's no need for it (yet)
		return fixedBezier(10, t, p0, p1, p2, p3)
	end,
}
