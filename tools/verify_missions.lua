local V={}
function V.run()
    local Game=require("core.game")
    local Manager=require("levels.manager")
    local Mission=require("systems.mission_script")
    local Sim=require("systems.simulation")
    local Objectives=require("systems.objectives")
    for n=1,10 do
        for choice=1,2 do
            local game=Game.new()
            local file=string.format("level_%02d.tbl",n)
            assert(Manager.load_level(file,game));Mission.start(game,file)
            local waves=#game.pending_waves
            Sim.deploy(game,choice==1 and "rune" or "moon",choice==1 and "moon" or "rune","spread")
            assert(#game.pending_waves>=waves,"deployment preserves mission waves")
            assert(game.objective and not Manager.check_victory(game),"mission starts incomplete")
            Mission.update(game,0)
            local _,actor=Mission.current(game)
            assert(actor and actor.game==game,"story speaker binds current match")
            Mission.advance(game,true)
            local o=game.objective
            if o.spec.type=="escort" then
                o.unit.x,o.unit.y=o.x,o.y;Objectives.update(game,0.1)
                assert(Manager.check_victory(game),"escort arrival wins")
                o.complete=false;o.unit.alive=false;Objectives.update(game,0.1)
                assert(Manager.check_defeat(game),"escort loss fails")
            elseif o.spec.type=="survive" then
                Objectives.update(game,o.spec.duration)
                assert(Manager.check_victory(game),"survival objective")
            elseif o.spec.type=="flagship" then
                game:get_mothership(1).alive=false;Objectives.update(game,0.1)
                assert(Manager.check_victory(game),"enemy flagship objective")
            else
                for _,u in ipairs(game:get_enemy_units(0)) do u.alive=false end
                game.pending_waves={{team=1,time=999}}
                Objectives.update(game,0.1);assert(not Manager.check_victory(game),"wait for scheduled enemies")
                game.pending_waves={};Objectives.update(game,0.1)
                assert(Manager.check_victory(game),"all waves cleared")
            end
            game:get_mothership(0).alive=false
            assert(Manager.check_defeat(game) and not Manager.check_victory(game),"base loss overrides victory")
            Mission.finish(game,"defeat");Mission.update(game,0)
            assert(Mission.current(game),"authored defeat scene")
            -- 剧情生命周期回归：interlude 一次性、finish 幂等、跳过开场不阻断中场。
            game.mission={script={interludes={{time=0,id=25,text="t"}},victory={{id=25,text="v"},{id=25,text="v2"}}},shown={},queue={},actors={},age=0}
            Mission.tick(game);Mission.tick(game)
            assert(#game.mission.queue==1,"interlude fires exactly once")
            Mission.finish(game,"victory");Mission.finish(game,"victory")
            assert(#game.mission.queue==2,"finish scenes fire exactly once")
            game.mission={script={interludes={{time=1,id=22,text="n"}}},shown={},queue={},actors={},age=0}
            game.level_time=5
            Mission.tick(game)
            assert(#game.mission.queue==1,"skipping intro keeps interludes")
        end
    end
    local Unit=require("entities.unit")
    local dock=Game.new()
    local base=Unit.new(0,0,0,Manager.unit_config("mothership"));dock:add_unit(base)
    local shuttle=Unit.new(20,0,0,Manager.unit_config("fighter"));dock:add_unit(shuttle)
    shuttle.state="supplying";shuttle.attack_target=base;shuttle.follow_target=base
    for _=1,400 do dock:update(0.025) end
    assert(shuttle.state=="idle" and shuttle:distance_to(base)>150,"supply ship leaves mother hull and stays idle")
    local minerals=Game.new();assert(Manager.load_level("level_01.tbl",minerals))
    local Economy=require("systems.economy")
    assert(Economy.enqueue(minerals,"collector"));Economy.update(minerals,25)
    local node=minerals.minerals[1]
    assert(node.station and node.station.alive,"station placed on mineral node")
    node.remaining=2
    local credits=minerals.economy.credits
    Economy.update(minerals,1)
    assert(node.remaining==0 and minerals.economy.credits==credits+5,"finite mineral yield")
    local station=node.station;station.alive=false
    node.remaining=100
    assert(require("systems.minerals").available(minerals)==node,"destroyed station frees mine")
    local Pref=require("systems.preferences")
    local savedValues=Pref.values
    Pref.values={};Pref.set("auto_skill_4",true);Pref.set("auto_skill_6",false);Pref.set("volume",0.4)
    assert(Pref.get("auto_skill_4",false) and not Pref.get("auto_skill_6",true) and Pref.get("volume",1)==0.4,"per-pilot preference keys")
    Pref.values.volume="bad";assert(Pref.get("volume",0.65)==0.65,"malformed preference falls back")
    Pref.values=savedValues
    local Slots=require("systems.comms_slots")
    local slot=Slots.new({unit_type="researcher",character_id=22})
    Slots.say(slot,"a","idle",4);Slots.say(slot,"b","idle",4)
    assert(slot.text=="a" and #slot.queue==1,"first message shows and second queues")
    for _=1,50 do Slots.update(slot,0.1) end
    assert(slot.text=="b" and #slot.queue==0,"queued message shows after first expires")
    local econ=Game.new();Economy.start(econ)
    assert(econ.logistics.tact and econ.logistics.almo and econ.logistics.enemy,"logistics slots exist")
    assert(econ.logistics.enemy.unit.game==econ and econ.logistics.enemy.unit.team==1,"enemy slot carries faction")
    Economy.say(econ,"x");Economy.say(econ,"y")
    assert(econ.researcher.text=="x" and econ.researcher.queue[1].text=="y","economy feedback queues per slot")
    local Special=require("systems.special_attacks")
    local g=Game.new()
    local u=Unit.new(0,0,0,Manager.unit_config("sniper"));u.character_id=4;g:add_unit(u)
    local t=Unit.new(400,0,1,{max_hp=3000});g:add_unit(t)
    u.skill_target=t;Special.prepare(u);t.y=150
    Special.execute(u,g);assert(t.hp==t.max_hp,"locked beam can be dodged")
    u.skill_data={type="sweep_bombardment",count=12,damage=65,range=1500};u.skill_target=t;Special.prepare(u)
    Special.execute(u,g);Special.update(g,1)
    assert(#g.projectiles==12 and #g.skill_jobs==0,"barrage schedules twelve shots")
    u.skill_data={type="dash_strike",range=650,damage=380};t.x,t.y=400,0;u.skill_target=t;Special.prepare(u);Special.execute(u,g)
    for _=1,10 do Special.update_dash(u,0.05,g) end
    assert(u.x>400 and t.hp<t.max_hp,"dash moves and hits")
    local hp=t.hp;Special.update_dash(u,1,g);assert(t.hp==hp,"dash hits once")
    local Cinema=require("systems.cinematic")
    Cinema.start(g,u);Cinema.start(g,t)
    assert(#g.cutins==2,"simultaneous compact cutins")
    Cinema.update(g,3);assert(not g.cinematic and #g.cutins==0,"cutins expire")
    return true
end
function V.pacing()
    local Game=require("core.game")
    local Manager=require("levels.manager")
    local results={}
    for n=1,10 do
        local game=Game.new();local file=string.format("level_%02d.tbl",n)
        assert(Manager.load_level(file,game));require("systems.mission_script").start(game,file)
        require("systems.simulation").deploy(game,"rune","moon","spread")
        require("systems.mission_script").advance(game,true)
        local first_loss,result
        for _=1,3600 do
            game:update(0.05)
            if game.losses>0 and not first_loss then first_loss=game.level_time end
            if Manager.check_defeat(game) then result="defeat";break end
            if Manager.check_victory(game) then result="victory";break end
            for _,u in ipairs(game.units) do assert(u.x==u.x and u.y==u.y,"finite unit coordinates") end
        end
        results[#results+1]=string.format("%02d: time=%.1f result=%s first_friendly_loss=%s active=%d objective=%s progress=%.2f",n,game.level_time,result or "ongoing",first_loss and string.format("%.1f",first_loss) or "none",#game.units,game.objective.spec.type,game.objective.progress)
    end
    local f=assert(io.open("mission-pacing.txt","w"));f:write(table.concat(results,"\n"));f:close()
end
return V
