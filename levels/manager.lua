-- Level loading and victory/defeat checking
local LevelManager = {}
local unit_configs = {}
local load_unit_config

function LevelManager.scan_levels()
    local levels = {}
    local files = love.filesystem.getDirectoryItems("levels")
    table.sort(files)
    for _, f in ipairs(files) do
        if f:match("^level_%d+%.tbl$") then
            table.insert(levels, f)
        end
    end
    return levels
end

function LevelManager.load_level(filename, game)
    local TBL = require("core.tbl")
    local data = TBL.parse_file("levels/" .. filename)
    if not data then return false, "Failed to parse level file" end

    game:reset()

    local Unit = require("entities.unit")
    local Terrain = require("systems.terrain")
    local SpaceScene = require("systems.space_scene")

    -- iterate all sections, handle by prefix
    local sections={}
    for name in pairs(data) do sections[#sections+1]=name end
    table.sort(sections,function(a,b)
        local ap,an=a:match("^(.-)%.(%d+)$")
        local bp,bn=b:match("^(.-)%.(%d+)$")
        if ap and ap==bp then return tonumber(an)<tonumber(bn) end
        return a<b
    end)
    for _,section_name in ipairs(sections) do
        local section_data=data[section_name]
        if type(section_data) ~= "table" then goto continue end

        -- terrain: sections like "terrain.1", "terrain.2", etc.
        if section_name:match("^terrain%.") then
            local terrain = Terrain.new(
                section_data.x or 0,
                section_data.y or 0,
                section_data.type or "asteroid",
                section_data.radius or 50
            )
            terrain.height = section_data.height
            game:add_terrain(terrain)
        elseif section_name == "background" then
            game.background = section_data
        elseif section_name:match("^environment%.") then
            game:add_environment(SpaceScene.new(section_data))
        -- player spawns: sections like "player.1", "player.2", etc.
        elseif section_name:match("^player%.") and section_data.unit_id then
            local unit_cfg = load_unit_config(section_data.unit_id)
            if unit_cfg then
                local pos = section_data.position or {}
                local x = pos[1] or section_data.x or math.random(300, 600)
                local y = pos[2] or section_data.y or math.random(300, 600)
                game:add_unit(Unit.new(x, y, game.player_team, unit_cfg))
            end
        -- enemy spawns: sections like "enemy.1", "enemy.2", etc.
        elseif section_name:match("^enemy%.") and section_data.unit_id then
            local unit_cfg = load_unit_config(section_data.unit_id)
            if unit_cfg then
                local pos = section_data.position or {}
                local x = pos[1] or section_data.x or math.random(800, 2000)
                local y = pos[2] or section_data.y or math.random(200, 600)
                game:add_unit(Unit.new(x, y, 1, unit_cfg))
            end
        elseif section_name:match("^wave%.") and section_data.unit_id then
            local unit_cfg = load_unit_config(section_data.unit_id)
            if unit_cfg then
                local pos = section_data.position or {}
                table.insert(game.pending_waves, {
                    time = section_data.time or 20,
                    team = section_data.team or 1,
                    cfg = unit_cfg,
                    count = section_data.count or 3,
                    x = pos[1] or section_data.x or 4800,
                    y = pos[2] or section_data.y or 1000,
                    spread = section_data.spread or 180,
                })
            end
        end

        ::continue::
    end

    if #game.environment_layers == 0 then
        for _, layer in ipairs(SpaceScene.default_layers(filename)) do
            game:add_environment(SpaceScene.new(layer))
        end
    end

    -- setup AI
    local pacing=require("config.pacing")
    local scale=(data.meta and data.meta.tutorial) and 1 or pacing.map_scale
    for _,u in ipairs(game.units) do u.x,u.y=u.x*scale,u.y*scale end
    for _,t in ipairs(game.terrain_objects) do t.x,t.y=t.x*scale,t.y*scale end
    for _,e in ipairs(game.environment_layers) do e.x,e.y,e.radius=e.x*scale,e.y*scale,e.radius*scale end
    for _,wave in ipairs(game.pending_waves) do wave.x,wave.y=wave.x*scale,wave.y*scale end
    game.opening_grace=pacing.opening_grace
    game.map_scale=scale
    local AI = require("systems.ai")
    local ai_cfg = data.ai or {}
    local difficulty = ai_cfg.difficulty or "normal"
    local personality = ai_cfg.personality or "balanced"
    table.insert(game.ai_controllers, AI.new(1, difficulty, personality))

    -- store level metadata
    local meta = data.meta or data["name"] or {}
    game.level_name = meta.value or meta.name or filename
    game.level_data = data
    game.level_filename=filename
    require("systems.economy").start(game)

    return true
end

function load_unit_config(unit_id)
    local TBL = require("core.tbl")

    -- check cache
    if unit_configs[unit_id] then
        return unit_configs[unit_id]
    end

    -- try TBL file
    local ok, cfg = pcall(function()
        return TBL.parse_file("config/units/" .. unit_id .. ".tbl")
    end)
    if ok and cfg then
        local p=require("config.pacing")
        cfg.stats.max_hp=math.floor((cfg.stats.max_hp or 100)*p.hull_multiplier)
        cfg.stats.attack_cooldown=(cfg.stats.attack_cooldown or 1)*p.cooldown_multiplier
        cfg.stats.projectile_speed=(cfg.stats.projectile_speed or 400)*p.projectile_speed_multiplier
        unit_configs[unit_id] = cfg
        return cfg
    end

    print("Warning: unit config not found: " .. unit_id)
    return nil
end

LevelManager.unit_config=load_unit_config

function LevelManager.check_victory(game)
    if game.objective then return game.objective.complete and not game.objective.failed and game:get_mothership(game.player_team)~=nil end
    local data = game.level_data
    if not data then
        return #game:get_enemy_units(game.player_team) == 0
    end

    local vc = data.victory_conditions or data.victory or {}
    if vc.eliminate_all then
        return #game:get_enemy_units(game.player_team) == 0
    end
    if vc.eliminate_mothership then
        local ms = game:get_mothership(1 - game.player_team)
        return not ms or not ms.alive
    end
    if vc.survive_time then
        return game.level_time >= tonumber(vc.survive_time)
    end
    return #game:get_enemy_units(game.player_team) == 0
end

function LevelManager.check_defeat(game)
    if game.objective then return game.objective.failed or not game:get_mothership(game.player_team) end
    local data = game.level_data
    if not data then
        return #game:get_units_by_team(game.player_team) == 0
    end

    local dc = data.defeat_conditions or data.defeat or {}
    if dc.lose_all then
        return #game:get_units_by_team(game.player_team) == 0
    end
    if dc.lose_mothership then
        local ms = game:get_mothership(game.player_team)
        return not ms or not ms.alive
    end
    if dc.time_limit then
        return game.level_time >= tonumber(dc.time_limit)
    end
    return #game:get_units_by_team(game.player_team) == 0
end

return LevelManager
