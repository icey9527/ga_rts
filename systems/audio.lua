local A={sources={},last={},voices={}}
function A.play(event)
    if _G.VERIFY_RUNNING or not love.audio then return end
    local cfg=require("config.audio")[event]
    if not cfg then return end
    local now=love.timer.getTime()
    if now-(A.last[event] or -10)<cfg.cooldown then return end
    A.last[event]=now
    local volume=math.max(0,math.min(1,tonumber(require("systems.preferences").get("volume",0.9)) or 0.9))
    if volume==0 then return end
    if A.sources[event]==nil then
        local ok,source=pcall(love.audio.newSource,"assets/se/"..cfg.file..".ogg","static")
        A.sources[event]=ok and source or false
    end
    if not A.sources[event] then return end
    for i=#A.voices,1,-1 do if not A.voices[i]:isPlaying() then table.remove(A.voices,i) end end
    if #A.voices>=12 then A.voices[1]:stop();table.remove(A.voices,1) end
    local source=A.sources[event]:clone();source:setVolume(volume*cfg.volume);source:play()
    A.voices[#A.voices+1]=source
end
return A
