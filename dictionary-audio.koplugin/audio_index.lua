-- Plain TSV index for a concatenated collection of independent WAV files.
local Index = {}
function Index.read(path)
    local f,err=io.open(path,"rb")
    if not f then return nil,err end
    local result={}
    for line in f:lines() do
        local word,offset,length=line:match("^([^\t]+)\t(%d+)\t(%d+)$")
        if word and tonumber(length)>0 then result[word]={tonumber(offset),tonumber(length)} end
    end
    f:close();return result
end
function Index.find(index,word)
    word=tostring(word or ""):gsub("^%s+",""):gsub("%s+$","")
    return index[word] or index[word:lower()] or index[word:lower():gsub(" ","_")]
end
function Index.translations(path)
    local f,err=io.open(path,"rb")
    if not f then return nil,err end
    local result={}
    for line in f:lines() do
        local key,rest=line:match("^([^\t]+)\t(.+)$")
        if key then
            local choices={}
            for term in rest:gmatch("[^\t]+") do choices[#choices+1]=term end
            result[key]=choices
        end
    end
    f:close();return result
end
return Index
