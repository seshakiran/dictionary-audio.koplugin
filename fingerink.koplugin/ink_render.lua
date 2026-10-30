-- Merge overlapping square brush stamps into rectangles along the dominant
-- axis. Same coverage, fewer calls into the blitter, especially for markers.
local floor, ceil, abs = math.floor, math.ceil, math.abs
local Render = {}
local function rect(bb, x, y, w, h, color, highlight)
    if not highlight then bb:paintRect(x, y, w, h, color); return end
    for py = y + (-y % 4), y + h - 1, 4 do
        for px = x + (-x % 4), x + w - 1, 4 do bb:paintRect(px, py, 1, 1, color) end
    end
end
function Render.segment(bb, x0, y0, x1, y1, w, color, highlight)
    local half = floor(w / 2)
    local dx, dy = x1 - x0, y1 - y0
    local steps = ceil(math.max(abs(dx), abs(dy)))
    if steps == 0 then rect(bb, floor(x0)-half, floor(y0)-half, w, w, color, highlight); return end
    if dy == 0 then
        rect(bb, floor(math.min(x0,x1))-half, floor(y0)-half,
            floor(math.max(x0,x1))-floor(math.min(x0,x1))+w, w, color, highlight)
        return
    elseif dx == 0 then
        rect(bb, floor(x0)-half, floor(math.min(y0,y1))-half, w,
            floor(math.max(y0,y1))-floor(math.min(y0,y1))+w, color, highlight)
        return
    end
    local horizontal = abs(dx) >= abs(dy)
    local start, last, minor
    for i = 0, steps do
        local x, y = floor(x0 + dx * i / steps), floor(y0 + dy * i / steps)
        local major, next_minor = horizontal and x or y, horizontal and y or x
        if minor ~= next_minor then
            if minor then
                local low, high = math.min(start,last)-half, math.max(start,last)-half+w
                if horizontal then rect(bb, low, minor-half, high-low, w, color, highlight)
                else rect(bb, minor-half, low, w, high-low, color, highlight) end
            end
            start, minor = major, next_minor
        end
        last = major
    end
    local low, high = math.min(start,last)-half, math.max(start,last)-half+w
    if horizontal then rect(bb, low, minor-half, high-low, w, color, highlight)
    else rect(bb, minor-half, low, w, high-low, color, highlight) end
end
function Render.stroke(bb, s, ox, oy, color)
    if s.n < 1 then return end
    if s.n == 1 then
        Render.segment(bb, ox+s[1],oy+s[2],ox+s[1],oy+s[2],s.w,color,s.tool=="highlight")
    else
        for i = 1, (s.n-1)*2, 2 do
            Render.segment(bb,ox+s[i],oy+s[i+1],ox+s[i+2],oy+s[i+3],s.w,color,s.tool=="highlight")
        end
    end
end
return Render
