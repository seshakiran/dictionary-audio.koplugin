-- Android MediaPlayer plays a bounded WAV slice from one offline pack. No
-- external activity, network request, background service, or shell command.
local Player = {}
function Player.new(android,ffi)
    return setmetatable({android=android,ffi=ffi},{__index=Player})
end
function Player:release(jni)
    if not self.player then return end
    jni:callVoidMethod(self.player,"release","()V")
    jni.env[0].DeleteGlobalRef(jni.env,self.player)
    self.player=nil
end
function Player:stop()
    if not self.player then return end
    self.android.jni:context(self.android.app.activity.vm,function(jni) self:release(jni) end)
end
function Player:play(path,offset,length)
    return self.android.jni:context(self.android.app.activity.vm,function(jni)
        local env=jni.env
        local refs={}
        local stream
        local function check(value)
            if env[0].ExceptionCheck(env)~=0 then
                env[0].ExceptionClear(env)
                error("Android could not play this recording. Check media volume and the audio pack.",0)
            end
            return value
        end
        local function localRef(ref)
            check()
            if ref==nil then error("Android audio object unavailable",0) end
            refs[#refs+1]=ref;return ref
        end
        local function construct(class,signature,...)
            local cls=localRef(env[0].FindClass(env,class))
            local init=check(env[0].GetMethodID(env,cls,"<init>",signature))
            if init==nil then error("Android audio constructor unavailable",0) end
            return localRef(env[0].NewObject(env,cls,init,...))
        end
        local ok,err=pcall(function()
            self:release(jni);check()
            local path_string=localRef(env[0].NewStringUTF(env,path))
            stream=construct("java/io/FileInputStream","(Ljava/lang/String;)V",path_string)
            local fd=localRef(jni:callObjectMethod(stream,"getFD","()Ljava/io/FileDescriptor;"))
            local player=construct("android/media/MediaPlayer","()V")
            self.player=check(env[0].NewGlobalRef(env,player))
            if self.player==nil then self.player=nil;error("Android audio reference unavailable",0) end
            jni:callVoidMethod(player,"setDataSource","(Ljava/io/FileDescriptor;JJ)V",fd,
                self.ffi.new("jlong",offset),self.ffi.new("jlong",length));check()
            jni:callVoidMethod(player,"prepare","()V");check()
            jni:callVoidMethod(player,"start","()V");check()
        end)
        if stream then jni:callVoidMethod(stream,"close","()V") end
        if env[0].ExceptionCheck(env)~=0 then env[0].ExceptionClear(env) end
        if not ok then
            self:release(jni)
            if env[0].ExceptionCheck(env)~=0 then env[0].ExceptionClear(env) end
        end
        for _,ref in ipairs(refs) do env[0].DeleteLocalRef(env,ref) end
        return ok,err
    end)
end
return Player
