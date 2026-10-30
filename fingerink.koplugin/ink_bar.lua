-- Direct toolbar: each tool activates on its first tap; no pending selection.
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
local floor=math.floor
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
        line=rgb(163,177,197),soft=rgb(234,240,249),white=rgb(255),
        pen=rgb(35,88,184),highlight=rgb(148,99,0),eraser=rgb(183,68,55),read=rgb(5,111,111),action=rgb(35,88,184)},
    mono={shell=rgb(255),panel=rgb(255),ink=rgb(0),muted=rgb(0),line=rgb(0),soft=rgb(255),
        white=rgb(255),pen=rgb(0),highlight=rgb(0),eraser=rgb(0),read=rgb(0),action=rgb(0)},
}
local NAMES={read=_("Read"),pen=_("Pen"),highlight=_("Highlight"),eraser=_("Erase")}
function InkBar:displayInfo()
    local p,id=self.plugin,self:activeId()
    local input=p.stylus_only and _("Pen only") or _("Pen + finger")
    local width=tostring(id=="highlight" and 24 or p.pen_width or 4).." px"
    local help={read=_("Turn pages or hold a word to look it up."),
        pen=_("Write directly on the book page."),
        highlight=_("Draw a broad highlight over the page."),
        eraser=_("Touch handwriting to erase a whole stroke.")}
    local detail=id=="read" and _("Writing off") or (id=="eraser" and input or width.." · "..input)
    return {id=id,name=NAMES[id],status=NAMES[id].._(" active"),detail=detail,help=help[id]}
end
function InkBar:canUndo()
    local p=self.plugin
    if not p.store or not p.currentPage then return false end
    local ink=p.store:get(p:currentPage())
    return ink~=nil and #ink>0
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
    self.scale=math.min(self.base_scale,(Screen:getWidth()-16)/360,(Screen:getHeight()-16)/254)
    self.tools={"read","pen","highlight","eraser"}
    self.color_mode=not not (Device.hasColorScreen and Device:hasColorScreen() and BB.ColorRGB32 and BB.TYPE_BBRGB32)
    self.palette=THEMES[self.color_mode and "color" or "mono"];self.color_cache={}
    self.expanded=false;self.labels={}
    self.hub_w,self.hub_h=self:S(164),self:S(52)
    self.position=self.position or {x=self.side=="left" and 8 or Screen:getWidth()-self.hub_w-8,
        y=round(Screen:getHeight()/2-self.hub_h/2)}
    self:layout();self:update(false)
end
function InkBar:S(value) return math.max(1,round(value*self.scale)) end
function InkBar:activeId()
    local p=self.plugin
    return not p.drawing and "read" or p.eraser and "eraser" or p.highlighter and "highlight" or "pen"
end
function InkBar:clampPosition(x,y)
    return round(clamp(x,2,Screen:getWidth()-self.hub_w-2)),round(clamp(y,2,Screen:getHeight()-self.hub_h-2))
end
function InkBar:layout()
    local x,y=self:clampPosition(self.position.x,self.position.y)
    local w,h=self.hub_w,self.hub_h
    if self.expanded then
        w,h=self:S(360),self:S(254)
        x=round(clamp(x+self.hub_w/2-w/2,4,Screen:getWidth()-w-4))
        y=round(clamp(y+self.hub_h/2-h/2,4,Screen:getHeight()-h-4))
    end
    self.dimen=Geom:new{x=x,y=y,w=w,h=h}
    self.cx,self.cy=x+round(w/2),y+round(h/2)
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
    self.expanded=on
    if on then self.plugin:abortStroke() end
    self:layout();self:update(false)
    -- Refresh both the old and the new bounds; closing performs a clean eink
    -- refresh so the reader under the panel cannot retain toolbar outlines.
    local damage=union(old,self.dimen)
    UIManager:setDirty(self.plugin.ui,on and "ui" or "full",damage)
    UIManager:setDirty(self,"ui",damage)
end
function InkBar:freeSurface()
    if self.surface then self.surface:free();self.surface=nil end
