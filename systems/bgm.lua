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
    local master=tonumber(require("systems.preferences").get("volume",0.9)) or 0.9
    src:setVolume(math.max(0,math.min(1,master))*0.8)
    src:play()
    BGM.current,BGM.source=name,src
end

function BGM.play_pack(game,state,loop)
    local pack=require("systems.pack_registry")
    local team_id=(game and game.player_team_id) or (game and game.team_id) or pack.default_player()
    local file=pack.bgm(game and game.content_pack,team_id,state)
    if not file then return BGM.play(state,loop) end
    local key=team_id..":"..state
    if BGM.current==key then return end
    BGM:stop()
    local team=pack.team(game and game.content_pack or "galaxy",team_id)
    if not team then return BGM.play(state,loop) end
    local root=team.root
    local ok,src=pcall(love.audio.newSource,root.."/"..file,"stream")
    if not ok then return BGM.play(state,loop) end
    local master=tonumber(require("systems.preferences").get("volume",0.9)) or 0.9
    src:setLooping(loop~=false); src:setVolume(math.max(0,math.min(1,master))*0.8); src:play()
    BGM.current,BGM.source=key,src
end

function BGM.play_battle(game)
    local index=tonumber(game and game.level_index or 0) or 0
    local squad=tonumber(game and game.chosen_squad or 1) or 1
    -- 当前素材集中只有一首正式战斗曲；通过不同播放起点和音高形成关卡/舰队差异，
    -- 待后续补充更多原声文件时，只需在 config/bgm.lua 增加映射即可。
    local key=((index+squad)%2==0) and "battle_alt" or "battle"
    BGM.play(key)
    if BGM.source then
        BGM.source:setPitch(squad==2 and 0.94 or (1.0+((index%3)*0.015)))
    end
end

function BGM.stop()
    if BGM.source then BGM.source:stop() end
    BGM.source=nil
    BGM.current=nil
end

return BGM
