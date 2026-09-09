local Sim={}
local Registry=require("systems.pack_registry")
-- 队内未指定机型时的默认出场序列（指挥官固定母舰）。
local DEFAULT_LINEUP={"mothership","fighter","sniper","artillery","light","repair","interceptor","tiger"}

local function real_teams()
    local out={}
    for _,id in ipairs(Registry.ids()) do
        if id~="default" and id~="random" then out[#out+1]=id end
    end
    if #out==0 then out={"rune","moon"} end
    return out
end

local function side_roster(side_id,excluded_ids)
    if side_id~="random" then
        local cfg=Registry.load(side_id).team or {}
        local commander=tonumber(cfg.commander)
        local members={}
        for _,cid in ipairs(cfg.chara or {}) do
            cid=tonumber(cid)
            if cid and (not commander or cid~=commander) then members[#members+1]={team=side_id,id=cid} end
        end
        return {
            commander={team=side_id,id=commander},
            left={team=side_id,id=tonumber(cfg.left)},
            right={team=side_id,id=tonumber(cfg.right)},
            members=members,
        }
    end
    -- 随机编队：从所有队伍（含混池）混编，内部与对方阵营角色均不重复
    return require("systems.random_roster").roster(excluded_ids)
end

-- 依据队伍 ID 组建双方舰队；"random" 表示从所有队伍随机混编。
function Sim.deploy(game,player_id,enemy_id,formation)
    local Unit=require("entities.unit")
    local Manager=require("levels.manager")
    local ms=game:get_mothership(0)
    local base={x=ms and ms.x or 1800,y=ms and ms.y or 1800}
    game.units={}; game.selected_units={}; game.next_unit_id=0
    game.simulation=true; game.formation=formation
    game.player_team_id=player_id or "rune"
    game.enemy_team_id=enemy_id or "moon"
    game.team_id=(game.player_team_id~="random" and game.player_team_id) or "rune"
    game.chosen_squad=nil
    -- 双方各自组建；随机编队排除对方已用角色，避免同角色跨阵营重复
    local pside,eside
    if game.enemy_team_id~="random" then
        pside=side_roster(game.player_team_id)
        eside=side_roster(game.enemy_team_id)
        if game.player_team_id=="random" then
            local ex={eside.commander.id}
            for _,m in ipairs(eside.members) do ex[#ex+1]=m.id end
            pside=side_roster("random",ex)
        end
    else
        pside=side_roster(game.player_team_id)
        local ex={pside.commander.id}
        for _,m in ipairs(pside.members) do ex[#ex+1]=m.id end
        eside=side_roster("random",ex)
    end
    local sides={pside,eside}
    game.advisor_set={
        tactical=sides[1].left.id, logistics=sides[1].right.id,
        critic=sides[2].left.id, cheer=sides[2].right.id,
    }
    game.advisor_teams={
        tactical=sides[1].left.team, logistics=sides[1].right.team,
        critic=sides[2].left.team, cheer=sides[2].right.team,
    }
    for team=0,1 do
        local tid=team==0 and game.player_team_id or game.enemy_team_id
        local side=sides[team+1]
        local roster={{pilot=side.commander,ship="mothership"}}
        for i,m in ipairs(side.members) do
            roster[#roster+1]={pilot=m,ship=DEFAULT_LINEUP[((i-1)%(#DEFAULT_LINEUP-1))+2]}
        end
        for i,entry in ipairs(roster) do
            local info=Registry.character(nil,entry.pilot.team,entry.pilot.id)
            local ship=entry.ship or (info and info.ship)
            if not ship then ship=DEFAULT_LINEUP[((i-1)%(#DEFAULT_LINEUP-1))+2] end
            local spread=formation=="spread" and 240 or 150
            local x=base.x+team*3000+((i-1)%3)*spread
            local y=base.y+math.floor((i-1)/3)*spread
            if formation=="wedge" then x=base.x+team*3000+math.abs(i-4)*100 end
            local u=Unit.new(x,y,team,Manager.unit_config(ship))
            u.character_id=entry.pilot.id
            u.team_id=entry.pilot.team
            u.rank=(info and info.rank) or (({[4]="中尉",[13]="中校",[20]="司令",[21]="副官"})[entry.pilot.id] or ((entry.pilot.id>=10 and entry.pilot.id<=15) and "少校" or "少尉"))
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
