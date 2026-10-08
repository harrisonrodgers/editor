-- Blend color `fg` over `bg` (both "#rrggbb") by `alpha`, for subtle tinted backgrounds.
return function(fg, bg, alpha)
    local out = "#"
    for i = 2, 6, 2 do
        local f, b = tonumber(fg:sub(i, i + 1), 16), tonumber(bg:sub(i, i + 1), 16)
        out = out .. string.format("%02x", math.floor(b + (f - b) * alpha + 0.5))
    end
    return out
end
