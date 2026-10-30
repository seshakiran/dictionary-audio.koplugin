--[[--
Stroke rasterisation. Numbers only on every hot path — no tables are created
here, by anything, ever.
]]

local floor = math.floor

local Render = {}

--- Paint a w-wide segment from (x0,y0) to (x1,y1) into bb.
local function stamp(bb, x, y, w, color, highlight)
    if not highlight then bb:paintRect(x, y, w, w, color); return end
    for py = y + (-y % 4), y + w - 1, 4 do
        for px = x + (-x % 4), x + w - 1, 4 do
            bb:paintRect(px, py, 1, 1, color)
        end
    end
end

function Render.segment(bb, x0, y0, x1, y1, w, color, highlight)
    local half = floor(w / 2)
    local dx = x1 - x0
    local dy = y1 - y0
    local adx = dx >= 0 and dx or -dx
    local ady = dy >= 0 and dy or -dy
    local steps = adx > ady and adx or ady

    if steps < 1 then
        stamp(bb, floor(x0) - half, floor(y0) - half, w, color, highlight)
        return
    end

    steps = floor(steps)
    local sx = dx / steps
    local sy = dy / steps
    local x, y = x0, y0
    for _ = 0, steps do
        stamp(bb, floor(x) - half, floor(y) - half, w, color, highlight)
        x = x + sx
        y = y + sy
    end
end

--- Replay a whole stroke. ox/oy let a caller shift it; both are 0 today.
function Render.stroke(bb, s, ox, oy, color)
    local n = s.n
    local w = s.w
    if n < 1 then return end
    if n == 1 then
        local half = floor(w / 2)
        stamp(bb, floor(ox + s[1]) - half, floor(oy + s[2]) - half, w, color, s.tool == "highlight")
        return
    end
    for i = 1, (n - 1) * 2, 2 do
        Render.segment(bb, ox + s[i], oy + s[i + 1],
                           ox + s[i + 2], oy + s[i + 3], w, color, s.tool == "highlight")
    end
end

return Render
