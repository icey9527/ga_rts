local Flow={}
local LevelManager=require("levels.manager")
local Mission=require("systems.mission_script")
local Advisor=require("systems.advisor")
local Simulation=require("systems.simulation")
local Registry=require("systems.pack_registry")
local Score=require("systems.score")

function Flow.level_menu(files,TBL,scores)
    local names,values={},{}
    for _,file in ipairs(files) do
        local data=TBL.parse_file("levels/"..file)
        local name=(data and data.meta and (data.meta.name or data.meta.value)) or file
        names[#names+1]=name; values[#values+1]=scores[name] or 0
    end
    return names,values
end

function Flow.start_level(ctx,index)
    if index<1 or index>#ctx.level_files then return nil end
    local file=ctx.level_files[index]
    local ok,err=LevelManager.load_level(file,ctx.game)
    if not ok then print("Failed to load level: "..tostring(err));return nil end
    local game,camera=ctx.game,ctx.camera
    game.player_team_id=game.player_team_id or Registry.default_player()
    game.enemy_team_id=game.enemy_team_id or Registry.default_enemy()
    game.team_id=game.player_team_id
    Mission.start(game,file);Advisor.start(game)
    local ms=game:get_mothership(game.player_team)
    local cx,cy=game:get_units_center();if ms then cx,cy=ms.x,ms.y end
    camera:focus_on(cx,cy);camera.zoom=0.8;camera.target_zoom=0.8;camera:stop_follow()
    ctx.reset_input();game:resume()
    local state="playing"
    if not _G.VERIFY_RUNNING and not (game.advisor and game.advisor.tutorial) then game:pause();state="deployment" end
    return state,game.level_name or file,file
end

function Flow.begin_briefing(ctx)
    Simulation.deploy(ctx.game,ctx.deployment.player_id(),ctx.deployment.enemy_id(),ctx.deployment.formation)
    Mission.start(ctx.game,ctx.level_file)
    ctx.game.briefing={time=0};ctx.game:pause()
    local ms=ctx.game:get_mothership(0);if ms then ctx.camera:focus_on(ms.x,ms.y) end
    return "briefing"
end

function Flow.finish_briefing(game)
    game.briefing=nil;Mission.advance(game,true);game.reports={};game:resume()
    return "playing"
end

function Flow.check_result(game,settings,scores,level_name,TBL)
    if game:is_paused() or (game.advisor and game.advisor.tutorial) then return nil end
    if LevelManager.check_victory(game) then
        Mission.finish(game,"victory");Score.calculate(game,settings);Score.save_high(game,scores,level_name,TBL)
        require("systems.audio").play("victory");return "victory"
    elseif LevelManager.check_defeat(game) then
        Mission.finish(game,"defeat");require("systems.audio").play("defeat");return "defeat"
    end
end

return Flow
