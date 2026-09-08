local Sim={}
local teams=require("config.squadrons")
function Sim.deploy(game,choice,formation)
    local Unit=require("entities.unit")
    local Manager=require("levels.manager")
    local ms=game:get_mothership(0)
    local base={x=ms and ms.x or 1800,y=ms and ms.y or 1800}
    game.units={}; game.selected_units={}; game.next_unit_id=0
    game.simulation=true; game.chosen_squad=choice; game.formation=formation
    for team=0,1 do
        local squad=teams[team==0 and choice or (3-choice)]
        for i,member in ipairs(squad.members) do
            local spread=formation=="spread" and 240 or 150
            local x=base.x+team*3000+((i-1)%3)*spread
            local y=base.y+math.floor((i-1)/3)*spread
            if formation=="wedge" then x=base.x+team*3000+math.abs(i-4)*100 end
            local u=Unit.new(x,y,team,Manager.unit_config(member[2]))
            u.character_id=member[1]
            u.rank=({[4]="中尉",[13]="中校",[20]="司令",[21]="副官"})[member[1]] or ((member[1]>=10 and member[1]<=15) and "少校" or "少尉")
            local px,py=game:find_clear_position(x,y,u.radius)
            u.x,u.y=px,py
            game:add_unit(u)
        end
    end
    game.reports={}
    require("systems.advisor").apply_squad(game)
    require("systems.objectives").start(game)
    if game.advisor then game.advisor.enemy_count=#game:get_enemy_units(game.player_team) end
end
return Sim
