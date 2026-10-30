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
 callObjectMethod=function(_,object,method) assert(method=='getFD');return 'fd' end,
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
package.preload['ui/uimanager']=function() return {show=function(_,o) shown=o end} end
package.preload['ui/widget/menu']=function() return {new=function(_,o) return o end} end
local Widget={}
function Widget:extend(o) return setmetatable(o or {},{__index=self}) end
package.preload['ui/widget/container/widgetcontainer']=function() return Widget end
local Audio=dofile('dictionary-audio.koplugin/main.lua')
local played
local audio=Audio:extend{root='test/',translations=translations,
 indices={spanish={libro={100,120},libreto={100,120}},english={book={100,120}}},
 player={play=function(_,path,offset,length) played={path,offset,length};return true end}}
audio:showSpanish('book')
assert(shown.title=='Hear Spanish: book' and #shown.item_table==2)
shown.item_table[2].callback()
assert(played[1]=='test/spanish-audio/spanish.pack')
assert(played[2]==100 and played[3]==120)
audio:pronounce('BOOK');assert(played[1]=='test/english-audio/english.pack')
audio:showSpanish('libro');assert(played[1]=='test/spanish-audio/spanish.pack')
print('Spanish audio: translation alternatives, exact accented keys, chooser callbacks and English/Spanish pack selection passed')
