-- Classic click wheel: active mode is explicit; browsing never applies a tool.
-- Render into a bounded private buffer. Never pass fractional pixel coordinates
-- to BlitBuffer's pixel primitives (fractional rows can corrupt screen offsets).
local BB=require("ffi/blitbuffer")
local Device=require("device")
local Font=require("ui/font")
local Geom=require("ui/geometry")
local TextWidget=require("ui/widget/textwidget")
local UIManager=require("ui/uimanager")
local WidgetContainer=require("ui/widget/container/widgetcontainer")
local _=require("gettext")
local Screen=Device.screen
local InkBar=WidgetContainer:extend{side="right"}
local INPUT={onGesture=true,onKeyPress=true,onKeyRepeat=true,onKeyRelease=true}
local floor,pi=math.floor,math.pi
local atan2=math.atan2 or function(y,x) return math.atan(y,x) end
local function round(x) return floor(x+.5) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function copy(d) return {x=d.x,y=d.y,w=d.w,h=d.h} end
local function union(a,b)
    local x,y=math.min(a.x,b.x),math.min(a.y,b.y)
    return Geom:new{x=x,y=y,w=math.max(a.x+a.w,b.x+b.w)-x,h=math.max(a.y+a.h,b.y+b.h)-y}
end
function InkBar:init()
    self.base_scale=Screen:scaleBySize(100)/100
    self.scale=math.min(self.base_scale,(Screen:getWidth()-16)/280,(Screen:getHeight()-16)/444)
    self.items={
        {id="pen",text=_("Pen")},{id="highlight",text=_("Highlighter")},
        {id="eraser",text=_("Eraser")},{id="read",text=_("Read / select text")},
        {id="undo",text=_("Undo stroke")},{id="width",text=_("Pen width")},
        {id="note",text=_("Page note")},{id="collapse",text=_("Close controls")},
    }
    self.expanded=false;self.labels={}
    self.hub_w,self.hub_h=self:S(66),self:S(52)
    self.position=self.position or {x=self.side=="left" and 8 or Screen:getWidth()-self.hub_w-8,
        y=round(Screen:getHeight()/2-self.hub_h/2)}
    self.focus=self:activeIndex();self:layout();self:update(false)
end
function InkBar:S(value) return math.max(1,round(value*self.scale)) end
function InkBar:activeId()
    local p=self.plugin
    return not p.drawing and "read" or p.eraser and "eraser" or p.highlighter and "highlight" or "pen"
end
function InkBar:activeIndex()
    local id=self:activeId()
    for i,item in ipairs(self.items) do if item.id==id then return i end end
    return 1
end
function InkBar:clampPosition(x,y)
    return round(clamp(x,2,Screen:getWidth()-self.hub_w-2)),round(clamp(y,2,Screen:getHeight()-self.hub_h-2))
end
function InkBar:layout()
    local x,y=self:clampPosition(self.position.x,self.position.y)
    local w,h=self.hub_w,self.hub_h
    if self.expanded then
        w,h=self:S(280),self:S(444)
        x=round(clamp(x+self.hub_w/2-w/2,4,Screen:getWidth()-w-4))
        y=round(clamp(y+self.hub_h/2-h/2,4,Screen:getHeight()-h-4))
    end
    self.dimen=Geom:new{x=x,y=y,w=w,h=h}
    self.wheel_x,self.wheel_y,self.wheel_r,self.select_r=self:S(140),self:S(294),self:S(105),self:S(36)
    self.cx=x+(self.expanded and self.wheel_x or round(w/2))
    self.cy=y+(self.expanded and self.wheel_y or round(h/2))
end
function InkBar:getVisibleDimen() return self.dimen end
function InkBar:getSize() return self.dimen end
function InkBar:contains(x,y)
    local d=self.dimen;return x>=d.x and y>=d.y and x<d.x+d.w and y<d.y+d.h
end
function InkBar:setExpanded(on)
    on=on and true or false
    if on==self.expanded then return end
    local old=copy(self.dimen)
    self.expanded=on;self.rotating=false;self.angle=nil;self.rotation=0
    if on then self.focus=self:activeIndex();self.plugin:abortStroke() end
    self:layout();self:update(false)
    -- Refresh both the old and the new bounds; closing performs a clean eink
    -- refresh so the reader under the panel cannot retain wheel outlines.
    local damage=union(old,self.dimen)
    UIManager:setDirty(self.plugin.ui,on and "ui" or "full",damage)
    UIManager:setDirty(self,"ui",damage)
end
function InkBar:freeSurface()
    if self.surface then self.surface:free();self.surface=nil end
end
function InkBar:update(refresh)
    local p=self.plugin
    self.state=not p.drawing and _("READ") or p.eraser and _("ERASE") or p.highlighter and _("MARK") or _("PEN")
    self.subtitle=p.drawing and _("ON") or _("OFF")
    self.active_label=p.drawing and (_("WRITING: ")..self.state) or _("READING: INK OFF")
    for _,label in pairs(self.labels) do label:free() end
    self.labels={};self:freeSurface()
    if refresh then UIManager:setDirty(self,"ui",self.dimen) end
