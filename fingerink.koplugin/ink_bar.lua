-- A permanent status hub and a tap-to-open radial tool wheel.
local BB = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen
local InkBar = WidgetContainer:extend{ side = "right" }
local INPUT = { onGesture=true, onKeyPress=true, onKeyRepeat=true, onKeyRelease=true }
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
function InkBar:init()
    self.hub_r = Screen:scaleBySize(30)
    self.node_r = Screen:scaleBySize(29)
    self.orbit = Screen:scaleBySize(91)
    self.outer_r = self.orbit + self.node_r + Screen:scaleBySize(7)
    self.labels = {}
    self.position = self.position or { x = self.side == "left" and 8 or Screen:getWidth()-self.hub_r*2-8,
        y = math.floor(Screen:getHeight()/2)-self.hub_r }
    self.expanded = false
    self.nodes = {
        { id="pen", label=_("Pen") }, { id="highlight", label=_("Mark") },
        { id="eraser", label=_("Erase") }, { id="undo", label=_("Undo") },
        { id="note", label=_("Note") }, { id="width", label=_("Width") },
        { id="read", label=_("Read") }, { id="collapse", label=_("Close") },
    }
    self:layout()
    self:update(false)
end
function InkBar:layout()
    local r = self.expanded and self.outer_r or self.hub_r
    local cx = clamp(self.position.x+self.hub_r,r+2,Screen:getWidth()-r-2)
    local cy = clamp(self.position.y+self.hub_r,r+2,Screen:getHeight()-r-2)
    self.cx,self.cy = cx,cy
    self.dimen = Geom:new{ x=cx-r,y=cy-r,w=r*2,h=r*2 }
    for i,node in ipairs(self.nodes) do
        local a = -math.pi/2+(i-1)*math.pi/4
        node.x,node.y = cx+self.orbit*math.cos(a),cy+self.orbit*math.sin(a)
    end
end
function InkBar:clampPosition(x,y)
    return clamp(x,2,Screen:getWidth()-self.hub_r*2-2),clamp(y,2,Screen:getHeight()-self.hub_r*2-2)
end
function InkBar:setExpanded(on)
    self.expanded = on and true or false
    self:layout()
    -- Redraw the page under the old wheel; only happens on menu interactions.
    UIManager:setDirty(self.plugin.ui,"ui")
    self:update(true)
end
function InkBar:getVisibleDimen() return self.dimen end
function InkBar:getSize() return self.dimen end
function InkBar:contains(x,y)
    local d=self.dimen
    return x>=d.x and y>=d.y and x<d.x+d.w and y<d.y+d.h
end
function InkBar:update(refresh)
    local p=self.plugin
    self.state = not p.drawing and _("READ") or p.eraser and _("ERASE") or p.highlighter and _("MARK") or _("PEN")
    self.subtitle = p.drawing and _("ON") or _("OFF")
    for _,label in pairs(self.labels) do label:free() end
    self.labels={}
    local function label(key,text,bold)
        self.labels[key]=TextWidget:new{ text=text, face=Font:getFace("smallinfofont",14), bold=bold }
    end
    label("state",self.state,true)
    label("subtitle",self.expanded and _("Close") or self.subtitle,false)
    for i,node in ipairs(self.nodes) do
        node.selected = (node.id=="read" and not p.drawing)
            or (p.drawing and ((node.id=="pen" and not p.eraser and not p.highlighter)
            or (node.id=="eraser" and p.eraser) or (node.id=="highlight" and p.highlighter)))
        label(i,(node.selected and "● " or "") .. (node.id=="width" and tostring(p.pen_width or 4).." px" or node.label),node.selected)
    end
    if refresh then UIManager:setDirty(self,"ui",self.dimen) end
end
function InkBar:paintTo(bb)
    local function circle(x,y,r) bb:paintCircle(x,y,r,BB.COLOR_WHITE);bb:paintCircle(x,y,r,BB.COLOR_BLACK,2) end
    local function text(key,x,y)
        local t=self.labels[key];local s=t:getSize();t:paintTo(bb,math.floor(x-s.w/2),math.floor(y-s.h/2))
    end
    if self.expanded then
        circle(self.cx,self.cy,self.outer_r)
        for i,node in ipairs(self.nodes) do circle(node.x,node.y,self.node_r);text(i,node.x,node.y) end
    end
    circle(self.cx,self.cy,self.hub_r)
    text("state",self.cx,self.cy-8);text("subtitle",self.cx,self.cy+10)
end
function InkBar:activate(id)
    local p=self.plugin
    if id=="collapse" then self:setExpanded(false);return end
    if id=="undo" then p:onFingerInkUndo();self:update(true);return end
    if id=="width" then p:setPenWidth(p.pen_width==2 and 4 or p.pen_width==4 and 7 or 2);self:update(true);return end
    self:setExpanded(false)
    if id=="note" then p:editNote(p:currentPage());return end
    if id=="read" then p:setDrawing(false);return end
    p:setTool(id)
end
function InkBar:onGesture(ges)
    local pos=ges.pos
    if not pos then return end
    local inside=self:contains(pos.x,pos.y)
    if ges.ges=="hold" and inside and not self.expanded then
        self.drag_start={x=pos.x,y=pos.y,px=self.position.x,py=self.position.y};return true
    elseif ges.ges=="hold_release" and self.drag_start then
        local d=self.drag_start;self.drag_start=nil
        local x,y=self:clampPosition(d.px+pos.x-d.x,d.py+pos.y-d.y)
        self.position={x=x,y=y};self.plugin:setBarPosition(x,y);self:layout()
        UIManager:setDirty(self.plugin.ui,"ui");self:update(true);return true
    elseif self.drag_start then return true end
    if not inside then
        if self.expanded and ges.ges=="tap" then self:setExpanded(false);return true end
        return
    end
    if ges.ges=="tap" then
        if not self.expanded then self:setExpanded(true)
        elseif (pos.x-self.cx)^2+(pos.y-self.cy)^2<=self.hub_r^2 then self:setExpanded(false)
        else
            for _,node in ipairs(self.nodes) do
                if (pos.x-node.x)^2+(pos.y-node.y)^2<=self.node_r^2 then self:activate(node.id);break end
            end
        end
    end
    return true
end
function InkBar:windowBelow()
    for i=#UIManager._window_stack,1,-1 do
        local w=UIManager._window_stack[i].widget
        if w~=self and not w.toast then return w end
    end
end
function InkBar:handleEvent(event)
    if WidgetContainer.handleEvent(self,event) then return true end
    if INPUT[event.handler] then local below=self:windowBelow();if below then return below:handleEvent(event) end end
end
function InkBar:onCloseWidget()
    for _,label in pairs(self.labels) do label:free() end
    self.labels={}
end
return InkBar
