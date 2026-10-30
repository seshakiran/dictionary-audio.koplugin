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
