-- Behavioral regressions for shared combat state, delayed fire and steering.
local Test={}
function Test.run()
    local Unit=require("entities.unit")
    local Weapons=require("battle.unit.weapons")
    local Manager=require("levels.manager")
    local Projectile=require("entities.projectile")
    local g={player_team=-1,level_time=0,terrain_objects={},units={},projectiles={},effects={}}
    function g:is_position_blocked() return false end
    function g:report_event() end
    function g:add_projectile(p) self.projectiles[#self.projectiles+1]=p end
    function g:add_effect(e) self.effects[#self.effects+1]=e end
    function g:get_enemy_units(team)
        local out={};for _,u in ipairs(self.units) do if u.team~=team and u.alive then out[#out+1]=u end end
        return out
    end
    local cfg={stats={attack_damage=100,attack_range=600},
        ["weapon.a"]={type="ranged",visual="interceptor_tracer",damage=40,count=2,burst_count=2,burst_delay=0.1,projectile_speed=1400,arc=360},
        ["weapon.b"]={type="missile",damage=20,count=1,projectile_speed=300,arc=360}}
    local a,b=Unit.new(0,0,0,cfg),Unit.new(0,0,1,cfg)
    Weapons.on_fire(a.weapons[1],1);a.weapons[1].cooldown_timer=10
    assert(b.weapons[1].heat==0 and b.weapons[1].cooldown_timer==0,"per-unit weapon state")
    assert(cfg["weapon.a"].id==nil and cfg["weapon.a"].heat==nil,"config remains immutable")
    a.weapons[1].cooldown_timer=0
    local target=Unit.new(300,0,1,{max_hp=10000})
    a.angle=0;a.attack_target=target;a.state="attacking"
    a:apply_buff("attack",2,5)
    a:_try_attack(g)
    assert(#g.projectiles==3 and #a.burst_queue==2,"mixed immediate and delayed fire")
    assert(g.projectiles[1].damage==40,"attack buffs affect configured weapons")
    a:_update_burst_queue(0.2,g)
    assert(#g.projectiles==5 and g.projectiles[5].style=="interceptor_tracer","burst retains weapon visual")
    assert(g.projectiles[5].speed==1400 and g.projectiles[5].damage==40 and not g.projectiles[5].homing,"burst retains ballistics and damage")
    assert(a.attack_damage==100 and a.projectile_count==1,"firing and buffs never overwrite base stats")
    local victim=Unit.new(0,0,0,{})
    victim:take_damage(1,target);assert(victim.attack_target==target,"retaliation acquires attacker")
    victim:take_damage(1,b);assert(victim.attack_target==target,"retaliation preserves live target")
    target.alive=false;victim:take_damage(1,b);assert(victim.attack_target==b,"retaliation replaces dead target")
    local collector=Unit.new(0,0,0,{type="collector"})
    collector:take_damage(1,b);assert(not collector.attack_target,"collector cannot enter combat")
    local shell=Projectile.artillery(0,0,1200,0,10,60,155,0,0,"artillery",a)
    assert(shell.life>1200/155,"artillery lifetime covers travel")
    local shooter=Unit.new(0,0,0,{})
    local distant=Unit.new(1000,0,1,{max_hp=1000})
    local p=Projectile.basic(0,0,1000,0,20,10000,distant,0,"sniper_rifle",shooter)
    p:update(0.2,g)
    assert(not p.alive and distant.hp==980 and distant.attack_target==shooter,"fast projectile sweeps hit and attributes damage")
    -- Mirrored snipers must keep sailing and actually fire while turning.
    for _,team in ipairs({0,1}) do
        local sniper=Unit.new(0,0,team,Manager.unit_config("sniper"))
        local enemy=Unit.new(team==0 and 900 or -900,0,1-team,{max_hp=100000})
        g.units={sniper,enemy};g.projectiles={}
        sniper.attack_target=enemy;sniper.state="attacking";sniper.angle=0
        local traveled=0
        for _=1,900 do
            local x,y=sniper.x,sniper.y
            g.level_time=g.level_time+1/60;sniper:update(1/60,g)
            traveled=traveled+math.sqrt((sniper.x-x)^2+(sniper.y-y)^2)
        end
        assert(traveled>300 and #g.projectiles>=1,"sniper sails and fires on both teams")
        enemy.x=sniper.x+sniper.attack_range*1.3;enemy.y=sniper.y
        local before_x=sniper.x
        sniper:_state_attacking(1/60,g)
        assert(math.abs(sniper.x-before_x)>0.1,"out-of-range pursuit closes distance")
        sniper.state="returning";sniper.behavior.update(sniper,0.1,g)
        assert(sniper.state=="returning","sniper behavior respects supply orders")
    end
    -- Arrival must be measured from actual movement, never the requested step.
    -- 每种机型的战术脚本都要在窗口内实际开火且位移有界（不无限漂移）。
    local engage_dist={fighter=200,interceptor=200,heavy=380,tiger=480,light=200,scout=380,
        gunship=400,carrier=560,missile_frigate=700,artillery=1000,bomber=640,repair=180}
    for kind,dist in pairs(engage_dist) do
        local ship=Unit.new(0,0,0,Manager.unit_config(kind))
        local enemy=Unit.new(dist,0,1,{max_hp=100000})
        ship.angle=0;ship.attack_target=enemy;ship.state="attacking";g.units={ship,enemy};g.projectiles={}
        for _=1,1200 do g.level_time=g.level_time+1/60;ship:update(1/60,g) end
        assert(#g.projectiles>1,"type tactics keep firing: "..kind)
        assert(math.abs(ship.x)<2600 and math.abs(ship.y)<2600,"type tactics keep position bounded: "..kind)
    end
    local sniper_cfg=Manager.unit_config("sniper").stats
    local fighter_cfg=Manager.unit_config("fighter").stats
    -- pacing 伤害倍率在配置加载时已乘入：加载后的数值即实际结算数值。
    local fraction=sniper_cfg.attack_damage/fighter_cfg.max_hp
    assert(fraction>=0.33 and fraction<0.36,"sniper benchmark against standard fighter")
    local duel={Unit.new(-450,0,0,Manager.unit_config("sniper")),Unit.new(450,0,1,Manager.unit_config("sniper"))}
    g.units=duel;g.projectiles={}
    for i,ship in ipairs(duel) do ship.state="attacking";ship.attack_target=duel[3-i];ship.angle=i==1 and 0 or math.pi end
    for _=1,3600 do
        g.level_time=g.level_time+1/60
        for _,ship in ipairs(duel) do
            ship:update(1/60,g)
            local speed=math.sqrt(ship.vx^2+ship.vy^2)
            if speed>1 then
                assert((ship.vx*math.cos(ship.angle)+ship.vy*math.sin(ship.angle))/speed>0.99,"flight follows nose")
            end
            assert(math.abs(ship.x)<2500 and math.abs(ship.y)<2500,"sniper duel stays near engagement")
        end
    end
    assert(#g.projectiles>=6,"dueling snipers keep firing")
    local moving=Unit.new(0,0,0,{speed=200,acceleration=1})
    moving.state="moving"
    assert(not moving:_move_towards(10,0,20,g) and moving.x<1,"low acceleration does not falsely arrive")
    local Combat=require("battle.unit.combat")
    for _,team in ipairs({0,1}) do
        local ship=Unit.new(0,0,team,Manager.unit_config("sniper"))
        local close=Unit.new(100,0,1-team,{max_hp=100000})
        ship.angle=0;ship.state="attacking";ship.attack_target=close
        g.units={ship,close};g.projectiles={}
        assert(not ship:_try_attack(g),"sniper cannot fire point blank")
        local escaped,boosted=false,false
        for _=1,1200 do
            g.level_time=g.level_time+1/60
            ship:update(1/60,g)
            if ship:distance_to(close)>=ship.behavior_config.safe_distance then escaped=true end
            if math.sqrt(ship.vx^2+ship.vy^2)>ship.base_speed*1.3 then boosted=true end
        end
        assert(escaped and boosted,"close-range sniper escapes with forward boost on either team")
        assert(#g.projectiles>0,"sniper resumes ranged fire after escape")
        ship.state="returning";ship.behavior.update(ship,0,g)
        assert(not ship.sniper_escape and not ship._approach_speed_multiplier,"escape clears on supply order")
        ship.state="attacking";ship.attack_target=Unit.new(ship.x+1000,ship.y,1-team,{})
        local flanker=Unit.new(ship.x+80,ship.y,1-team,{})
        g.units={ship,ship.attack_target,flanker};ship:update(1/60,g)
        assert(ship.sniper_escape and ship.sniper_escape.threat==flanker,"unlocked close threat triggers escape")
    end
    -- The sniper escape must change lateral sign at least once instead of flying one-way.
    local evasive=Unit.new(0,0,0,Manager.unit_config("sniper"))
    local pursuer=Unit.new(100,0,1,{max_hp=100000,speed=120})
    g.units={evasive,pursuer};g.projectiles={};evasive.attack_target=pursuer;evasive.state="attacking";evasive.angle=0
    local lateral_signs={};local last_y=evasive.y
    for _=1,240 do
        g.level_time=g.level_time+1/60;evasive:update(1/60,g)
        if evasive.sniper_escape and evasive.sniper_escape.lateral_sign then lateral_signs[#lateral_signs+1]=evasive.sniper_escape.lateral_sign end
        local dy=evasive.y-last_y
        last_y=evasive.y
    end
    local changed=false
    for i=2,#lateral_signs do if lateral_signs[i]~=lateral_signs[i-1] then changed=true;break end end
    assert(changed,"sniper escape reverses lateral direction")
    local function burst_unit()
        local ship=Unit.new(0,0,0,{stats={attack_range=600},["weapon.test"]={count=2,burst_count=3,burst_delay=0.1,damage=20,arc=90,energy_cost=6,heat_per_shot=1,max_heat=100,cool_rate=0}})
        ship.angle=0;ship.state="attacking";ship.attack_target=Unit.new(200,0,1,{max_hp=10000})
        ship.energy=20;ship.sp=0
        return ship
    end
    -- SP 不再按发结算：整轮连发期间 sp 保持 0，命中后由伤害回充（见下方 SP 回归）。
    local burst=burst_unit();burst:_try_attack(g)
    assert(burst.energy==18 and burst.sp==0 and burst.weapons[1].heat==2,"only emitted shots are charged")
    burst.attack_target.x=-200;burst:_update_burst_queue(1,g)
    assert(burst.energy==18 and burst.sp==0 and burst.weapons[1].heat==2 and #burst.burst_queue==0,"out-of-arc burst cancelled without cost")
    assert(not burst.weapons[1].burst_pending,"cancelled cycle unlocks weapon")
    burst=burst_unit();burst.weapons[1].max_heat=3;burst:_try_attack(g);burst:_update_burst_queue(1,g)
    assert(burst.energy==17 and burst.sp==0 and burst.weapons[1].heat==3,"overheat stops subsequent projectiles")
    burst=burst_unit();burst.energy=3;burst:_try_attack(g);burst:_update_burst_queue(1,g)
    assert(burst.energy==0 and burst.sp==0 and burst.weapons[1].heat==3,"energy never overdrawn")
    burst=burst_unit();burst:_try_attack(g);burst:_update_burst_queue(1,g)
    assert(burst.energy==14 and burst.sp==0 and burst.weapons[1].heat==6,"complete cycle has deterministic budget")
    burst=burst_unit();burst:_try_attack(g);require("ui.selection_controller").set_returning(nil,{burst})
    assert(#burst.burst_queue==0 and not burst.weapons[1].burst_pending,"return command clears cycle lock")
    -- SP 来源是实际伤害：造成伤害回充、承受伤害回充、技能弹不回流、维修回充。
    do
        local pacing=require("config.pacing")
        local shooter=Unit.new(0,0,0,{})
        local victim=Unit.new(300,0,1,{max_hp=100000})
        g.units={shooter,victim};g.projectiles={}
        local shot=Projectile.basic(0,0,300,0,100,5000,victim,0,"main_gun",shooter)
        while shot:update(1/60,g) do end
        assert(victim.hp==victim.max_hp-100 and shooter.sp>0,"damage dealt charges SP")
        assert(math.abs(shooter.sp-100*pacing.sp_per_damage_dealt)<1e-9,"dealt SP uses pacing rate")
        assert(math.abs(victim.sp-100*pacing.sp_per_damage_taken)<1e-9,"taken SP uses pacing rate")
        local sp_before=shooter.sp
        local keeper=Unit.new(300,0,1,{max_hp=100000})
        local no_sp_shot=Projectile.basic(0,0,300,0,100,5000,keeper,0,"missile",shooter)
        no_sp_shot.no_sp=true
        g.units={shooter,keeper};g.projectiles={no_sp_shot}
        while no_sp_shot:update(1/60,g) do end
        assert(keeper.hp==keeper.max_hp-100 and shooter.sp==sp_before,"skill projectiles do not refund SP")
        local medic=Unit.new(0,0,0,{})
        local wounded=Unit.new(50,0,0,{max_hp=5000})
        wounded.hp=2500;medic.repair_target=wounded;medic.state="repairing";medic.energy=20;medic.sp=0
        medic:_state_repairing(1/60,g)
        assert(wounded.hp==wounded.max_hp and medic.sp==2500*pacing.sp_per_repair,"repair charges SP by healed amount")
    end
    -- Existing type tactics must choose one movement, not integrate before and after the state machine.
    local artillery=Unit.new(0,0,0,Manager.unit_config("artillery"))
    artillery.state="attacking";artillery.attack_target=Unit.new(1000,0,1,{})
    local integrations=0;local move=artillery._move_towards
    artillery._move_towards=function(self,...) integrations=integrations+1;return move(self,...) end
    artillery:update(0.1,g)
    assert(integrations==1,"type tactics integrate exactly once")
    integrations=0
    artillery.attack_target=Unit.new(100,0,1,{})
    artillery:update(0.1,g)
    assert(integrations==0,"inside too_close the straight engine brakes without integrating")
    local Loader=require("battle.unit.type_loader")
    for _,kind in ipairs({"fighter","interceptor"}) do
        assert(require("battle.unit.type_loader").load(kind)==require("battle.unit.types."..kind),"new type selected")
        for _,team in ipairs({0,1}) do
            local ship=Unit.new(0,0,team,Manager.unit_config(kind))
            local sign=team==0 and 1 or -1
            local enemy=Unit.new(sign*500,0,1-team,{max_hp=100000,radius=25})
            enemy.vx=sign*35;enemy.vy=0
            ship.angle=team==0 and 0 or math.pi;ship.state="attacking";ship.attack_target=enemy
            g.units={ship,enemy};g.projectiles={}
            local peak_speed=0;local phases=0
            for _=1,1800 do
                enemy.x=enemy.x+enemy.vx/60;g.level_time=g.level_time+1/60
                ship:update(1/60,g)
                if ship.intercept_pass or ship.fighter_pass then phases=phases+1 end
                local speed=math.sqrt(ship.vx^2+ship.vy^2);peak_speed=math.max(peak_speed,speed)
                if speed>1 then assert((ship.vx*math.cos(ship.angle)+ship.vy*math.sin(ship.angle))/speed>0.99,"forward thrust during attack run") end
                for i=#g.projectiles,1,-1 do
                    local p=g.projectiles[i];p:update(1/60,g)
                    if not p.alive then table.remove(g.projectiles,i) end
                end
            end
            assert(phases>0 and enemy.hp<enemy.max_hp,"attack passes actually hit moving targets: "..kind)
            assert(peak_speed>ship.base_speed*1.05,"approach accelerates: "..kind)
            enemy.alive=false
            local replacement=Unit.new(ship.x+100,ship.y,1-team,{max_hp=10000})
            g.units={ship,replacement};ship.retarget_timer=0;ship:update(1/60,g)
            assert(ship.attack_target==replacement,"dead target replaced: "..kind)
            require("ui.selection_controller").set_returning(nil,{ship})
            ship.behavior.update(ship,0,g)
            assert(not ship.intercept_pass and not ship.fighter_pass and not ship._approach_speed_multiplier,"orders clear type maneuver")
        end
    end
    local used_old=false
    package.preload["battle.unit.types.test_broken"]=function() error("broken dependency") end
    package.preload["units.test_broken.logic"]=function() used_old=true;return {update=function() end} end
    local ok,err=pcall(Loader.load,"test_broken")
    assert(not ok and tostring(err):find("broken dependency",1,true) and not used_old,"load error must not fall back")
    package.preload["battle.unit.types.test_invalid"]=function() return {} end
    assert(not pcall(Loader.load,"test_invalid"),"invalid module rejected")
    package.preload["units.test_legacy.logic"]=function() return {update=function() end} end
    assert(Loader.load("test_legacy")==nil,"missing type module yields nil without legacy fallback")
    for _,name in ipairs({"battle.unit.types.test_broken","units.test_broken.logic","battle.unit.types.test_invalid","units.test_legacy.logic"}) do package.preload[name]=nil;package.loaded[name]=nil end
    -- 命令层：玩家命令优先，自动命令经仲裁，命令完成点清除。
    local Commands=require("battle.commands")
    do
        local ship=Unit.new(0,0,0,{speed=300})
        local foe=Unit.new(500,0,1,{max_hp=100000})
        g.units={ship,foe}
        assert(Commands.issue(g,ship,"attack",{target=foe}) and ship.state=="attacking","auto attack issues")
        assert(Commands.issue(g,ship,"move",{source="player",x=0,y=300}) and ship.state=="moving","player move overrides auto")
        assert(not Commands.issue(g,ship,"attack",{target=foe}),"auto rejected while player command active")
        Commands.finish(ship)
        assert(Commands.issue(g,ship,"attack",{target=foe}),"auto resumes after finish")
        assert(not Commands.issue(g,ship,"attack",{target=foe}),"identical auto attack is idempotent")
        ship.command={kind="attack",source="player",target=foe}
        ship.attack_target=foe;ship.state="attacking"
        foe.alive=false
        ship:_state_attacking(0.01,g)
        assert(ship.state=="idle" and ship.command==nil,"target death finishes player command")
    end
    -- AI 分层：等值目标集火不翻转；难度区分集火服从度。
    do
        local Controller=require("battle.ai.controller")
        local Focus=require("battle.ai.focus")
        local Executor=require("battle.ai.executor")
        local easy=Controller.new(1,"easy","balanced")
        local insane=Controller.new(1,"insane","balanced")
        local t1=Unit.new(0,0,0,{max_hp=1000,attack_damage=10})
        local t2=Unit.new(300,0,0,{max_hp=1000,attack_damage=10})
        local enemies={t1,t2}
        for _=1,120 do Focus.update(easy,enemies) end
        assert(easy.focus_target==t1 or easy.focus_target==t2,"focus picks a target")
        local first=easy.focus_target
        for _=1,10 do Focus.update(easy,enemies) end
        assert(easy.focus_target==first,"equal targets do not flip focus")
        local shooter=Unit.new(400,0,1,{attack_damage=10})
        easy.focus_target=t1;insane.focus_target=t1
        assert(Executor.score_focus_fire(insane,shooter,enemies)>Executor.score_focus_fire(easy,shooter,enemies),
            "coordination differentiates difficulty focus compliance")
    end
    print("PASS: combat regression, single movement, strict loading, emitted-shot accounting and cancellation")
    return true
end
return Test
