_G.VERIFY_RUNNING=true
love={filesystem={},graphics={}}
function love.filesystem.read(path) local f=io.open(path,"rb");if not f then return nil end;local s=f:read("*a");f:close();return s end
function love.filesystem.getInfo(path) local f=io.open(path,"rb");if f then f:close();return {type="file"} end end
function love.filesystem.getDirectoryItems(path)
    if path=="assets/portraits" then return PORTRAITS end
    if TEAM_DIRS then
        local key=path
        if key:sub(1,6)=="teams/" then key=key:sub(7) end
        if TEAM_DIRS[key] then return TEAM_DIRS[key] end
    end
    return {}
end
local Game=require("core.game")
local Unit=require("entities.unit")
local Manager=require("levels.manager")
local Mission=require("systems.mission_script")
local Skill=require("systems.skill")
local function new_game()
    local g=Game.new();assert(Manager.load_level("level_01.tbl",g));return g
end
for n=0,10 do
    local g=new_game();Mission.start(g,string.format("level_%02d.tbl",n));Mission.update(g,0)
    assert(Mission.current(g),"mission opening")
    local old=Mission.current(g)
    Mission.start(g,string.format("level_%02d.tbl",n));Mission.update(g,0)
    local line,actor=Mission.current(g);assert(actor.game==g and old==line,"cached script has no game state")
    Mission.advance(g,true);assert(not Mission.busy(g))
    Mission.finish(g,"defeat");Mission.update(g,0);assert(not Mission.current(g),"mission scripts do not own result dialogue")
end
local g=new_game()
local u=Unit.new(0,0,0,Manager.unit_config("sniper"));g:add_unit(u)
local target=Unit.new(400,0,1,{max_hp=3000});g:add_unit(target)
u.team_id="rune";target.team_id="rune";g.team_id="rune"
u.sp=u.max_sp;u.skill_target=target
assert(u:use_skill(g));assert(u.skill_pending>1,"sniper charges")
require("battle.skills.registry").resolve("charge_beam").execute(u,g)
assert(target.hp<target.max_hp and #g.effects>0,"beam damages and draws")
local repair=Unit.new(0,0,0,Manager.unit_config("repair"));g:add_unit(repair)
local ms=g:get_mothership(0);repair.x,repair.y=ms.x,ms.y;repair.state="supplying"
repair:_state_supplying(0.1,g)
assert(repair.state=="undocking" and repair.target_pos,"full supply leaves dock")
assert(not repair.attack_target and not repair.follow_target,"supply clears stale goals")
local prefs=require("systems.preferences");prefs.set("auto_skill_"..repair.character_id,true)
repair.auto_skill=false;prefs.apply(repair);assert(repair.auto_skill,"preferences restore")
-- 队伍目录资源：立绘、名字与对白全部来自 teams/<队>/chara/<编号>。
local Pilots=require("ui.pilots")
assert(Pilots.profile({character_id=0,team_id="rune"}).name=="卡兹亚","rune commander name from team dir")
assert(Pilots.profile({character_id=20,team_id="moon"}).name=="塔克特","moon commander name from team dir")
assert(Pilots.profile({character_id=74,team_id="default"}).name=="索尔贝","default mixed pool name")
assert(love.filesystem.getInfo("teams/moon/chara/020/chara.png"),"moon commander standing art file")
for choice=1,2 do
    local sim=new_game()
    local pid,eid=choice==1 and "rune" or "moon",choice==1 and "moon" or "rune"
    require("systems.simulation").deploy(sim,pid,eid,"spread")
    assert(sim.player_team_id==pid and sim.enemy_team_id==eid,"team ids recorded")
    assert(sim:get_mothership(0).character_id==(choice==1 and 0 or 20),"commander per team.tbl")
end
print("PASS: mission lifecycle, skill targeting, beam impact, supply undocking, preferences, pilot assets, squads")
assert(require("tools.verify_missions").run())
assert(require("tools.verify_combat").run())
