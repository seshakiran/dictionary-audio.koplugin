--[[--
Tests that need no running KOReader.

The plugin modules are loaded for real; the KOReader modules they pull in are
stubbed below, just far enough to reproduce the behaviour under test — Widget's
event dispatch, and a PdfDocument that records what it was asked to write.

    luajit test.lua
]]

local unpack = unpack or table.unpack

package.path = "fingerink.koplugin/?.lua;" .. package.path

-- ------------------------------------------------------------------- stubs

--[[--
Widget and WidgetContainer, verbatim in behaviour from KOReader: a container
offers an event to its children first and only handles it itself if none of
them consumed it.
]]
package.preload["ui/widget/container/widgetcontainer"] = function()
    local Widget = {}

    function Widget:extend(subclass_prototype)
        local o = subclass_prototype or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end

    function Widget:new(o)
        o = self:extend(o)
        if o.init then o:init() end
        return o
    end

    function Widget:handleEvent(event)
        if self[event.handler] then
            return self[event.handler](self, unpack(event.args, 1, event.argc))
        end
    end

    local WidgetContainer = Widget:extend{}

    function WidgetContainer:propagateEvent(event)
        for _, widget in ipairs(self) do
            if widget:handleEvent(event) then return true end
        end
        return false
    end

    function WidgetContainer:handleEvent(event)
        if not self:propagateEvent(event) then
            return Widget.handleEvent(self, event)
        else
            return true
        end
    end

    return WidgetContainer
end

-- The real MovableContainer delegates drawing to its child and keeps its
-- current rectangle in `dimen`. This small stand-in is enough to exercise the
-- toolbar's hold-and-drag behavior without a running KOReader.
package.preload["ui/widget/container/movablecontainer"] = function()
    local WidgetContainer = require("ui/widget/container/widgetcontainer")
    local MovableContainer = WidgetContainer:extend{}

    function MovableContainer:init()
        self._moved_offset_x = self._moved_offset_x or 0
        self._moved_offset_y = self._moved_offset_y or 0
    end

    function MovableContainer:setMovedOffset(offset)
        self._moved_offset_x = offset.x
        self._moved_offset_y = offset.y
    end

    function MovableContainer:getMovedOffset()
        return { x = self._moved_offset_x, y = self._moved_offset_y }
    end

    function MovableContainer:paintTo(_, x, y)
        self._orig_x = x
        self._orig_y = y
        self.dimen.x = x + self._moved_offset_x
        self.dimen.y = y + self._moved_offset_y
    end

    function MovableContainer:_moveBy(dx, dy)
        if dx and dy then
            self._moved_offset_x = self._moved_offset_x + dx
            self._moved_offset_y = self._moved_offset_y + dy
        else
            self._moved_offset_x = 0
            self._moved_offset_y = 0
        end
        self.dimen.x = (self._orig_x or self.dimen.x) + self._moved_offset_x
        self.dimen.y = (self._orig_y or self.dimen.y) + self._moved_offset_y
    end

    function MovableContainer:onGesture(ges)
        local d = self.dimen
        local inside = ges.pos and ges.pos.x >= d.x and ges.pos.x < d.x + d.w
            and ges.pos.y >= d.y and ges.pos.y < d.y + d.h
        if ges.ges == "hold" and inside then
            self._moving = true
            self._move_start_x = ges.pos.x
            self._move_start_y = ges.pos.y
            return true
        elseif ges.ges == "hold_pan" and self._moving then
            return true
        elseif ges.ges == "hold_release" and self._moving then
            self:_moveBy(ges.pos.x - self._move_start_x,
                         ges.pos.y - self._move_start_y)
            self._moving = false
            return true
        end
    end

    return MovableContainer
end

package.preload["ui/event"] = function()
    local Event = {}
    function Event:new(handler, ...)
        local o = { handler = "on" .. handler, args = {...}, argc = select("#", ...) }
        setmetatable(o, self)
        self.__index = self
        return o
    end
    return Event
