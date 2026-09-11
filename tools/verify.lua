local Verify = {}
function Verify.input(game,camera,panel,show_context_menu,execute_menu_action,execute_targeted_command,cancel_command)
    local friendly=game:get_units_by_team(game.player_team)[2]
    game:select_unit(friendly)
    game:pause()
    show_context_menu(300,200)
    execute_menu_action("global")
    love.mousepressed(480,210,1)
    assert(camera.edge_scroll,"submenu input reaches global command")
    local before=game.level_time
    local getPosition=love.mouse.getPosition
    love.mouse.getPosition=function() return 1,300 end
    local old_x=camera.x
    love.update(0.03)
    love.mouse.getPosition=getPosition
    assert(camera.x<old_x and game.level_time==before,"command edge scroll keeps simulation paused")
    execute_targeted_command(300,350)
    assert(game:is_paused(),"manual pause preserved after order")
    game:resume()
    show_context_menu(300,200)
    execute_menu_action("move")
    cancel_command()
    assert(not game:is_paused(),"running state restored after cancel")
    love.mousepressed(200,60,1)
    love.mousepressed(50,110,1)
    assert(game.inspected_unit and game.inspected_unit.team~=game.player_team and camera.follow_target==game.inspected_unit,"enemy panel follows enemy")
    local saved=game.inspected_unit
    assert(saved.team~=friendly.team and not saved.selected,"inspection does not command enemy")
    panel.side="friendly"
    game.inspected_unit=nil
    game:select_unit(friendly)
    camera:stop_follow()
    camera:set_follow(friendly)
    local cx,cy=camera.x,camera.y
    love.mousepressed(400,300,3)
    love.mousemoved(450,330,50,30)
    love.mousereleased(460,335,3)
    assert(math.abs(camera.x-(cx-60/camera.zoom))<0.001 and math.abs(camera.y-(cy-35/camera.zoom))<0.001,"middle drag including final release without update")
    assert(camera.follow_target==nil,"middle drag releases follow")
    game.mission=nil;game.reports={};game.advisor.life=0;game.researcher.life=0;game.economy.open=false
    saved.x,saved.y=600,300
    camera:focus_on(saved.x,saved.y);camera.zoom=0.8;camera.target_zoom=0.8
    local px,py=require("ui.tactical_markers").position(saved,camera)
    local order=friendly.attack_target
    love.mousepressed(px,py,1)
    assert(game.inspected_unit==saved and camera.follow_target==saved and friendly.attack_target==order,"map portrait inspection never orders an attack")
    local x,y,z=camera.x,camera.y,camera.zoom
    require("systems.cinematic").start(game,friendly)
    assert(camera.x==x and camera.y==y and camera.zoom==z,"cutin does not move camera")
    game.cutins={};game.cinematic=nil;game.inspected_unit=nil;camera:stop_follow()
    local file=assert(io.open(love.filesystem.getSource().."/verification.txt","a"))
    file:write("PASS: actual menu input, global submenu, targeting edge scroll, pause restoration, enemy follow\n")
    file:write("Save directory: "..love.filesystem.getSaveDirectory().."/saves\n")
    file:close()
