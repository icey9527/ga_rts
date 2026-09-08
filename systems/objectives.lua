local O={}
function O.start(game)
    local script=game.mission and game.mission.script or {}
    local spec=script.objective
    game.objective=nil
    if not spec then return end
    local base=game:get_mothership(game.player_team)
    if not base then return end
    local o={spec=spec,start_x=base.x,start_y=base.y,progress=0,elapsed=0}
    game.objective=o
    if spec.type=="escort" then
        local u=require("entities.unit").new(base.x+120,base.y+240,game.player_team,require("levels.manager").unit_config("carrier"))
        u.character_id=40;u.objective_ship=true;u.base_speed=28;u.speed=28
        game:add_unit(u);o.unit=u
        local delta=spec.destination or {2100,600}
        o.x,o.y=game:find_clear_position(base.x+delta[1],base.y+delta[2],u.radius)
        o.distance=math.max(1,u:dist_to_pos(o.x,o.y))
    end
    for _,wave in ipairs(script.reinforcements or {}) do
        game.pending_waves[#game.pending_waves+1]={time=wave.time,team=wave.team or 1,count=wave.count or 2,
            cfg=require("levels.manager").unit_config(wave.unit or "fighter"),
            character_id=wave.id,x=base.x+(wave.offset or {2400,-600})[1],y=base.y+(wave.offset or {2400,-600})[2],spread=180}
    end
end
function O.update(game,dt)
    local o=game.objective
    if not o or o.complete or o.failed then return end
    o.elapsed=o.elapsed+dt
    if not game:get_mothership(game.player_team) then o.failed=true;return end
    if o.spec.type=="escort" then
        if not o.unit.alive then o.failed=true;return end
        local d=o.unit:dist_to_pos(o.x,o.y)
        o.progress=math.max(o.progress,1-d/o.distance)
        if d<110 then o.complete=true;o.unit.state="idle";o.unit.target_pos=nil
        elseif o.unit.state~="disabled" then o.unit.state="moving";o.unit.target_pos={o.x,o.y};o.unit.attack_move=nil end
    elseif o.spec.type=="survive" then
        o.progress=math.min(1,o.elapsed/(o.spec.duration or 180));o.complete=o.progress>=1
    elseif o.spec.type=="flagship" then
        o.complete=not game:get_mothership(1-game.player_team)
    else
        local pending=false
        for _,wave in ipairs(game.pending_waves) do if wave.team~=game.player_team then pending=true end end
        o.complete=#game:get_enemy_units(game.player_team)==0 and not pending
    end
end
function O.draw(game,camera)
    local o=game.objective
    if not o then return end
    local g=love.graphics
    g.push("all");g.setFont(require("core.fonts").get(12));g.setColor(0.75,0.98,0.82,1)
    local text=o.spec.label or "完成演习目标"
    if o.spec.type=="escort" or o.spec.type=="survive" then text=text.."  "..math.floor(o.progress*100).."%" end
    g.printf(text,270,36,math.max(80,g.getWidth()-550))
    if o.x then
        local x,y=camera:world_to_screen(o.x,o.y)
        if x>260 and x<g.getWidth()-20 and y>65 and y<g.getHeight()-30 then
            g.setLineWidth(2);g.circle("line",x,y,math.max(20,110*camera.zoom));g.printf("集结区",x-45,y+24,90,"center")
        end
    end
    g.pop()
end
return O