end

--- Consumes a tap only inside its own rectangle, as a real Button does.
package.preload["ui/widget/button"] = function()
    local WidgetContainer = require("ui/widget/container/widgetcontainer")
    local Button = WidgetContainer:extend{}
    function Button:init() self.dimen = self.dimen or { x = 0, y = 0, w = 0, h = 0 } end
    function Button:setText(text) self.text = text end
    function Button:setIcon(icon, width)
        self.icon = icon
        self.width = width
        self.text = nil
    end
    function Button:getSize()
        return { w = self.width, h = self.icon and self.icon_height or 30 }
    end
    function Button:onGesture(ges)
        local d = self.dimen
        if ges.ges == "tap" and ges.pos
           and ges.pos.x >= d.x and ges.pos.x < d.x + d.w
           and ges.pos.y >= d.y and ges.pos.y < d.y + d.h then
            self.callback()
            return true
        end
        if self.readonly then return end
        if ges.pos and ges.pos.x >= d.x and ges.pos.x < d.x + d.w
           and ges.pos.y >= d.y and ges.pos.y < d.y + d.h then
            return true
        end
    end
    return Button
end

package.preload["ui/widget/container/framecontainer"] = function()
    local WidgetContainer = require("ui/widget/container/widgetcontainer")
    local FrameContainer = WidgetContainer:extend{}
    function FrameContainer:getSize()
        local child = self[1]
        local size = child and child.getSize and child:getSize()
            or { w = 0, h = 0 }
        local extra = 2 * ((self.padding or 0) + (self.bordersize or 0))
        return { w = size.w + extra, h = size.h + extra }
    end
    return FrameContainer
end

package.preload["ui/widget/verticalgroup"] = function()
    local VerticalGroup = require("ui/widget/container/widgetcontainer"):extend{}
    function VerticalGroup:getSize()
        local width, height = 0, 0
        for _, child in ipairs(self) do
            local size = child:getSize()
            width = math.max(width, size.w)
            height = height + size.h
        end
        return { w = width, h = height }
    end
    return VerticalGroup
end

package.preload["ui/uimanager"] = function()
    return { _window_stack = {}, setDirty = function() end,
             show = function() end, close = function() end }
end

package.preload["ui/geometry"] = function()
    local Geom = {}
    function Geom:new(o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end
    return Geom
end

package.preload["ffi/blitbuffer"] = function()
    return { COLOR_WHITE = "white", COLOR_BLACK = "black" }
end

package.preload["device"] = function()
    return { screen = { getWidth = function() return 1000 end,
                        getHeight = function() return 1400 end,
                        scaleBySize = function(_, size) return size end } }
end

package.preload["ui/size"] = function()
    return { radius = { button = 2, window = 4 }, border = { window = 2 },
             padding = { small = 2, large = 8 } }
end

package.preload["gettext"] = function()
    return function(s) return s end
end

package.preload["logger"] = function()
    local noop = function() end
    return { warn = noop, info = noop, dbg = noop, err = noop }
end

package.preload["ui/font"] = function() return { getFace=function() return {} end } end
package.preload["ui/widget/textwidget"] = function()
    return { new=function(_,o)
        o.getSize=function() return {w=#o.text*7,h=18} end
        o.free=function() end; o.paintTo=function() end
        return o
    end }
end
require("device").screen.bb={paintRect=function() end}
local manager=require("ui/uimanager")
manager.scheduleIn=function() end
manager.unschedule=function() end

-- ------------------------------------------------------------------ runner

local failures, total = 0, 0

local function check(name, got, want)
    total = total + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %-44s got %-26s want %s",
                            name, tostring(got), tostring(want)))
    else
        print(string.format("ok   %-44s %s", name, tostring(got)))
    end
end

local function section(name)
    print("\n== " .. name .. " ==")
end

-- ------------------------------------------------- toolbar input forwarding

