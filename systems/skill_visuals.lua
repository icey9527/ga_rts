local V={}
function V.release(game,u,kind)
    game.screen_flash={time=0.45,max=0.45,color=(kind=="shield" or kind=="heal_aoe" or kind=="fleet_heal" or kind=="repair_tool") and {0.3,0.95,0.85} or {1,0.8,0.5}}
    game.skill_slow={time=1.7,scale=0.24,unit=u}
    local Effect=require("entities.effect")
    if kind=="buff_speed" or kind=="rapid_fire" then game:add_effect(Effect.skill_signature(u)) end
end
function V.update(game,dt)
    if game:is_paused() then return end
    if game.screen_flash then game.screen_flash.time=game.screen_flash.time-dt; if game.screen_flash.time<=0 then game.screen_flash=nil end end
    if game.skill_slow then game.skill_slow.time=game.skill_slow.time-dt; if game.skill_slow.time<=0 then game.skill_slow=nil end end
end
function V.draw(game)
    local f=game.screen_flash
    if not f then return end
    love.graphics.push("all")
    love.graphics.setColor(f.color[1],f.color[2],f.color[3],0.24*(f.time/f.max)^2)
    love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
    love.graphics.pop()
end
return V
