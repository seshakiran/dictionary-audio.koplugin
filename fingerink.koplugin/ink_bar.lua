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
local function rgb(r,g,b) return {r,g or r,b or r} end
local THEMES={
    color={shell=rgb(245,247,251),panel=rgb(255),ink=rgb(23,36,59),muted=rgb(73,90,113),
        line=rgb(163,177,197),soft=rgb(234,240,249),wheel=rgb(233,238,245),white=rgb(255),
        pen=rgb(35,88,184),highlight=rgb(148,99,0),eraser=rgb(183,68,55),read=rgb(5,111,111),action=rgb(35,88,184)},
    mono={shell=rgb(255),panel=rgb(255),ink=rgb(0),muted=rgb(0),line=rgb(0),soft=rgb(255),
        wheel=rgb(235),white=rgb(255),pen=rgb(0),highlight=rgb(0),eraser=rgb(0),read=rgb(0),action=rgb(0)},
}
local NAMES={pen=_("Pen"),highlight=_("Highlighter"),eraser=_("Eraser"),read=_("Reading")}
local NAV={pen=_("Pen"),highlight=_("Marker"),eraser=_("Eraser"),read=_("Read"),
    undo=_("Undo"),width=_("Width"),note=_("Note"),collapse=_("Close")}
function InkBar:displayInfo()
    local p=self.plugin
    local active=self:activeId()
    local input=p.stylus_only and _("Pen only") or _("Pen + finger")
    local width=tostring(p.pen_width or 4).." px"
    local states={
        pen={status=_("WRITING ON"),detail=width.." · "..input,help=_("Write directly on the page.")},
        highlight={status=_("HIGHLIGHTING ON"),detail="24 px · "..input,help=_("Shade parts of the book page.")},
        eraser={status=_("ERASING ON"),detail=input,help=_("Touch ink to remove a stroke.")},
        read={status=_("WRITING OFF"),detail=_("Page turns and word selection"),help=_("Choose a writing tool to begin.")},
    }
    local now=states[active];now.id=active;now.name=NAMES[active]
    local id=self.items[self.focus].id
    local next_width=p.pen_width==2 and 4 or p.pen_width==4 and 7 or 2
    local choices={
        pen={name=NAMES.pen,lines={_("Write handwritten notes"),_("directly on the book page.")}},
        highlight={name=NAMES.highlight,lines={_("Shade text with broad ink."),_("Keeps the book text visible.")}},
        eraser={name=NAMES.eraser,lines={_("Remove handwritten ink."),_("Erases one whole stroke at a time.")}},
        read={name=NAMES.read,lines={_("Stop handwriting to turn pages"),_("or select words for lookup.")}},
        undo={name=_("Undo last stroke"),lines={_("Remove the most recent stroke"),_("on the current page.")},action=_("SELECT: Undo last stroke"),verb=_("UNDO")},
        width={name=width.." → "..next_width.." px",lines={_("Change the pen's line thickness."),_("The highlighter stays 24 px wide.")},action=_("SELECT: Set pen to ")..next_width.." px",verb=_("CHANGE")},
        note={name=_("Page note"),lines={_("Open the typed note editor"),_("for this page of the book.")},action=_("SELECT: Open page note"),verb=_("OPEN")},
        collapse={name=_("Close controls"),lines={_("Keep using the current tool."),_("The status button stays visible.")},action=_("SELECT: Close this panel"),verb=_("CLOSE")},
    }
    local choice=choices[id];choice.id=id;choice.current=id==active;choice.available=true
    if NAMES[id] then
        if choice.current then
            choice.badge=_("ACTIVE NOW");choice.lines[2]=_("This tool is already in use.")
            choice.action=_("SELECT: Keep using ")..NAMES[id];choice.verb=_("KEEP")
        else
            choice.badge=_("NOT ACTIVE")
            choice.action=id=="read" and _("SELECT: Stop handwriting") or (_("SELECT: Switch to ")..NAMES[id])
            choice.verb=id=="read" and _("READ") or _("SWITCH")
        end
    else choice.badge=_("ACTION") end
    local page_ink=p.store and p.currentPage and p.store:get(p:currentPage())
    if id=="undo" and p.store and p.currentPage and (not page_ink or #page_ink==0) then
        choice.available=false;choice.badge=_("NO INK");choice.lines={_("No strokes on this page yet."),_("Choose Pen or Highlighter first.")}
        choice.action=_("Nothing to undo on this page");choice.verb=_("NONE")
    end
    local n=#self.items
    return {now=now,choice=choice,previous=NAV[self.items[(self.focus-2)%n+1].id],
        next=NAV[self.items[self.focus%n+1].id],count=self.focus.." / "..n}
end
function InkBar:color(value)
    local key=value[1]*65536+value[2]*256+value[3]
    if not self.color_cache[key] then
        self.color_cache[key]=self.color_mode and BB.ColorRGB32(value[1],value[2],value[3],255)
            or (BB.Color8 and BB.Color8(value[1]) or (value[1]<128 and BB.COLOR_BLACK or BB.COLOR_WHITE))
    end
    return self.color_cache[key]
end
function InkBar:rect(bb,x,y,w,h,value,radius)
    local c=self:color(value)
    if radius then
        if self.color_mode then bb:paintRoundedRectRGB32(x,y,w,h,c,radius) else bb:paintRoundedRect(x,y,w,h,c,radius) end
    elseif self.color_mode then bb:paintRectRGB32(x,y,w,h,c)
    else bb:paintRect(x,y,w,h,c) end
end
-- TextWidget's usual glyph blit converts colors to gray. Bind only its local
-- drawing target to the RGB blitter; never patch a shared/global buffer.
function InkBar:textTarget(bb)
    if not self.color_mode or not bb.colorblitFromRGB32 then return bb end
    return setmetatable({},{__index=function(_,key)
        local member=key=="colorblitFrom" and bb.colorblitFromRGB32 or bb[key]
        if type(member)=="function" then return function(_,...) return member(bb,...) end end
        return member
    end})
end

function InkBar:init()
    self.base_scale=Screen:scaleBySize(100)/100
    self.scale=math.min(self.base_scale,(Screen:getWidth()-16)/300,(Screen:getHeight()-16)/576)
    self.items={
        {id="pen",text=_("Pen")},{id="highlight",text=_("Highlighter")},
        {id="eraser",text=_("Eraser")},{id="read",text=_("Read / select text")},
        {id="undo",text=_("Undo stroke")},{id="width",text=_("Pen width")},
        {id="note",text=_("Page note")},{id="collapse",text=_("Close controls")},
    }
    self.color_mode=not not (Device.hasColorScreen and Device:hasColorScreen() and BB.ColorRGB32 and BB.TYPE_BBRGB32)
    self.palette=THEMES[self.color_mode and "color" or "mono"];self.color_cache={}
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
        w,h=self:S(300),self:S(576)
        x=round(clamp(x+self.hub_w/2-w/2,4,Screen:getWidth()-w-4))
        y=round(clamp(y+self.hub_h/2-h/2,4,Screen:getHeight()-h-4))
    end
    self.dimen=Geom:new{x=x,y=y,w=w,h=h}
    self.wheel_x,self.wheel_y,self.wheel_r,self.select_r=self:S(150),self:S(449),self:S(91),self:S(33)
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
local function disk(self,bb,cx,cy,r,foreground,background)
    cx,cy,r=round(cx),round(cy),round(r)
    local outer,inner=r+.5,math.max(0,r-.5)
    for dy=-r,r do
        local extent=floor(math.sqrt(math.max(0,outer*outer-dy*dy)))
        local core=math.abs(dy)<=inner and floor(math.sqrt(inner*inner-dy*dy)) or -1
        if core>=0 then self:rect(bb,cx-core,cy+dy,core*2+1,1,foreground) end
        for dx=core+1,extent do
            local a=clamp(outer-math.sqrt(dx*dx+dy*dy),0,1)
            local color={}
            for channel=1,3 do color[channel]=round(foreground[channel]*a+background[channel]*(1-a)) end
            self:rect(bb,cx+dx,cy+dy,1,1,color)
            if dx~=0 then self:rect(bb,cx-dx,cy+dy,1,1,color) end
        end
    end
end
function InkBar:render()
    local d,p,info=self.dimen,self.palette,self:displayInfo()
    self.info=info
    local kind=self.color_mode and BB.TYPE_BBRGB32 or Screen.bb:getType()
    local bb=BB.new(d.w,d.h,kind)
    self.surface=bb
    self:rect(bb,0,0,d.w,d.h,p.line,self:S(12))
    local edge=self:S(1)
    self:rect(bb,edge,edge,d.w-2*edge,d.h-2*edge,p.shell,self:S(11))
    local function box(x,y,w,h,color,radius)
        self:rect(bb,self:S(x),self:S(y),self:S(w),self:S(h),color,radius and self:S(radius))
    end
    local function text(key,value,size,bold,color,x,y,w,h,align)
        self:text(self:textTarget(bb),key,value,size,bold,self:color(color),self:S(x),self:S(y),self:S(w),self:S(h),align)
    end
    local active=p[info.now.id]
    if not self.expanded then
        if self.plugin.drawing then self:rect(bb,edge,edge,d.w-2*edge,d.h-2*edge,active,self:S(10)) end
        local ink=self.plugin.drawing and p.white or p.ink
        text("hub",self.state,14,true,ink,4,4,58,23)
        text("hub_state",self.subtitle,10,true,ink,4,29,58,15)
        return
    end
    text("title",_("PAGESCRIBE"),11,true,p.ink,12,9,276,20)
    box(12,36,276,130,p.line,8);box(13,37,274,128,p.panel,7)
    text("now_label",_("NOW USING"),9,true,p.muted,24,42,252,16,"left")
    box(24,65,54,54,active,9)
    text("art",self.state,10,true,p.white,27,77,48,29)
    text("now_name",info.now.name,23,true,p.ink,90,63,185,33,"left")
    box(90,100,185,21,active,4)
    text("now_status",info.now.status,10,true,p.white,94,100,177,21)
    text("now_detail",info.now.detail,11,true,p.ink,24,127,252,17,"left")
    text("now_help",info.now.help,10,false,p.muted,24,146,252,15,"left")
    local c=info.choice
    local accent=p[c.id] or p.action
    box(12,177,276,141,p.line,8);box(13,178,274,139,p.panel,7)
    text("browse_label",_("CHOOSE NEXT").."  "..info.count,8.5,true,p.muted,24,185,142,16,"left")
    box(170,184,105,18,c.current and active or p.soft,4)
    text("browse_badge",c.badge,8.5,true,c.current and p.white or p.ink,173,184,99,18)
    text("choice",c.name,21,true,p.ink,24,207,252,30,"left")
    text("choice_help1",c.lines[1],11,false,p.ink,24,240,252,18,"left")
    text("choice_help2",c.lines[2],11,false,p.muted,24,259,252,18,"left")
    box(20,286,260,26,accent,5)
    text("apply",c.action,11,true,p.white,26,287,248,24)
    text("previous",_("‹ Prev: ")..info.previous,9,true,p.muted,13,325,132,21)
    text("next",_("Next: ")..info.next.." ›",9,true,p.muted,155,325,132,21)
    local cx,cy,r=self.wheel_x,self.wheel_y,self.wheel_r
    disk(self,bb,cx,cy,r,p.line,p.shell)
    disk(self,bb,cx,cy,r-self:S(2),p.wheel,p.line)
    disk(self,bb,cx,cy,self.select_r,p.line,p.wheel)
    disk(self,bb,cx,cy,self.select_r-self:S(2),accent,p.line)
    text("menu",_("MENU"),10,true,p.ink,119,371,62,21)
    text("prev","‹",27,true,p.ink,64,433,36,31)
    text("next_arrow","›",27,true,p.ink,200,433,36,31)
    text("select",_("SELECT"),9,true,p.white,119,431,62,16)
    text("select_verb",c.verb,8.5,true,p.white,119,450,62,15)
    text("toggle",self.plugin.drawing and _("READ") or _("WRITE"),10,true,p.ink,115,501,70,21)
    text("hint",_("Rotate to browse · SELECT to apply"),9,false,p.muted,10,549,280,17)
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
    if id=="undo" and not self:displayInfo().choice.available then return end
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
        if y>=self:S(324) and y<=self:S(348) then
            self:browse(x<self:S(150) and -1 or 1)
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