end
function Verify.run()
    require("tools.verify_missions").run()
    local Game = require("core.game")
    local Unit = require("entities.unit")
    local Projectile = require("entities.projectile")
    local g = Game.new()
    local u = Unit.new(100,100,0,{radius=20,z=100})
    g:add_unit(u)
    assert(g:get_unit_at(100,78)==u,"projected picking")
    g:select_units_in_rect(95,73,105,83)
    assert(#g.selected_units==1,"projected box selection")
    u.energy=10
    g.environment_layers={{type="sun",x=100,y=100,radius=100}}
    g:pause()
    g:update(1)
    assert(u.energy==10,"pause freezes environment")
    local target=Unit.new(25,0,1,{})
    local p=Projectile.basic(0,0,25,0,10,1000,target)
    assert(not p:update(0.05,g),"swept projectile impact")
    assert(target.hp==90,"projectile damage exactly once")
    local Camera=require("core.camera")
    local camera=Camera.new(6000,4200)
    local getPosition=love.mouse.getPosition
    love.mouse.getPosition=function() return 1,300 end
    camera:set_follow(u)
    camera:enable_edge_scroll(true)
    camera:edge_scroll_update(0.1)
    assert(camera.x<0 and camera.follow_target==nil,"edge scroll breaks follow inside window")
    love.mouse.getPosition=getPosition
    for _=1,30 do camera:zoom_out() end
    assert(camera.target_zoom==0.1,"strategic zoom")
    local Orders=require("systems.orders")
    local a=Unit.new(0,0,0,{})
    local b=Unit.new(0,40,0,{})
    local battle=Game.new()
    battle:add_unit(a); battle:add_unit(b); battle:add_unit(target)
    assert(Orders.issue(battle,{a,b},"move",nil,400,400)==2)
    assert(a.target_pos[1]~=b.target_pos[1],"formation slots")
    assert(Orders.issue(battle,{a},"attack",a,0,0)==0,"reject friendly fire order")
    assert(Orders.issue(battle,{a},"attack",nil,400,400)==1 and a.attack_move,"attack move")
    a.attack_target=target; a.state="attacking"; target.alive=false
    a:_state_attacking(1/60,battle)
    assert(a.state=="moving" and a.target_pos[1]==400,"resume attack move")
    local Panel=require("ui.unit_panel")
    local panel=Panel.new()
    target.alive=true
    battle:invalidate_team_cache()
    panel:handle_click(200,60,battle,1)
    local action,enemy=panel:handle_click(50,110,battle,1)
    assert(action=="inspect" and enemy==target,"enemy roster inspect")
    local nav=require("systems.navigation")
    battle.terrain_objects={{x=200,y=0,radius=55,height=200}}
    a.x,a.y,a.z=0,0,0
    local route=nav.route(battle,a,400,0)
    assert(#route>1,"obstacle detour")
    a.route=nil
    for _=1,300 do battle.level_time=battle.level_time+1/60; if a:_move_towards(400,0,a.speed/60,battle) then break end end
    assert(math.abs(a.x-400)<2 and math.abs(a.y)<2,"detour arrival")
    a.skill_data={type="damage_aoe",radius=30}; a.sp=100
    assert(not a:use_skill(battle) and a.sp==100,"no wasted skill")
    a.state="disabled"; a.skill_data={type="shield"}
    assert(not a:use_skill(battle),"disabled skill blocked")
    local Controller=require("battle.ai.controller")
    local Executor=require("battle.ai.executor")
    local ms=Unit.new(0,0,1,{type="mothership"})
    battle:add_unit(ms)
    target.energy=1; target.state="supplying"
    Executor.command(Controller.new(1),target,{target,ms},{a},battle)
    assert(target.state=="supplying","AI preserves supply")
    local splash=Projectile.artillery(0,0,0,0,10,50,100,0,1)
    target.x,target.y=0,0
    local hp=target.hp
    splash:update(0.01,battle)
    assert(target.hp==hp,"artillery excludes friendly units")
    local missed=Projectile.basic(0,0,25,0,10,1000,target)
    target.x=200
    missed:update(0.05,battle)
    assert(target.hp==hp,"ballistic miss does not damage distant target")
    local levels=require("levels.manager")
    local Economy=require("systems.economy")
    local e=Game.new()
    assert(levels.load_level("level_01.tbl",e))
    e.economy.credits=3000
    local start=e.economy.credits
    assert(Economy.enqueue(e,"fighter"))
    assert(e.economy.credits==start-1500)
    assert(Economy.cancel(e,1) and e.economy.credits==start,"queue refund")
    local n=#e.units
    assert(Economy.enqueue(e,"repair")); Economy.update(e,21)
    assert(#e.units==n+1 and e.units[#e.units].unit_type=="repair","production completes")
    local repair=e.units[#e.units]
    local enemy=e:get_enemy_units(e.player_team)[1]
    assert(Orders.issue(e,{repair},"attack",enemy,enemy.x,enemy.y)==1 and repair.state=="attacking","repair accepts target attack")
    assert(Orders.issue(e,{repair},"attack",nil,1000,1000)==1 and repair.attack_move,"repair participates in attack move")
    assert(Orders.issue(e,{repair},"move",nil,1000,1000)==1)
    assert(Orders.issue(e,{repair},"follow",e:get_mothership(0),0,0)==1)
    assert(Orders.issue(e,{repair},"repair",enemy,0,0)==0,"repair rejects enemy repair")
    local hp=repair.max_hp
    e.economy.credits=10000
    assert(Economy.enqueue(e,"armor")); Economy.update(e,29)
    assert(e.economy.armor==1 and repair.max_hp>hp,"upgrade applies to fleet")
    assert(Economy.enqueue(e,"fighter")); Economy.update(e,17)
    assert(e.units[#e.units].tech_armor==1,"new production inherits technology")
    assert(Economy.enqueue(e,"collector")); Economy.update(e,25)
    assert(e.units[#e.units].unit_type=="collector","station construction")
    -- 阵营增援：指定角色入队、完成后该角色上场；候选池不含场上角色（不抽随机池）。
    local candidates=Economy.member_candidates(e)
    assert(#candidates>0,"faction has reinforcement candidates")
    local pick=candidates[1]
    assert(Economy.enqueue(e,"member",pick))
    local job=e.economy.queue[#e.economy.queue]
    assert(job and job.character==pick,"member job carries the chosen character")
    local before=#e.units
    Economy.update(e,15)
    assert(#e.units==before+1 and e.units[#e.units].character_id==pick,"member reinforcement spawns the chosen character")
    for _,c in ipairs(Economy.member_candidates(e)) do assert(c~=pick,"on-field character leaves candidate pool") end
    local credits=e.economy.credits
    Economy.update(e,1)
    -- 基础收入 9/s，加上采集站 8/s。
    assert(e.economy.credits==credits+17,"station income")
    assert(Economy.enqueue(e,"weapons"))
    local remain=e.economy.queue[1].remaining
    e:pause(); e:update(5)
    assert(e.economy.queue[1].remaining==remain,"paused economy")
    e:get_mothership(0).alive=false
    e:invalidate_team_cache()
    Economy.update(e,1)
    assert(#e.economy.queue==0,"lost mothership cancels queue")
    local Pilots=require("ui.pilots")
    for _,name in ipairs({"ui-confirm","ui-open","weapon-release","impact","skill-charge"}) do
        local data=love.sound.newSoundData("assets/se/"..name..".ogg")
        assert(data:getDuration()>0,"audio asset decodes")
    end
    -- 角色对白现在按队伍隔离，统一从 teams/<team>/chara/<id>/dialogue.lua 读取。
    local sample=Pilots.dialogue({character_id=25,team_id="rune"})
    assert(type(sample)=="table" and sample.friendly,"team pilot dialogue pools load")
    assert(Pilots.profile({character_id=25,team_id="rune"}).name=="可可","rune left is Coco")
    assert(Pilots.profile({character_id=22,team_id="rune"}).name=="诺阿","rune right is Noah")
    assert(Pilots.profile({character_id=21,team_id="moon"}).name=="雷斯特","moon left is Lester")
    assert(Pilots.profile({character_id=26,team_id="moon"}).name=="阿尔茉","moon right is Almo")
    local nano={unit_type="repair",character_id=3,team_id="rune"}
    assert(not Pilots.line(nano,"command",""):find("我",1,true),"Nano speech constraint")
    local skill_game=Game.new()
    local caster=Unit.new(0,0,0,{stats={type="fighter"},skill={type="shield",shield_amount=200,duration=4}})
    skill_game:add_unit(caster); caster.sp=100
    assert(caster:use_skill(skill_game) and caster.shield==0 and caster.skill_pending,"skill windup precedes effect")
    for _=1,80 do skill_game:update(1/60) end
    assert(caster.shield>0 and not caster.skill_pending,"skill releases after windup")
    local gunner=Unit.new(0,0,0,{attack_type="missile",projectile_count=5,attack_damage=50,attack_range=400})
    local dummy=Unit.new(100,0,1,{})
    skill_game.projectiles={}
    for i=0,4 do gunner:_spawn_projectile(skill_game,dummy,i,5) end
    local volley=0
    for _,shot in ipairs(skill_game.projectiles) do volley=volley+shot.damage end
    assert(volley==50,"missile volley damage is shared across projectiles")
    local retarget=Unit.new(30,0,1,{})
    skill_game:add_unit(retarget)
    caster.attack_target={alive=false}; caster.state="attacking"
    caster:_state_attacking(0.01,skill_game)
    assert(caster.attack_target==retarget,"continues combat after target death")
    local Advisor=require("systems.advisor")
    local training=Game.new()
    assert(levels.load_level("level_00.tbl",training))
    Advisor.start(training)
    assert(training.tutorial_hold,"tutorial starts protected")
    training:select_unit(training:get_units_by_team(0)[2])
    Advisor.update(training,0.1)
    Advisor.event(training,"pan"); Advisor.event(training,"zoom"); Advisor.update(training,0.1)
    Advisor.event(training,"move"); Advisor.update(training,0.1)
    Advisor.event(training,"attack"); Advisor.update(training,0.1)
    Advisor.event(training,"skill"); Advisor.update(training,0.1)
    Advisor.event(training,"economy"); Advisor.update(training,0.1)
    Advisor.event(training,"collect"); Advisor.update(training,0.1)
    Advisor.event(training,"recruit"); Advisor.update(training,0.1)
    Advisor.event(training,"research"); Advisor.update(training,0.1)
    assert(training.tutorial_complete and not training.tutorial_hold,"tutorial completes in order")
    local radiogame=Game.new()
    local rival=Unit.new(0,0,1,{stats={type="fighter"}})
    rival.character_id=11; radiogame:add_unit(rival)
    radiogame:report_event(rival,"command","ignored")
    assert(#(radiogame.reports or {})==0,"enemy command acknowledgements suppressed")
    radiogame:report_event(rival,"attack","")
    assert(#radiogame.reports==1 and radiogame.reports[1].unit==rival,"enemy taunt delivered")
    radiogame.reports={}
    for choice=1,2 do
        local exercise=Game.new()
        assert(levels.load_level("level_01.tbl",exercise))
        require("systems.simulation").deploy(exercise,choice==1 and "rune" or "moon",choice==1 and "moon" or "rune","spread")
        local deployed=0
        for _,actor in ipairs(exercise:get_units_by_team(exercise.player_team)) do
            if actor.unit_type~="mothership" then deployed=deployed+1 end
        end
        assert(deployed>0 and deployed<=require("systems.loadout").limit(),"deploy respects member cap")
        local seen={}
        for _,actor in ipairs(exercise.units) do
            assert(not seen[actor.character_id],"simulation has unique pilots")
            seen[actor.character_id]=true
            assert(actor.max_hp>=400,"simulation hull durability")
        end
        assert(exercise:get_mothership(0).character_id==(choice==1 and 0 or 20),"selected squad deploys")
        require("systems.mission_script").start(exercise,"level_01.tbl")
        assert(require("systems.mission_script").busy(exercise),"authored prebattle conversation")
    end
    local Skill=require("systems.skill")
    local healer=Unit.new(0,0,0,{stats={type="repair"}})
    local patient=Unit.new(100,0,0,{})
    local healing=Game.new(); healing:add_unit(healer); healing:add_unit(patient)
    patient.hp=patient.max_hp*0.1
    healer.skill_data={type="fleet_heal"}
    assert(Skill.can_execute(healer,healing)); Skill.execute(healer,healing)
    assert(patient.hp>patient.max_hp*0.4 and #healing.effects>0,"fleet heal produces effects")
    healer.skill_data={type="repair_tool",range=600}; healer.repair_target=patient
    assert(Skill.can_execute(healer,healing)); Skill.execute(healer,healing)
    assert(patient.hp==patient.max_hp,"targeted repair")
    for i=1,4 do local actor=Unit.new(0,0,0,{}); radiogame:add_unit(actor); radiogame:report_event(actor,"command","test") end
    assert(require("ui.comms").count(radiogame)==3,"bounded simultaneous radio")
    require("ui.comms").update(radiogame,6)
    assert(require("ui.comms").count(radiogame)==0,"radio expires")
    Verify.skill_repro()
    for _,name in ipairs(levels.scan_levels()) do
        local sim=Game.new()
        assert(levels.load_level(name,sim))
        for _=1,600 do sim:update(1/60) end
    end
    local file=assert(io.open(love.filesystem.getSource().."/verification.txt","w"))
    file:write("PASS: camera, commands, repair attack, navigation, skills, tutorial, radio, character IDs, economy payment/refund/production/research/income/pause/base-loss, all levels simulation\n")
    file:write("PASS: both squads on all mission objectives, escort loss/arrival, wave preservation, supply undocking, finite mineral yields, beam dodge, burst scheduling, dash collision, cutins, preferences, OGG decoding\n")
    file:close()
end
function Verify.pacing()
    local game=require("core.game").new()
    assert(require("levels.manager").load_level("level_01.tbl",game))
    local count=#game.units
    local initial={}
    for _,u in ipairs(game.units) do initial[#initial+1]=u end
    local first_shot,first_loss=nil,nil
    for i=1,5400 do
        game:update(1/30)
        if #game.projectiles>0 and not first_shot then first_shot=game.level_time end
        for _,u in ipairs(initial) do if not u.alive and not first_loss then first_loss=game.level_time end end
        if i==300 then assert(#game.units==count,"opening survives ten seconds") end
    end
    assert(first_shot,"enemy fleet advances and engages")
    local f=assert(io.open(love.filesystem.getSource().."/pacing-results.txt","w"))
    local survivors=0
    for _,u in ipairs(initial) do if u.alive then survivors=survivors+1 end end
    f:write(string.format("180s simulation: first projectile %.2fs, first loss %s, initial survivors %d/%d, active units including reinforcements %d\n",first_shot,tostring(first_loss),survivors,count,#game.units))
    f:close()
end
-- 必杀技全链路回归：部署各 playable 队伍（动态发现，不写死队名）→逐机型 use_skill→
-- 70 帧模拟（覆盖 windup 开火）→事件播报；并校验经济播报与左右手阵营绑定为通用行为。
-- 注意：本测试严禁直接调用 love.graphics 绘制——在 load 阶段绘制会破坏渲染状态导致段错误。
function Verify.skill_repro()
    local Game=require("core.game")
    local Manager=require("levels.manager")
    local Sim=require("systems.simulation")
    local Mission=require("systems.mission_script")
    local Registry=require("systems.pack_registry")
    for _,pid in ipairs(Registry.playable_ids()) do
        for _,lv in ipairs({"level_05.tbl","level_01.tbl"}) do
            local game=Game.new()
            assert(Manager.load_level(lv,game)); Mission.start(game,lv)
            Sim.deploy(game,pid,pid,"spread")
            -- 经济播报非空（不得回退成裸事件名）+ 左右手阵营绑定（敌方槽=阵营1、绑敌方队名）
            local Economy=require("systems.economy")
            require("systems.advisor").apply_squad(game)
            assert(game.researcher and game.researcher.unit,"researcher slot missing ["..pid.."]")
            Economy.say(game,"open")
            assert(game.researcher.text~="" and game.researcher.text~="open","economy open line missing ["..pid.."]")
            assert(game.logistics.tact.unit.team==1 and game.logistics.tact.unit.team_id==pid,"enemy tact hand faction ["..pid.."]")
            assert(game.logistics.almo.unit.team==1 and game.logistics.almo.unit.team_id==pid,"enemy almo hand faction ["..pid.."]")
            local tried={}
            for _,u in ipairs(game.units) do
                if u.alive and u.team==game.player_team and u.skill_data and u.skill_data.type and not tried[u.unit_type] then
                    tried[u.unit_type]=true
                    local enemies=game:get_enemy_units(u.team)
                    if enemies[1] then enemies[1].x,enemies[1].y=u.x+120,u.y end
                    u.sp=u.max_sp; u.skill_target=enemies[1]; u.attack_target=enemies[1]
                    game:select_unit(u)
                    local ok,err=pcall(function() return u:use_skill(game) end)
                    assert(ok,"use_skill 错误 ["..pid.." "..lv.." "..u.unit_type.."]: "..tostring(err))
                    local ok2,err2=pcall(function()
                        for _=1,70 do game:update(1/30) end
                        game:report_event(u,"skill","特殊装备启动！")
                    end)
                    assert(ok2,"技能更新错误 ["..pid.." "..lv.." "..u.unit_type.."]: "..tostring(err2))
                    game.cutins={};game.cinematic=nil;game.skill_slow=nil
                end
            end
            local f=assert(io.open(love.filesystem.getSource().."/verification.txt","a"))
            f:write("PASS: skill repro "..pid.." "..lv.."\n"); f:close()
        end
    end
end
return Verify
