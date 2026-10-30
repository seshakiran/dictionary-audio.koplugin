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
local updater=dofile(directory.."pluginupdater.lua").new{
    repository="seshakiran/dictionary-audio.koplugin",branch="main",folder="dictionary-audio.koplugin",
}
local Audio=WidgetContainer:extend{name="dictionary_audio",is_doc_only=true}
function Audio:init()
    self.ui.dictionary_audio=self
    self.root=DataStorage:getDataDir().."/data/dict/"
    self.indices={}
    local legacy=G_reader_settings:readSetting("dictionary_audio_enabled")
    self.english_enabled=G_reader_settings:readSetting("dictionary_audio_english_enabled")
    self.spanish_enabled=G_reader_settings:readSetting("dictionary_audio_spanish_enabled")
    if self.english_enabled==nil then self.english_enabled=legacy~=false end
    if self.spanish_enabled==nil then self.spanish_enabled=legacy~=false end
    self.spanish_rate=G_reader_settings:readSetting("dictionary_audio_spanish_rate") or 0.85
    if self.spanish_rate~=1 and self.spanish_rate~=0.85 and self.spanish_rate~=0.7 then self.spanish_rate=0.85 end
    self.ui.menu:registerToMainMenu(self)
    if not Device:isAndroid() or not self.ui.dictionary or not self.ui.dictionary.addToDictButtons then return end
    local android=require("android")
    self.player=Player.new(android,require("ffi"))
    self.ui.dictionary:addToDictButtons{
        id="offline_english_audio",text=_("Hear English"),menu_text=_("Offline English pronunciation"),
        conditional=true,row_group="offline_audio",show_func=function() return self.english_enabled end,
        callback=function(popup) self:pronounce(popup.lookupword or popup.word) end,
    }
    self.ui.dictionary:addToDictButtons{
        id="offline_spanish_audio",text=_("Hear Spanish"),menu_text=_("Offline Spanish pronunciation"),
        conditional=true,row_group="offline_audio",show_func=function() return self.spanish_enabled end,
        callback=function(popup) self:showSpanish(popup.lookupword or popup.word) end,
    }
end
function Audio:pronounce(word)
    self:play("english",word)
end
function Audio:play(language,word)
    if (language=="english" and self.english_enabled==false) or (language=="spanish" and self.spanish_enabled==false) then return end
    local path=self.root..(language=="spanish" and "spanish-neural-audio/spanish" or "english-audio/english")
    if not self.indices[language] then
        self.indices[language]=Index.read(path..".tsv")
        if not self.indices[language] then self:notify(_("Offline audio pack not found: ")..language);return end
    end
    local entry=Index.find(self.indices[language],word)
    if not entry then self:notify(_("No offline recording for this word."));return end
    local ok,err=self.player:play(path..".pack",entry[1],entry[2],language=="spanish" and (self.spanish_rate or 0.85) or 1.0)
    if not ok then self:notify(tostring(err)) else self.playing_language=language end
end
function Audio:showSpanish(word)
    if self.spanish_enabled==false then return end
    if not self.translations then
        self.translations=Index.translations(self.root.."spanish-neural-audio/spanish-translations.tsv")
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
function Audio:rateItem(label,rate)
    return {text=label,radio=true,checked_func=function() return self.spanish_rate==rate end,
        callback=function()
            self.spanish_rate=rate
            G_reader_settings:saveSetting("dictionary_audio_spanish_rate",rate)
        end}
end
function Audio:languageItem(label,language)
    local field=language.."_enabled"
    return {text=label,checked_func=function() return self[field] end,
        callback=function()
            self[field]=not self[field]
            G_reader_settings:saveSetting("dictionary_audio_"..field,self[field])
            if not self[field] and self.playing_language==language and self.player then self.player:stop() end
        end}
end
function Audio:addToMainMenu(items)
    items.dictionary_audio={text=_("Dictionary audio"),sorting_hint="more_tools",sub_item_table={
        self:languageItem(_("English pronunciation"),"english"),
        self:languageItem(_("Spanish pronunciation"),"spanish"),
        {text=_("Spanish speech speed"),enabled_func=function() return self.spanish_enabled end,sub_item_table={
            self:rateItem(_("Normal"),1.0),self:rateItem(_("Slower"),0.85),self:rateItem(_("Very slow"),0.7),
        },help_text=_("Changes playback speed while preserving the voice's pitch. Applies to the next Spanish word; English playback stays normal.")},
        updater:menuItem(),
    }}
end
function Audio:showSettings()
    local ButtonDialog=require("ui/widget/buttondialog")
    local dialog
    local function selected(on,label) return (on and "✓ " or "")..label end
    local function change(callback)
        return function() UIManager:close(dialog);callback();self:showSettings() end
    end
    local rates={}
    for _,entry in ipairs({{_("Normal"),1},{_("Slower"),0.85},{_("Very slow"),0.7}}) do
        local label,rate=entry[1],entry[2]
        rates[#rates+1]={text=selected(self.spanish_rate==rate,label),enabled=self.spanish_enabled,
            callback=change(self:rateItem(label,rate).callback)}
    end
    dialog=ButtonDialog:new{title=_("Dictionary audio"),buttons={
        {{text=_("English audio: ")..(self.english_enabled and _("ON") or _("OFF")),
            callback=change(self:languageItem("","english").callback)}},
        {{text=_("Spanish audio: ")..(self.spanish_enabled and _("ON") or _("OFF")),
            callback=change(self:languageItem("","spanish").callback)}},
        {{text=_("Spanish pronunciation speed"),enabled=false}},rates,
        {{text=_("Done"),callback=function() UIManager:close(dialog) end}},
    }}
    UIManager:show(dialog)
end
function Audio:onCloseDocument() if self.player then self.player:stop() end end
return Audio
