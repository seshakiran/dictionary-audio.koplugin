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
    self.root=DataStorage:getDataDir().."/data/dict/"
    self.indices={}
    if not Device:isAndroid() or not self.ui.dictionary or not self.ui.dictionary.addToDictButtons then return end
    local android=require("android")
    self.player=Player.new(android,require("ffi"))
    self.ui.dictionary:addToDictButtons{
        id="offline_english_audio",text=_("Hear English"),menu_text=_("Offline English pronunciation"),
        conditional=true,row_group="offline_audio",
        callback=function(popup) self:pronounce(popup.lookupword or popup.word) end,
    }
    self.ui.dictionary:addToDictButtons{
        id="offline_spanish_audio",text=_("Hear Spanish"),menu_text=_("Offline Spanish pronunciation"),
        conditional=true,row_group="offline_audio",
        callback=function(popup) self:showSpanish(popup.lookupword or popup.word) end,
    }
end
function Audio:pronounce(word)
    self:play("english",word)
end
function Audio:play(language,word)
    local path=self.root..language.."-audio/"..language
    if not self.indices[language] then
        self.indices[language]=Index.read(path..".tsv")
        if not self.indices[language] then self:notify(_("Offline audio pack not found: ")..language);return end
    end
    local entry=Index.find(self.indices[language],word)
    if not entry then self:notify(_("No offline recording for this word."));return end
    local ok,err=self.player:play(path..".pack",entry[1],entry[2])
    if not ok then self:notify(tostring(err)) end
end
function Audio:showSpanish(word)
    if not self.translations then
        self.translations=Index.translations(self.root.."spanish-audio/spanish-translations.tsv")
        if not self.translations then self:notify(_("Spanish audio pack not found."));return end
    end
    local choices=self.translations[tostring(word or ""):lower()]
    if not choices or #choices==0 then self:play("spanish",word);return end
    local Menu=require("ui/widget/menu")
    local items={}
    for _,choice in ipairs(choices) do
        local term=choice
        items[#items+1]={text=term,callback=function() self:play("spanish",term) end}
    end
    UIManager:show(Menu:new{
        title=_("Hear Spanish: ")..tostring(word),
        item_table=items,width=math.floor(Device.screen:getWidth()*0.8),
    })
end

function Audio:notify(text) UIManager:show(Notification:new{text=text}) end
function Audio:onCloseDocument() if self.player then self.player:stop() end end
return Audio
