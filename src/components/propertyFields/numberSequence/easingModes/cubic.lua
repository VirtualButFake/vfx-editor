return {
    In = function(a, b, t)
        return a + (b - a) * t * t * t
    end,
    Out = function(a, b, t)
        return a + (b - a) * ((t - 1) * (t - 1) * (t - 1) + 1)
    end,
    InOut = function(a, b, t)
        if t < 0.5 then
            return a + (b - a) * 4 * t * t * t
        else
            return a + (b - a) * ((t - 1) * (2 * t - 2) * (2 * t - 2) + 1)
        end
    end,
}