end
function InkBar:update(refresh)
    local p=self.plugin
    local info=self:displayInfo()
    self.state=info.name;self.subtitle=info.detail;self.active_label=info.status
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
function InkBar:render()
    local d,p,info=self.dimen,self.palette,self:displayInfo()
    self.info=info
    local kind=self.color_mode and BB.TYPE_BBRGB32 or Screen.bb:getType()
    local bb=BB.new(d.w,d.h,kind);self.surface=bb
    self:rect(bb,0,0,d.w,d.h,p.line,self:S(10))
    local edge=self:S(1)
    self:rect(bb,edge,edge,d.w-2*edge,d.h-2*edge,p.shell,self:S(9))
    local function box(x,y,w,h,color,radius)
        self:rect(bb,self:S(x),self:S(y),self:S(w),self:S(h),color,radius and self:S(radius))
    end
    local function text(key,value,size,bold,color,x,y,w,h,align)
        self:text(self:textTarget(bb),key,value,size,bold,self:color(color),self:S(x),self:S(y),self:S(w),self:S(h),align)
    end
    local active=p[info.id]
    if not self.expanded then
        box(2,2,160,48,active,8)
        text("hub",info.status.." ▸",13,true,p.white,8,5,148,23)
        text("hub_detail",info.detail,10,false,p.white,8,29,148,16)
        return
    end
    text("title",_("PAGESCRIBE"),11,true,p.ink,12,12,190,24,"left")
    box(274,10,74,28,p.line,5);box(275,11,72,26,p.panel,4)
    text("collapse",_("Hide ▸"),11,true,p.ink,277,11,68,26)
    text("status",info.status.." · "..info.detail,13,true,active,12,45,336,24,"left")
    text("help",info.help,11,false,p.muted,12,72,336,20,"left")
    for i,id in ipairs(self.tools) do
        local x=12+(i-1)*86
        local selected=id==info.id
        box(x,101,78,66,selected and p[id] or p.line,6)
        if not selected then box(x+1,102,76,64,p.panel,5) end
        local ink=selected and p.white or p.ink
        text("selected_"..id,selected and _("✓ ACTIVE") or _("Tap to use"),9,selected,ink,x+3,107,72,20)
        text("tool_"..id,NAMES[id],12,true,ink,x+3,133,72,25)
    end
    local actions={{id="undo",label=_("Undo"),enabled=self:canUndo()},
        {id="note",label=_("Notes"),enabled=true},{id="settings",label=_("Settings"),enabled=true}}
    for i,action in ipairs(actions) do
        local x=12+(i-1)*114
        box(x,180,108,40,p.line,5);box(x+1,181,106,38,action.enabled and p.panel or p.soft,4)
        text(action.id,action.label,12,action.enabled,action.enabled and p.ink or p.muted,x+4,185,100,30)
        if not action.enabled then text("no_undo",_("No ink"),9,false,p.muted,x+4,222,100,16) end
    end
    text("hint",_("Tap a tool to use it immediately"),10,false,p.muted,118,229,230,17)
end

function InkBar:paintTo(bb)
    if not self.surface then self:render() end
    local d=self.dimen
    bb:blitFrom(self.surface,d.x,d.y,0,0,d.w,d.h)
end
function InkBar:activate(id)
    local p=self.plugin
    if id=="collapse" then self:setExpanded(false)
    elseif id=="undo" then if self:canUndo() then p:onFingerInkUndo();self:update(true) end
    elseif id=="note" then self:setExpanded(false);p:openNotes()
    elseif id=="settings" then self:setExpanded(false);p:showToolbarSettings()
    elseif id=="read" then p:setDrawing(false)
    else p:setTool(id) end
end
function InkBar:onGesture(ges)
    local pos=ges.pos
    if not pos then return end
    local inside=self:contains(pos.x,pos.y)
    if self.expanded then
        if ges.ges~="tap" then return inside or nil end
        if not inside then self:setExpanded(false);return true end
        local x=(pos.x-self.dimen.x)/self.scale
        local y=(pos.y-self.dimen.y)/self.scale
        if x>=274 and x<348 and y>=10 and y<38 then self:activate("collapse")
        elseif y>=101 and y<167 then
            for i,id in ipairs(self.tools) do
                local bx=12+(i-1)*86
                if x>=bx and x<bx+78 then self:activate(id);break end
            end
        elseif y>=180 and y<220 then
            for i,id in ipairs({"undo","note","settings"}) do
                local bx=12+(i-1)*114
                if x>=bx and x<bx+108 then self:activate(id);break end
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
