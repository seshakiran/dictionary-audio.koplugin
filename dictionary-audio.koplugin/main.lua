local DataStorage=require("datastorage")
local Device=require("device")
local Notification=require("ui/widget/notification")
local UIManager=require("ui/uimanager")
local WidgetContainer=require("ui/widget/container/widgetcontainer")
local _=require("gettext")
-- Use file-local modules to avoid collisions with other plugins.
local directory=debug.getinfo(1,"S").source:match("^@(.*/)")
local Index=dofile(directory.."audio_index.lua")
local Player=dofile(directory.."audio_player.lua")
local Audio=WidgetContainer:extend{name="dictionary_audio",is_doc_only=true}
function Audio:init()
    self.path=DataStorage:getDataDir().."/data/dict/english-audio/english"
    if not Device:isAndroid() or not self.ui.dictionary or not self.ui.dictionary.addToDictButtons then return end
    local android=require("android")
    self.player=Player.new(android,require("ffi"))
    self.ui.dictionary:addToDictButtons{
        id="offline_english_audio",text=_("Hear English"),menu_text=_("Offline English pronunciation"),
        conditional=true,row_group="offline_audio",
        callback=function(popup) self:pronounce(popup.lookupword or popup.word) end,
    }
end
function Audio:pronounce(word)
    if not self.index then
        local err
        self.index,err=Index.read(self.path..".tsv")
        if not self.index then self:notify(_("English audio pack not found in koreader/data/dict/english-audio."));return end
    end
    local entry=Index.find(self.index,word)
    if not entry then self:notify(_("No offline recording for this word."));return end
    local ok,err=self.player:play(self.path..".pack",entry[1],entry[2])
    if not ok then self:notify(tostring(err)) end
end
function Audio:notify(text) UIManager:show(Notification:new{text=text}) end
function Audio:onCloseDocument() if self.player then self.player:stop() end end
return Audio
