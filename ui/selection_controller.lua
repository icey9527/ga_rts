local Selection = {}

function Selection.commandable(game, include_mothership)
    local out={}
    for _,u in ipairs(game.selected_units) do
        if u.alive and u.state~="dead" and u.state~="disabled"
           and (include_mothership or u.unit_type~="mothership") then out[#out+1]=u end
    end
    return out
end

function Selection.select_all_command_units(game)
    local all=game:get_all_friendly_units(game.player_team)
    game:clear_selection()
    for _,u in ipairs(all) do u.selected=true; game.selected_units[#game.selected_units+1]=u end
    return all
end

function Selection.set_returning(units)
    for _,u in ipairs(units) do
        if u.unit_type~="mothership" then
            u.attack_target=nil;u.repair_target=nil;u.follow_target=nil;u.attack_move=nil
            require("battle.unit.combat").cancel_bursts(u);u.route=nil;u.state="returning"
        end
    end
end

function Selection.command_defense(game,units,feedback)
    local ms=game:get_mothership(game.player_team)
    if not ms then return end
    for i,u in ipairs(units) do
        if u.unit_type~="mothership" then
            local angle=(i/math.max(1,#units))*math.pi*2
            local radius=150+(i%3)*45
            local tx=ms.x+math.cos(angle)*radius
            local ty=ms.y+math.sin(angle)*radius
            u.follow_target=ms
            u.attack_target=nil
            u.target_pos={tx,ty}
            u.state="moving"
            if feedback then feedback(u,tx,ty) end
        end
    end
end

return Selection
