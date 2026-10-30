local Index=dofile('dictionary-audio.koplugin/audio_index.lua')
local fpath=os.tmpname()
local f=assert(io.open(fpath,'wb'));f:write('hello\t0\t120\nnew_york\t120\t80\ninvalid\t-1\t20\nempty\t3\t0\n');f:close()
local index=assert(Index.read(fpath));os.remove(fpath)
assert(Index.find(index,' HELLO ')[2]==120)
assert(Index.find(index,'new york')[1]==120)
assert(Index.find(index,'missing')==nil)
assert(index.invalid==nil and index.empty==nil)
assert(Index.read('/does-not-exist/audio.tsv')==nil)
local Player=dofile('dictionary-audio.koplugin/audio_player.lua')
local calls, globals,deleted,exception={},0,0,false
local env={}
env[0]={
 ExceptionCheck=function() return exception and 1 or 0 end,
 ExceptionClear=function() exception=false end,
 FindClass=function(_,class) return class end,
 GetMethodID=function(_,class,name) return name end,
 NewObject=function(_,class) return class end,
 NewGlobalRef=function(_,ref) globals=globals+1;return ref end,
 DeleteGlobalRef=function() deleted=deleted+1 end,
 DeleteLocalRef=function() end,
 NewStringUTF=function(_,str) return str end,
}
local fail=false
local jni={env=env,
 context=function(self,vm,fn) return fn(self) end,
 callObjectMethod=function(_,object,method,signature,...)
  if method=='getFD' then return 'fd' end
  if method=='setSpeed' then assert((...)==0.85) end
  if method=='setPitch' then assert((...)==1.0) end
  assert(method=='getPlaybackParams' or method=='allowDefaults' or method=='setSpeed' or method=='setPitch')
  return 'params'
 end,
 callVoidMethod=function(_,object,method,signature,...)
  calls[#calls+1]=method
  if method=='setDataSource' then
   local fd,offset,length=...;assert(fd=='fd' and offset==100 and length==120)
   assert(signature=='(Ljava/io/FileDescriptor;JJ)V')
  end
  if method=='prepare' and fail then exception=true end
 end,
}
local player=Player.new({jni=jni,app={activity={vm={}}}}, {new=function(_,v) return v end})
assert(player:play('pack',100,120))
assert(table.concat(calls,',')=='setDataSource,prepare,start,close')
assert(globals==1 and deleted==0)
player:stop();assert(deleted==1 and player.player==nil)
fail=true;calls={}
local ok,err=player:play('pack',100,120)
assert(not ok and err:find('could not play',1,true))
assert(table.concat(calls,',')=='setDataSource,prepare,close,release')
assert(globals==2 and deleted==2 and player.player==nil and not exception)
fail=false;calls={}
assert(player:play('pack',100,120,0.85))
assert(table.concat(calls,',')=='setDataSource,prepare,setPlaybackParams,start,close')
player:stop();assert(globals==3 and deleted==3)
print('Dictionary audio: index normalization, missing data, bounded playback, release and Java exception cleanup passed')
local translations_path=os.tmpname()
local tf=assert(io.open(translations_path,'wb'));tf:write('book\tlibro\tlibreto\nwrite\tescribir\n');tf:close()
local translations=assert(Index.translations(translations_path));os.remove(translations_path)
assert(translations.book[1]=='libro' and translations.book[2]=='libreto')
assert(Index.find({['Ácido']={0,1}},'Ácido')[2]==1)
package.preload['datastorage']=function() return {} end
package.preload['device']=function() return {screen={getWidth=function() return 1000 end}} end
package.preload['gettext']=function() return function(s) return s end end
package.preload['ui/widget/notification']=function() return {new=function(_,o) return o end} end
local shown
package.preload['ui/uimanager']=function() return {show=function(_,o) shown=o end,close=function() end} end
package.preload['ui/widget/menu']=function() return {new=function(_,o) return o end} end
local Widget={}
function Widget:extend(o) return setmetatable(o or {},{__index=self}) end
package.preload['ui/widget/container/widgetcontainer']=function() return Widget end
local Audio=dofile('dictionary-audio.koplugin/main.lua')
local played
local audio=Audio:extend{root='test/',translations=translations,
 indices={spanish={libro={100,120},libreto={100,120}},english={book={100,120}}},
 player={play=function(_,path,offset,length,rate) played={path,offset,length,rate};return true end,stop=function() end}}
audio:showSpanish('book')
assert(shown.title=='Hear Spanish: book' and #shown.item_table==2)
shown.item_table[2].callback()
assert(played[1]=='test/spanish-neural-audio/spanish.pack')
assert(played[2]==100 and played[3]==120)
audio:pronounce('BOOK');assert(played[1]=='test/english-audio/english.pack')
audio:showSpanish('libro');assert(played[1]=='test/spanish-neural-audio/spanish.pack')
print('Spanish audio: translation alternatives, exact accented keys, chooser callbacks and English/Spanish pack selection passed')

local saved={}
G_reader_settings={saveSetting=function(_,key,value) saved[key]=value end}
audio.spanish_rate=0.85;audio.english_enabled=true;audio.spanish_enabled=true
local menu={};audio:addToMainMenu(menu)
local rates=menu.dictionary_audio.sub_item_table[3].sub_item_table
assert(rates[2].checked_func() and not rates[1].checked_func())
rates[1].callback();audio:showSpanish('libro');assert(played[4]==1)
rates[3].callback();audio:showSpanish('libro');assert(played[4]==0.7)
assert(saved.dictionary_audio_spanish_rate==0.7)
audio:pronounce('book');assert(played[4]==1)
local old=played
menu.dictionary_audio.sub_item_table[2].callback()
assert(audio.spanish_enabled==false and saved.dictionary_audio_spanish_enabled==false)
assert(audio.english_enabled==true)
audio:showSpanish('libro');assert(played==old)
audio:pronounce('book');assert(played~=old and played[1]=='test/english-audio/english.pack')
old=played
menu.dictionary_audio.sub_item_table[1].callback()
assert(audio.english_enabled==false and saved.dictionary_audio_english_enabled==false)
audio:pronounce('book');assert(played==old)
menu.dictionary_audio.sub_item_table[2].callback()
assert(audio.spanish_enabled==true and audio.english_enabled==false)
audio:showSpanish('libro');assert(played[1]=='test/spanish-neural-audio/spanish.pack')
print('Speech settings: speed persists, English stays normal, and English/Spanish can be enabled independently')
-- Settings survive opening a different book; visibility is evaluated per popup.
package.loaded['device'].isAndroid=function() return true end
package.loaded['datastorage'].getDataDir=function() return 'test' end
package.preload['android']=function() return {} end
package.preload['ffi']=function() return {} end
saved.dictionary_audio_english_enabled=true
saved.dictionary_audio_spanish_enabled=false
G_reader_settings.readSetting=function(_,key) return saved[key] end
local buttons={}
local restored=Audio:extend{ui={menu={registerToMainMenu=function() end},dictionary={
 addToDictButtons=function(_,spec) buttons[spec.id]=spec end}}}
restored:init()
assert(restored.english_enabled and not restored.spanish_enabled)
assert(buttons.offline_english_audio.show_func() and not buttons.offline_spanish_audio.show_func())
assert(restored.spanish_rate==0.7)
local settings_menu={};restored:addToMainMenu(settings_menu)
settings_menu.dictionary_audio.sub_item_table[2].callback()
assert(buttons.offline_spanish_audio.show_func() and buttons.offline_english_audio.show_func())
print('Language preferences survive reopening books and independently control popup button visibility')

package.preload['ui/widget/buttondialog']=function() return {new=function(_,o) return o end} end
assert(restored.ui.dictionary_audio==restored)
restored:showSettings()
assert(shown.buttons[1][1].text=='English audio: ON')
shown.buttons[2][1].callback()
assert(not restored.spanish_enabled and restored.english_enabled)
assert(not shown.buttons[4][1].enabled)
shown.buttons[2][1].callback()
shown.buttons[4][2].callback()
assert(restored.spanish_enabled and restored.spanish_rate==0.85)
assert(shown.buttons[4][2].text=='✓ Slower')
print('Toolbar audio dialog: independent switches, disabled speed when off, selected speed and persistence passed')