section("permanent hub, radial wheel and input forwarding")
do
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    local WidgetContainer = require("ui/widget/container/widgetcontainer")
    local InkBar = require("ink_bar")
    local log = {}
    local Reader=WidgetContainer:extend{}
    function Reader:onGesture() log[#log+1]="reader:gesture";return true end
    function Reader:onKeyPress() log[#log+1]="reader:key";return true end
    local Menu=WidgetContainer:extend{}
    function Menu:onGesture() log[#log+1]="menu:closed";return true end
    local Toast=WidgetContainer:extend{toast=true}
    function Toast:onGesture() log[#log+1]="toast:gesture" end
    local p={ drawing=false,eraser=false,highlighter=false,pen_width=4,ui={} }
    function p:onFingerInkUndo() log[#log+1]="undo" end
    function p:setTool(tool) self.drawing=true;self.eraser=tool=="eraser";self.highlighter=tool=="highlight";self.bar:update(true) end
    function p:setDrawing(on) self.drawing=on;self.bar:update(true) end
    function p:setPenWidth(w) self.pen_width=w end
    function p:setBarPosition(x,y) self.bar_position={x=x,y=y} end
    local bar=InkBar:new{plugin=p};p.bar=bar
    local reader,menu,toast=Reader:new{},Menu:new{},Toast:new{}
    UIManager._window_stack={{widget=reader},{widget=bar}}
    local function tap(x,y)
        log={};bar:handleEvent(Event:new("Gesture",{ges="tap",pos={x=x,y=y}}));return table.concat(log,",")
    end
    check("hub starts collapsed",bar.expanded,false)
    check("hub clearly shows read mode",bar.state,"READ")
    check("outside taps forward to reader",tap(10,10),"reader:gesture")
    tap(bar.cx,bar.cy);check("tap opens radial wheel",bar.expanded,true)
    for _,node in ipairs(bar.nodes) do
        check("wheel node fits screen: "..node.id,node.x-bar.node_r>=0 and node.x+bar.node_r<=1000 and node.y-bar.node_r>=0 and node.y+bar.node_r<=1400,true)
    end
    local pen=bar.nodes[1];tap(pen.x,pen.y)
    check("pen selection enables drawing",p.drawing,true)
    check("tool selection collapses wheel",bar.expanded,false)
    check("collapsed hub shows selected tool",bar.state,"PEN")
    check("hub remains reachable after collapse",bar:contains(bar.cx,bar.cy),true)
    tap(bar.cx,bar.cy);local marker=bar.nodes[2];tap(marker.x,marker.y)
    check("marker is selected directly",p.highlighter,true)
    check("hub updates marker state",bar.state,"MARK")
    tap(bar.cx,bar.cy);local undo=bar.nodes[4];check("undo runs its action",tap(undo.x,undo.y),"undo")
    check("undo keeps wheel open",bar.expanded,true)
    local width=bar.nodes[6];tap(width.x,width.y);check("width cycles",p.pen_width,7)
    local read=bar.nodes[7];tap(read.x,read.y);check("Read disables drawing",p.drawing,false)
    tap(bar.cx,bar.cy);local close=bar.nodes[8];tap(close.x,close.y)
    check("Close leaves hub visible",bar:contains(bar.cx,bar.cy),true)
    tap(bar.cx,bar.cy);check("closed wheel reopens with tap",bar.expanded,true)
    tap(10,10);check("outside tap closes expanded wheel",bar.expanded,false)
    UIManager._window_stack={{widget=reader},{widget=menu},{widget=bar}}
    check("page tap forwards to open menu",tap(10,10),"menu:closed")
    check("window below identifies dialog",bar:windowBelow(),menu)
    UIManager._window_stack={{widget=reader},{widget=bar},{widget=toast}}
    check("toast is skipped by forwarding",bar:windowBelow(),reader)
    local x,y=bar.cx,bar.cy
    bar:handleEvent(Event:new("Gesture",{ges="hold",pos={x=x,y=y}}))
    bar:handleEvent(Event:new("Gesture",{ges="hold_release",pos={x=x-80,y=y+90}}))
    check("hold-drag saves a new hub position",p.bar_position.x~=nil,true)
    check("moved hub hit testing follows position",bar:contains(x-80,y+90),true)
    bar:activate("collapse");check("collapse can always be repeated",bar.expanded,false)
end

section("batched Android display posting")
do
    local Refresh=require("ink_refresh")
    local pending,posts,removed={}, {},0
    local manager={ scheduleIn=function(_,delay,fn) pending[#pending+1]={delay,fn} end,
        unschedule=function() removed=removed+1 end }
    local screen={ refreshFast=function(_,x,y,w,h) posts[#posts+1]={x,y,w,h} end }
    local r=Refresh.new(manager,screen,true,30)
    for i=1,120 do r:add(i,10,10,20) end
    check("120 samples schedule one display post",#pending,1)
    check("samples do not immediately copy the screen",#posts,0)
    pending[1][2]()
    check("scheduled frame posts once",#posts,1)
    check("dirty region includes all samples",posts[1][3],129)
    r:add(200,10,10,10);r:flush()
    check("pen lift posts final pending pixels",#posts,2)
    check("flush cancels pending timer",removed,1)
    r:add(0,0,10,10);r:cancel();r:flush()
    check("cancel cannot post stale drawing",#posts,2)
end

-- ------------------------------------------------------- PDF ink annotations

section("PDF ink annotations (ADR-11)")

do
    local Store = require("ink_store")
    local InkPdf = require("ink_pdf")
    local Transform = require("ink_transform")

    --- A stroke as the plugin stores it: flat pairs, plus n, w and the
    --- view transform captured at endStroke.
    local function stroke(w, t, ...)
        local s = { n = select("#", ...) / 2, w = w, t = t }
        for i = 1, select("#", ...) do s[i] = (select(i, ...)) end
        return s
    end

    local function fakeDoc(opts)
        opts = opts or {}
        local doc = {
            is_pdf = opts.is_pdf ~= false,
            file = "/mnt/us/book.pdf",
            writes = 0,
            cache_resets = 0,
            annots = {},
        }
        function doc:_checkIfWritable() return opts.writable ~= false end
        function doc:writeDocument()
            if opts.write_fails then error("MuPDF: could not write document", 0) end
            self.writes = self.writes + 1
        end
        function doc:resetTileCacheValidity() self.cache_resets = self.cache_resets + 1 end
        doc._document = {
            openPage = function(_, pageno)
                local page = {}
                if not opts.no_ink_api then
                    function page:addInkAnnotation(strokes, color, width, opacity)
                        doc.annots[#doc.annots+1] = {
                            page = pageno, strokes = strokes, width = width,
                            color = color, opacity = opacity,
                        }
                    end
                end
                function page:close() self.closed = true end
                return page
            end,
        }
        return doc
    end

    local T1 = { z = 2, x = -30, y = -10 }   -- page = (screen + t) / 2

    -- Capture mappings through KOReader's real single/continuous-view API
    -- shape. Continuous view used to be rejected unconditionally.
    local sample = stroke(4, nil, 130, 110, 230, 210)
    local single_view = {
        getSinglePagePosition = function(_, pos)
            return { x = (pos.x - 30) / 2, y = (pos.y - 10) / 2,
                     page = 7, zoom = 2, rotation = 0 }
        end,
    }
    local t, page = Transform.fromStroke(single_view, sample)
    check("single-page transform page", page, 7)
    check("single-page transform x", t.x, -30)
    check("single-page transform y", t.y, -10)

    local scroll_view = {
        page_scroll = true,
        getScrollPagePosition = function(_, pos)
            if pos.y >= 300 and pos.y < 320 then return end -- page gap
            local p = pos.y < 300 and 4 or 5
            local y = p == 4 and pos.y or pos.y - 320
            return { x = pos.x / 2, y = y / 2, page = p,
                     zoom = 2, rotation = 0 }
        end,
    }
    sample = stroke(4, nil, 20, 20, 40, 40)
    t, page = Transform.fromStroke(scroll_view, sample)
    check("continuous-view transform page", page, 4)
    check("continuous-view transform captured", t.z, 2)
    sample = stroke(4, nil, 20, 290, 40, 330)
    local rejected, _, block = Transform.fromStroke(scroll_view, sample)
    check("cross-page stroke rejected", rejected, nil)
    check("cross-page reason", block, "page_boundary")
    sample = stroke(4, nil, 20, 20, 40, 40)
    single_view.getSinglePagePosition = function(_, pos)
        return { x = pos.x, y = pos.y, page = 7, zoom = 1, rotation = 90 }
    end
    rejected, _, block = Transform.fromStroke(single_view, sample)
    check("rotated stroke rejected", rejected, nil)
    check("rotated reason", block, "rotation")

    -- Conversion is ReaderView:getSinglePagePosition, inverted.
    local store = Store.new()
    store:add(7, stroke(4, T1, 130, 110, 230, 210))
    local doc = fakeDoc()
    local written, skipped = InkPdf.save({ document = doc }, store, {7})
    check("one stroke written", written, 1)
    check("none skipped", skipped, 0)
    check("one annotation created", #doc.annots, 1)
    check("on the right page", doc.annots[1].page, 7)
    check("first point x", doc.annots[1].strokes[1][1].x, (130 - 30) / 2)
    check("first point y", doc.annots[1].strokes[1][1].y, (110 - 10) / 2)
    check("last point x", doc.annots[1].strokes[1][2].x, (230 - 30) / 2)
    check("border width is pen width / zoom", doc.annots[1].width, 2)
    check("ink is black", doc.annots[1].color.r + doc.annots[1].color.g
                          + doc.annots[1].color.b, 0)
    check("written once, incrementally", doc.writes, 1)
    check("tile cache invalidated", doc.cache_resets, 1)
    check("saved strokes leave the store", store:get(7), nil)

    -- One annotation per pen width, not per stroke.
    store = Store.new()
    store:add(1, stroke(4, T1, 0, 0, 10, 10))
    store:add(1, stroke(4, T1, 20, 20, 30, 30))
    store:add(1, stroke(7, T1, 40, 40, 50, 50))
    doc = fakeDoc()
    check("all three written", (InkPdf.save({ document = doc }, store, {1})), 3)
    check("bucketed into two annotations", #doc.annots, 2)
    check("first holds two ink lists", #doc.annots[1].strokes, 2)
    check("second holds one", #doc.annots[2].strokes, 1)

    -- Marker and pen of equal width must remain separate PDF annotations.
    store = Store.new()
    local marker = stroke(4, T1, 20, 20, 30, 30)
    marker.tool = "highlight"
    store:add(1, stroke(4, T1, 0, 0, 10, 10))
    store:add(1, marker)
    doc = fakeDoc()
    check("pen and marker both export", (InkPdf.save({ document = doc }, store, {1})), 2)
    check("marker uses separate annotation", #doc.annots, 2)
    check("pen remains opaque", doc.annots[1].opacity, 1)
    check("marker remains translucent", doc.annots[2].opacity, 0.25)
    check("marker exports in yellow", doc.annots[2].color.r, 1)

    -- Strokes from a view with no page mapping stay put rather than landing wrong.
    store = Store.new()
    store:add(3, stroke(4, T1, 0, 0, 10, 10))
    store:add(3, stroke(4, nil, 20, 20, 30, 30))
    doc = fakeDoc()
    local skip_reasons
    written, skipped, skip_reasons = InkPdf.save({ document = doc }, store, {3})
    check("mappable stroke written", written, 1)
    check("unmappable stroke skipped", skipped, 1)
    check("unmapped legacy reason", skip_reasons.legacy, 1)
    check("skipped stroke kept", #store:get(3), 1)
    check("and it is the untransformed one", store:get(3)[1].t, nil)

    -- A failed write must lose no ink.
    store = Store.new()
    store:add(2, stroke(4, T1, 0, 0, 10, 10))
    doc = fakeDoc{ write_fails = true }
    local reason
    written, reason = InkPdf.save({ document = doc }, store, {2})
    check("failure reported", written, nil)
    check("actionable write reason", reason,
          "KOReader could not save changes to this PDF. Check that the file is writable and is not damaged or password-protected, then try again.")
    check("ink still in the store", #store:get(2), 1)
    check("no cache reset on failure", doc.cache_resets, 0)

    -- An older build without the MuPDF ink API fails before writing anything.
    store = Store.new()
    store:add(2, stroke(4, T1, 0, 0, 10, 10))
    doc = fakeDoc{ no_ink_api = true }
    written, reason = InkPdf.save({ document = doc }, store, {2})
    check("refused without the ink API", written, nil)
    check("explains why", reason,
          "PDF ink export requires KOReader 2026.07 or newer. Update KOReader, restart it, then try again.")
    check("ink kept", #store:get(2), 1)
    check("nothing written", doc.writes, 0)

    -- Documents that cannot take annotations are refused up front.
    store = Store.new()
    store:add(1, stroke(4, T1, 0, 0, 10, 10))
    written, reason = InkPdf.save({ document = fakeDoc{ is_pdf = false } }, store, {1})
    check("epub refused", written, nil)
    check("epub reason", reason,
          "PDF ink export only works with PDF files. Open a PDF, then try again.")
    written, reason = InkPdf.save({ document = fakeDoc{ writable = false } }, store, {1})
    check("read-only pdf refused", written, nil)
    check("read-only reason", reason,
          "KOReader cannot modify this PDF. Check its file permissions, or copy it to writable local storage, then try again.")
    check("ink untouched by either", #store:get(1), 1)

    -- Whole-document save walks every inked page, in order, writing once.
    store = Store.new()
    store:add(9, stroke(4, T1, 0, 0, 10, 10))
    store:add(2, stroke(4, T1, 0, 0, 10, 10))
    store:add(5, stroke(4, T1, 0, 0, 10, 10))
    check("page list is sorted", table.concat(store:pageList(), ","), "2,5,9")
    doc = fakeDoc()
    check("every page written", (InkPdf.save({ document = doc }, store, store:pageList())), 3)
    check("one annotation per page", #doc.annots, 3)
    check("in page order", doc.annots[1].page .. "," .. doc.annots[2].page
                           .. "," .. doc.annots[3].page, "2,5,9")
    check("store emptied", tostring(store:isEmpty()), "true")
    check("a single incremental write", doc.writes, 1)

    -- Nothing to save is not an error.
    doc = fakeDoc()
    written, skipped = InkPdf.save({ document = doc }, Store.new(), {4})
    check("nothing written", written, 0)
    check("nothing skipped", skipped, 0)
    check("no pointless write", doc.writes, 0)
end

section("notebook, highlight and eraser")
do
    local Store = require("ink_store")
    local Notebook = require("ink_notebook")
    local Render = require("ink_render")
    local store = Store.new()
    store:add(9, { n = 2, w = 4, sw = 600, sh = 800, 10, 20, 200, 20 })
    store:add(2, { n = 1, w = 24, tool = "highlight", 20, 20 })
    local notes = { [3] = '<script>alert("x")</script> & note', [9] = "Title\nBody" }
    check("notebook merges and sorts typed and ink pages", table.concat(Notebook.pages(store, notes), ","), "2,3,9")
    check("eraser hits between sparse samples", Store.hit(store:get(9), 100, 20, 1), 1)
    check("eraser includes stroke width", Store.hit(store:get(9), 100, 23, 1), 1)
    check("eraser does not hit distant segments", Store.hit(store:get(9), 100, 40, 1), nil)
    local html = Notebook.html('book<&>.epub', store, notes)
    check("HTML escapes book names", html:find('book&lt;&amp;&gt;.epub', 1, true) ~= nil, true)
    check("HTML escapes typed content", html:find('<script>', 1, true), nil)
    check("HTML preserves original canvas", html:find('viewBox="0 0 600 800"', 1, true) ~= nil, true)
    check("HTML includes handwriting points", html:find('10,20 200,20', 1, true) ~= nil, true)
    check("HTML includes highlight opacity", html:find('opacity="0.25"', 1, true) ~= nil, true)
    local path = os.tmpname()
    check("notebook export succeeds", not not Notebook.export(path, 'book', store, notes), true)
    local f = assert(io.open(path, 'rb'))
    check("export includes note text", f:read('*a'):find('Title', 1, true) ~= nil, true)
    f:close(); os.remove(path)
    check("export failure is reported", Notebook.export('/does-not-exist/notebook.html', 'book', store, notes), nil)
    local pixels = {}
    local bb = { paintRect = function(_, x, y, w, h)
        for px = x, x + w - 1 do for py = y, y + h - 1 do pixels[px .. ',' .. py] = true end end
    end }
    local mark = { n = 2, w = 24, tool = "highlight", 20, 20, 80, 20 }
    Render.stroke(bb, mark, 0, 0, "black")
    local count = 0
    for _ in pairs(pixels) do count = count + 1 end
    check("highlighter leaves most underlying pixels intact", count > 0 and count < 200, true)
    local first = count
    Render.stroke(bb, mark, 0, 0, "black")
    count = 0; for _ in pairs(pixels) do count = count + 1 end
    check("highlighter replay does not darken overlaps", count, first)
end

section("stylus capture lifecycle and notebook controls")
do
    local Device = require("device")
    local Capture = require("ink_capture")
    local old_input = Device.input
    local original = function() return { "gesture" } end
    local previous = function() return "previous" end
    Device.input = { gesture_detector = { feedEvent = original }, stylus_callback = previous,
        registerStylusCallback = function(self, cb) self.stylus_callback = cb end }
    local consumed = false
    check("capture installs with pen API", Capture:install(function() return false end, function() return consumed end), true)
    check("unhandled pen chains existing plugin", Device.input:stylus_callback({}), "previous")
    consumed = true
    check("handled pen is consumed once", Device.input:stylus_callback({}), true)
    check("drawing suppresses gestures", #Device.input.gesture_detector:feedEvent({}), 0)
    Capture:remove()
    check("capture restores previous pen callback", Device.input.stylus_callback, previous)
    check("capture restores gesture handler", Device.input.gesture_detector.feedEvent, original)
    Device.input = old_input

    package.preload["ui/widget/confirmbox"] = function() return require("ui/widget/container/widgetcontainer") end
    package.preload["ui/widget/notification"] = function() return require("ui/widget/container/widgetcontainer") end
    package.preload["dispatcher"] = function() return {} end
    package.preload["ffi/util"] = function() return { template = function(s, ...)
        local args = {...}; return (s:gsub('%%(%d+)', function(i) return tostring(args[tonumber(i)]) end))
    end } end
    local FingerInk = dofile('fingerink.koplugin/main.lua')
    local Store = require("ink_store")
    local settings = {}
    local last_event
    local p = FingerInk:extend{
        notes = { [3] = "Typed note" }, store = Store.new(), drawing = false,
        pen_width = 4, view = { state = { page = 1 } },
        ui = { document = { is_pdf = false },
            doc_settings = { saveSetting = function(_, k, v) settings[k] = v end,
                delSetting = function(_, k) settings[k] = nil end },
            handleEvent = function(_, e) last_event = e end },
    }
    p.store:add(5, { n = 2, w = 4, 10, 10, 100, 100 })
    p:cycleTool(); check("pen cycles to marker", p.highlighter, true)
    p.drawing = true
    p:cycleTool(); check("marker cycles to eraser", p.eraser, true)
    p:cycleTool(); check("eraser cycles to pen", p.eraser or p.highlighter, false)
    p.drawing = false
    local items = p:notebookItems()
    items[2].sub_item_table[1].callback()
    check("notebook navigation uses correct page closure", last_event.args[1], 5)
    p:onSaveSettings()
    check("typed notes saved independently of ink", settings.fingerink_notes[3], "Typed note")
    p.highlighter = true
    p:startStroke(10, 10)
    check("new stroke records highlighter", p.stroke.tool, "highlight")
    check("new stroke records canvas dimensions", p.stroke.sw, 1000)
    p.view.state.page = 2
    p:endStroke()
    check("page change cannot put stroke on wrong page", p.store:get(2), nil)
    p.highlighter = false
    p.drawing = true
    p.dialogOnTop = function() return false end
    p.inBar = function(_, x) return x < 100 end
    Device.screen.getRotationMode = function() return 0 end
    Device.screen.DEVICE_ROTATED_UPRIGHT = 0
    p.stylus_only = true
    p.contacts, p.n_contacts, p.passthrough = {}, 0, false
    p:onTouchFrame({ {slot=0,id=1,x=500,y=500}, {slot=1,id=2,x=600,y=600} })
    check("palm cannot create a stroke", p.stroke, nil)
    check("palm cannot turn pages", p:onTouchFrame({ {slot=0,id=-1}, {slot=1,id=-1} }), false)
    check("toolbar stays usable with stylus only", p:onTouchFrame({ {slot=0,id=3,x=50,y=500} }), true)
    check("toolbar release passes through", p:onTouchFrame({ {slot=0,id=-1} }), true)
    p.refreshBox = function() end
    Device.screen.bb = { paintRect = function() end }
    p:onStylusEvent({slot=4,id=4,tool=1,x=300,y=300})
    check("native pen starts stroke", p.stroke.n, 1)
    p:onTouchFrame({ {slot=0,id=6,x=600,y=600}, {slot=0,id=-1} })
    check("palm lift does not finish pen stroke", p.stroke.n, 1)
    p:onStylusEvent({slot=4,id=-1,tool=1})
    check("native pen release saves stroke", #p.store:get(2), 1)
    check("native pen state cleared", p.pen_down, false)
end

section("brush merging preserves stroke coverage")
do
    local Render=require("ink_render")
    local function canvas()
        local pixels,calls={},0
        return {paintRect=function(_,x,y,w,h)
            calls=calls+1
            for px=x,x+w-1 do for py=y,y+h-1 do pixels[px..","..py]=true end end
        end},pixels,function() return calls end
    end
    for _,line in ipairs({{20,20,120,30},{120,30,20,20},{40,80,20,10},{80,40,10,20},{10,10,10,80},{10,10,80,10},{10,10,10,10}}) do
        local bb,actual=canvas()
        Render.segment(bb,line[1],line[2],line[3],line[4],4,"black")
        local expected={};local steps=math.max(math.abs(line[3]-line[1]),math.abs(line[4]-line[2]))
        for i=0,steps do
            local t=steps==0 and 0 or i/steps
            local x=math.floor(line[1]+(line[3]-line[1])*t)-2
            local y=math.floor(line[2]+(line[4]-line[2])*t)-2
            for px=x,x+3 do for py=y,y+3 do expected[px..","..py]=true end end
        end
        local matches=true
        for pixel in pairs(expected) do if not actual[pixel] then matches=false end end
        for pixel in pairs(actual) do if not expected[pixel] then matches=false end end
        check("merged brush preserves coverage "..table.concat(line,","),matches,true)
    end
    local bb,pixels,count=canvas()
    Render.segment(bb,0,0,100,0,4,"black")
    check("horizontal stroke uses one blitter call",count(),1)
end

-- ----------------------------------------------------------------- summary

print("")
if failures == 0 then
    print(total .. " checks, all passed")
else
    print(total .. " checks, " .. failures .. " FAILED")
end
os.exit(failures == 0 and 0 or 1)
