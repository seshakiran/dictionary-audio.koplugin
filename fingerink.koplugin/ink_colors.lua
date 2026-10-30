-- Serializable palette IDs keep saved strokes and exports safe and portable.
local _=require("gettext")
local Colors={list={
    {id="black",name=_("Black"),rgb={0,0,0}},
    {id="blue",name=_("Blue"),rgb={35,88,184}},
    {id="red",name=_("Red"),rgb={198,45,52}},
    {id="green",name=_("Green"),rgb={15,128,84}},
    {id="purple",name=_("Purple"),rgb={132,63,186}},
    {id="orange",name=_("Orange"),rgb={224,118,0}},
    {id="pink",name=_("Pink"),rgb={224,65,136}},
    {id="yellow",name=_("Yellow"),rgb={213,170,0}},
}}
local by_id={}
for _,entry in ipairs(Colors.list) do by_id[entry.id]=entry end
function Colors.valid(id) return by_id[id]~=nil end
function Colors.get(id,fallback) return by_id[id] or by_id[fallback] or by_id.black end
function Colors.hex(id,fallback)
    local c=Colors.get(id,fallback).rgb
    return string.format("#%02x%02x%02x",c[1],c[2],c[3])
end
function Colors.pdf(id,fallback)
    local c=Colors.get(id,fallback).rgb
    return {r=c[1]/255,g=c[2]/255,b=c[3]/255}
end
return Colors
