-- 背景音乐：按游戏状态切换，同一曲目不重复启动。
-- 音源来自原声音乐集，ASCII 文件名映射见 config/bgm.lua。
local BGM={current=nil,source=nil}

function BGM.play(name,loop)
    if _G.VERIFY_RUNNING or not love.audio then return end
    if BGM.current==name then return end
    BGM:stop()
    local file=require("config.bgm")[name]
    if not file then return end
    local ok,src=pcall(love.audio.newSource,"assets/bgm/"..file..".ogg","stream")
    if not ok then BGM.current=name return end
    src:setLooping(loop~=false)
    local master=tonumber(require("systems.preferences").get("volume",0.65)) or 0.65
    src:setVolume(math.max(0,math.min(1,master))*0.5)
    src:play()
    BGM.current,BGM.source=name,src
end

function BGM.stop()
    if BGM.source then BGM.source:stop() end
    BGM.source=nil
    BGM.current=nil
end

return BGM
