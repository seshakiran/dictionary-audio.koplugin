-- Merge input samples into one display post per frame. Android posts copy the
-- whole window, so never perform one for every stylus coordinate.
local Refresh = {}
Refresh.__index = Refresh
function Refresh.new(manager, screen, fast, hz)
    local self = setmetatable({ manager = manager, screen = screen, fast = fast,
        interval = 1 / (hz or 30) }, Refresh)
    self.callback = function() self.scheduled = false; self:flush() end
    return self
end
function Refresh:add(x, y, w, h)
    if self.x then
        local right, bottom = math.max(self.x + self.w, x + w), math.max(self.y + self.h, y + h)
        self.x, self.y = math.min(self.x, x), math.min(self.y, y)
        self.w, self.h = right - self.x, bottom - self.y
    else
        self.x, self.y, self.w, self.h = x, y, w, h
    end
    if not self.scheduled then
        self.scheduled = true
        self.manager:scheduleIn(self.interval, self.callback)
    end
end
function Refresh:flush()
    if self.scheduled then self.manager:unschedule(self.callback); self.scheduled = false end
    if not self.x then return end
    local x, y, w, h = self.x, self.y, self.w, self.h
    self.x, self.y, self.w, self.h = nil, nil, nil, nil
    if self.fast then self.screen:refreshFast(x, y, w, h)
    else self.screen:refreshPartial(x, y, w, h) end
end
function Refresh:cancel()
    if self.scheduled then self.manager:unschedule(self.callback) end
    self.scheduled = false
    self.x, self.y, self.w, self.h = nil, nil, nil, nil
end
return Refresh