end
-- Every glyph is measured and centered inside its own box at the actual DPI.
function InkBar:text(bb,key,text,size,bold,color,x,y,w,h,align)
    local face_size=size*self.scale/self.base_scale
    local t=TextWidget:new{text=text,face=Font:getFace("smallinfofont",face_size),bold=bold,
        fgcolor=color,max_width=w}
    local dim=t:getSize()
    while dim.h>h and face_size>5 do
        t:free();face_size=face_size-1
        t=TextWidget:new{text=text,face=Font:getFace("smallinfofont",face_size),bold=bold,fgcolor=color,max_width=w}
        dim=t:getSize()
    end
    self.labels[key]=t
    local tx=align=="left" and x or x+round((w-dim.w)/2)
    local ty=y+round((h-dim.h)/2)
    t:paintTo(bb,round(tx),round(ty))
end
local colors={}
local function gray(value)
    value=round(value)
    if not colors[value] then colors[value]=BB.Color8 and BB.Color8(value) or (value<128 and BB.COLOR_BLACK or BB.COLOR_WHITE) end
    return colors[value]
end
local function disk(bb,cx,cy,r,foreground,background)
    cx,cy,r=round(cx),round(cy),round(r)
    local outer,inner=r+.5,math.max(0,r-.5)
    for dy=-r,r do
        local extent=floor(math.sqrt(math.max(0,outer*outer-dy*dy)))
        local core=math.abs(dy)<=inner and floor(math.sqrt(inner*inner-dy*dy)) or -1
        if core>=0 then bb:paintRect(cx-core,cy+dy,core*2+1,1,gray(foreground)) end
        for dx=core+1,extent do
            local coverage=clamp(outer-math.sqrt(dx*dx+dy*dy),0,1)
            local color=gray(foreground*coverage+background*(1-coverage))
            bb:paintRect(cx+dx,cy+dy,1,1,color)
            if dx~=0 then bb:paintRect(cx-dx,cy+dy,1,1,color) end
        end
    end
end

function InkBar:render()
    local d=self.dimen
    local bb=BB.new(d.w,d.h,Screen.bb:getType())
    self.surface=bb;bb:fill(BB.COLOR_WHITE)
    local border=self:S(2)
    bb:paintRoundedRect(0,0,d.w,d.h,BB.COLOR_BLACK,self:S(10))
    bb:paintRoundedRect(border,border,d.w-2*border,d.h-2*border,BB.COLOR_WHITE,self:S(8))
    local function text(key,value,size,bold,color,x,y,w,h,align)
        self:text(bb,key,value,size,bold,color,self:S(x),self:S(y),self:S(w),self:S(h),align)
    end
    if not self.expanded then
        -- Positive/negative state is written out, rather than inferred from an icon.
        if self.plugin.drawing then bb:paintRoundedRect(border,border,d.w-2*border,d.h-2*border,BB.COLOR_BLACK,self:S(8)) end
        local c=self.plugin.drawing and BB.COLOR_WHITE or BB.COLOR_BLACK
        text("hub",self.state,14,true,c,4,4,58,23)
        text("hub_state",self.subtitle,10,true,c,4,29,58,15)
        return
    end
    text("title",_("FINGER INK"),11,true,BB.COLOR_BLACK,12,10,256,21)
    bb:paintRect(self:S(12),self:S(37),self:S(256),self:S(30),BB.COLOR_BLACK)
    text("active",self.active_label,13,true,BB.COLOR_WHITE,18,40,244,24)
    bb:paintRect(self:S(12),self:S(74),self:S(256),self:S(98),BB.COLOR_BLACK)
    bb:paintRect(self:S(13),self:S(75),self:S(254),self:S(96),BB.COLOR_WHITE)
    local n=#self.items
    local before=self.items[(self.focus-2)%n+1]
    local item=self.items[self.focus]
    local after=self.items[self.focus%n+1]
    text("before",before.text,12,false,BB.COLOR_BLACK,24,76,232,25)
    bb:paintRect(self:S(18),self:S(103),self:S(244),self:S(37),BB.COLOR_BLACK)
    local choice=item.id=="width" and (_("Pen width: ")..tostring(self.plugin.pen_width).." px") or item.text
    text("choice",choice,16,true,BB.COLOR_WHITE,29,106,190,31,"left")
    text("count",tostring(self.focus).."/"..n,10,true,BB.COLOR_WHITE,224,106,31,31)
    text("after",after.text,12,false,BB.COLOR_BLACK,24,144,232,25)
    local cx,cy,r=self.wheel_x,self.wheel_y,self.wheel_r
    disk(bb,cx,cy,r,0,255);disk(bb,cx,cy,r-border,235,0)
    disk(bb,cx,cy,self.select_r,0,235);disk(bb,cx,cy,self.select_r-border,255,0)
    text("menu",_("MENU"),11,true,BB.COLOR_BLACK,109,210,62,24)
    text("prev","‹",30,true,BB.COLOR_BLACK,42,278,42,32)
    text("next","›",30,true,BB.COLOR_BLACK,196,278,42,32)
    text("select",_("SELECT"),10,true,BB.COLOR_BLACK,108,282,64,24)
    text("toggle",self.plugin.drawing and _("READ") or _("WRITE"),11,true,BB.COLOR_BLACK,105,353,70,25)
    text("hint",_("Rotate to browse · Center to apply"),10,false,BB.COLOR_BLACK,10,414,260,20)
