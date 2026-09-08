_G.VERIFY_RUNNING=true
love={filesystem={},graphics={}}
function love.filesystem.read(path) local f=io.open(path,"rb");if not f then return nil end;local s=f:read("*a");f:close();return s end
function love.filesystem.getInfo(path) local f=io.open(path,"rb");if f then f:close();return {type="file"} end end
function love.filesystem.getDirectoryItems(path) return path=="assets/portraits" and PORTRAITS or {} end
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
    Mission.finish(g,"defeat");Mission.update(g,0);assert(Mission.current(g),"defeat scene")
end
local g=new_game()
local u=Unit.new(0,0,0,Manager.unit_config("sniper"));g:add_unit(u)
local target=Unit.new(400,0,1,{max_hp=3000});g:add_unit(target)
u.sp=u.max_sp;u.skill_target=target
assert(u:use_skill(g));assert(u.skill_pending>1,"sniper charges")
require("systems.special_attacks").execute(u,g)
assert(target.hp<target.max_hp and #g.effects>0,"beam damages and draws")
local repair=Unit.new(0,0,0,Manager.unit_config("repair"));g:add_unit(repair)
local ms=g:get_mothership(0);repair.x,repair.y=ms.x,ms.y;repair.state="supplying"
repair:_state_supplying(0.1,g)
assert(repair.state=="undocking" and repair.target_pos,"full supply leaves dock")
assert(not repair.attack_target and not repair.follow_target,"supply clears stale goals")
local prefs=require("systems.preferences");prefs.set("auto_skill_"..repair.character_id,true)
repair.auto_skill=false;prefs.apply(repair);assert(repair.auto_skill,"preferences restore")
assert(require("config.character_assets")[0]=="kazuya" and require("config.character_assets")[6]=="natsume")
for choice=1,2 do
    local sim=new_game();require("systems.simulation").deploy(sim,choice,"spread")
    assert(sim:get_mothership(0).character_id==(choice==1 and 0 or 20))
end
print("PASS: mission lifecycle, skill targeting, beam impact, supply undocking, preferences, pilot assets, squads")
assert(require("tools.verify_missions").run())
