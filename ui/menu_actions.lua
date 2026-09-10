local Actions={}
function Actions.execute(ctx,action)
    local game=ctx.game
    if action=="skill_menu" then
        local u=game.selected_units[1]
        if u.unit_type=="repair" then ctx.context_menu:show(ctx.context_menu.x,ctx.context_menu.y,{{"全舰修复","fleet_heal"},{"维修工具：选友舰","repair_tool"},{"返回","back"}})
        elseif require("systems.skill").target_mode(u)=="enemy" then
            local Skill=require("systems.skill")
            if u.sp<u.max_sp then game:report_event(u,"failed","能量还没充满，再等等。");require("systems.audio").play("error")
            elseif not Skill.can_execute(u,game) then game:report_event(u,"failed","当前没有合适的目标。");require("systems.audio").play("error")
            else ctx.start_targeting("skill_target") end
        else Actions.execute(ctx,"skill") end
    elseif action=="back" then ctx.show_context_menu(ctx.context_menu.x,ctx.context_menu.y)
    elseif action=="fleet_heal" then for _,u in ipairs(game.selected_units) do if u.unit_type=="repair" and not u.skill_pending then u.skill_data={type="fleet_heal"};u:use_skill(game) end end;ctx.hide_menus()
    elseif action=="repair_tool" then ctx.start_targeting("repair_tool")
    elseif action=="auto_skill" then local enabled=not game.selected_units[1].auto_skill;for _,u in ipairs(game.selected_units) do u.auto_skill=enabled;require("systems.preferences").set("auto_skill_"..u.character_id,enabled) end;ctx.hide_menus()
    elseif action=="global" then ctx.global_menu:show(ctx.context_menu.x+ctx.context_menu.width+6,ctx.context_menu.y,{{"全体移动","global_move"},{"全体攻击","global_attack"},{"全体跟随","global_follow"},{"全体防御","global_defend"},{"全体补给","global_supply"}})
    elseif action=="move" or action=="attack" or action=="follow" or action=="repair" then ctx.start_targeting(action)
    elseif action=="supply" then ctx.set_returning(ctx.commandable(false));ctx.hide_menus()
    elseif action=="skill" then for _,u in ipairs(ctx.commandable(true)) do if not u:use_skill(game) then game:report_event(u,"failed","技能尚未就绪，或附近没有有效目标。") end end;ctx.hide_menus()
    else ctx.hide_menus() end
end
function Actions.execute_global(ctx,action)
    local all=ctx.select_all();if #all==0 then ctx.hide_menus();return end
    if action=="global_move" then ctx.start_targeting("move") elseif action=="global_attack" then ctx.start_targeting("attack") elseif action=="global_follow" then ctx.start_targeting("follow") elseif action=="global_defend" then ctx.command_defense(all);ctx.hide_menus() elseif action=="global_supply" then ctx.set_returning(all);ctx.hide_menus() end
end
return Actions