end
function InkBar:paintTo(bb)
    if not self.surface then self:render() end
    local d=self.dimen
    bb:blitFrom(self.surface,d.x,d.y,0,0,d.w,d.h)
end
function InkBar:browse(delta)
    self.focus=(self.focus-1+delta)%#self.items+1
    self:update(true)
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
function InkBar:ringPoint(x,y)
    local dx,dy=x-self.cx,y-self.cy
    local r2=dx*dx+dy*dy
    return r2>self.select_r*self.select_r and r2<=(self.wheel_r+self:S(8))^2
end
function InkBar:rotateTo(x,y,start)
    if not self.rotating then
        if not start or not self:ringPoint(start.x,start.y) then return end
        self.rotating=true;self.angle=atan2(start.y-self.cy,start.x-self.cx);self.rotation=0
    end
    if not self:ringPoint(x,y) then self.angle=nil;return end
    local angle=atan2(y-self.cy,x-self.cx)
    if not self.angle then self.angle=angle;return end
    local delta=(angle-self.angle+pi)%(2*pi)-pi
    self.angle=angle;self.rotation=self.rotation+delta
    local detent=pi/6
    while self.rotation>=detent do self:browse(1);self.rotation=self.rotation-detent end
    while self.rotation<=-detent do self:browse(-1);self.rotation=self.rotation+detent end
end
function InkBar:onGesture(ges)
    local pos=ges.pos
    if not pos then return end
    local inside=self:contains(pos.x,pos.y)
    if self.expanded then
        if ges.ges=="pan" or ges.ges=="hold_pan" then self:rotateTo(pos.x,pos.y,ges.start_pos or self.hold_start);return true end
        if ges.ges=="hold" then self.hold_start={x=pos.x,y=pos.y};return true end
        if ges.ges=="pan_release" or ges.ges=="hold_release" then
            self.rotating=false;self.hold_start=nil;self.angle=nil;return true
        end
        if ges.ges~="tap" then return inside or nil end
        if not inside then self:setExpanded(false);return true end
        local x,y=pos.x-self.dimen.x,pos.y-self.dimen.y
        if y>=self:S(74) and y<=self:S(172) then
            -- Screen list taps browse too; SELECT is the single commit action.
            if y<self:S(103) then self:browse(-1) elseif y>self:S(140) then self:browse(1) end
            return true
        end
        local dx,dy=pos.x-self.cx,pos.y-self.cy
        if dx*dx+dy*dy<=self.select_r^2 then self:activate(self.items[self.focus].id)
        elseif self:ringPoint(pos.x,pos.y) then
            if math.abs(dx)>math.abs(dy) then self:browse(dx>0 and 1 or -1)
            elseif dy<0 then self:setExpanded(false)
            else
                local p=self.plugin
                if p.drawing then self.resume_tool=self:activeId();p:setDrawing(false)
                else p:setTool(self.resume_tool or (p.eraser and "eraser" or p.highlighter and "highlight" or "pen")) end
                self.focus=self:activeIndex();self:update(true)
            end
        end
        return true
    end
    if ges.ges=="hold" and inside then self.drag_start={x=pos.x,y=pos.y,px=self.position.x,py=self.position.y};return true end
    if ges.ges=="hold_release" and self.drag_start then
        local old=copy(self.dimen);local s=self.drag_start;self.drag_start=nil
        local x,y=self:clampPosition(s.px+pos.x-s.x,s.py+pos.y-s.y)
        self.position={x=x,y=y};self.plugin:setBarPosition(x,y);self:layout();self:update(false)
        UIManager:setDirty(self.plugin.ui,"ui",union(old,self.dimen));UIManager:setDirty(self,"ui",self.dimen);return true
    end
    if self.drag_start then return true end
    if inside then if ges.ges=="tap" then self:setExpanded(true) end;return true end
end
function InkBar:windowBelow()
    for i=#UIManager._window_stack,1,-1 do local w=UIManager._window_stack[i].widget;if w~=self and not w.toast then return w end end
end
function InkBar:handleEvent(event)
    if WidgetContainer.handleEvent(self,event) then return true end
    if INPUT[event.handler] then local below=self:windowBelow();if below then return below:handleEvent(event) end end
end
function InkBar:onCloseWidget()
    for _,label in pairs(self.labels) do label:free() end
    self.labels={};self:freeSurface()
end
return InkBar
