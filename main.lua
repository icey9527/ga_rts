-- Deep Space Command - Love2D entry point.

local Camera = require("core.camera")
local Game = require("core.game")
local TBL = require("core.tbl")
local LevelManager = require("levels.manager")
local ContextMenu = require("ui.context_menu")
local UnitPanel = require("ui.unit_panel")
local HUD = require("ui.hud")
local Screens = require("ui.screens")
local MainMenu = require("ui.main_menu")
local SpaceScene = require("systems.space_scene")
local SelectionPanel = require("ui.selection_panel")
local ShipRenderer = require("systems.ship_renderer")
local Comms = require("ui.comms")
local Orders = require("systems.orders")
local Markers = require("ui.tactical_markers")
local Advisor=require("systems.advisor")
local Cinema=require("systems.cinematic")
local EconomyPanel=require("ui.economy_panel")
local SkillVisuals=require("systems.skill_visuals")
local Deployment=require("ui.deployment")
local Mission=require("systems.mission_script")
local Simulation=require("systems.simulation")
local Registry=require("systems.pack_registry")

local game
local camera
local settings = {}
local level_files = {}
local current_level_name = ""
local current_level_file = ""
local menu
local level_names = {}
local level_scores = {}
local high_scores = {}

local context_menu
local global_menu
local unit_panel

local hide_all_menus
local start_targeting
local cancel_command
local show_context_menu
local execute_menu_action
local execute_global_command
local execute_targeted_command
local direct_attack

local selection_start
local selection_rect
local dragging_camera = false
local drag_start_x, drag_start_y = 0, 0
local drag_cam_x, drag_cam_y = 0, 0

local command_mode = "normal"
local command_action
local command_hover_target
local command_feedbacks = {}
local pending_command_units = {}
local game_state = "menu"
local command_pause_before = nil

local function pause_for_command()
    if command_pause_before == nil then command_pause_before=game:is_paused() end
    game:pause()
end

local function restore_command_pause()
    if command_pause_before ~= nil then
        game.paused=command_pause_before
        command_pause_before=nil
    end
end

local function get_units_center()
    local ux, uy, count = 0, 0, 0
    for _, u in ipairs(game.units) do
        if u.alive and u.state ~= "dead" then
            ux = ux + u.x
            uy = uy + u.y
            count = count + 1
        end
    end
    if count > 0 then return ux / count, uy / count end
    return 600, 500
end

local function load_high_scores()
    high_scores = {}
    local data = TBL.parse_file("high_scores.tbl")
    if not data then return end

    local scores = data.scores or data
    for key, value in pairs(scores) do
        if type(value) == "number" then
            high_scores[key] = value
        end
    end
end

local function save_high_score()
    if current_level_name == "" then return end
    if game.score <= (high_scores[current_level_name] or 0) then return end

    high_scores[current_level_name] = game.score
    love.filesystem.write("high_scores.tbl", TBL.serialize({scores = high_scores}))
end

local function calc_score()
    local sc = settings.score or {}
    local base = sc.base_victory or 1000
    local time_target = sc.time_target or 300
    local time_bonus_max = sc.time_bonus_max or 500
    local time_bonus = 0

    if game.level_time < time_target then
        time_bonus = math.floor(time_bonus_max * (1 - game.level_time / time_target))
    end

    local survival = #game:get_units_by_team(game.player_team)
    local survival_bonus = survival * (sc.unit_survival or 100)
    local enemies_left = #game:get_enemy_units(game.player_team)
    local enemy_bonus = math.max(0, 10 - enemies_left) * (sc.enemy_defeat or 50)
    local mothership_bonus = game:get_mothership(game.player_team) and (sc.mothership_survival or 500) or 0

    game.score = base + time_bonus + survival_bonus + enemy_bonus + mothership_bonus
    game.score_breakdown = {
        ["胜利基础"] = base,
        ["时间奖励"] = time_bonus,
        ["单位存活"] = survival_bonus,
        ["敌军击破"] = enemy_bonus,
        ["母舰存活"] = mothership_bonus,
    }
end

local function rebuild_menu()
    if game then game.menu_confirm = nil end
    level_names = {}
    level_scores = {}

    for _, file in ipairs(level_files) do
        local data = TBL.parse_file("levels/" .. file)
        local name = file
        if data and data.meta then
            name = data.meta.name or data.meta.value or file
        end
        table.insert(level_names, name)
        table.insert(level_scores, high_scores[name] or 0)
    end

    if menu then
        menu:set_levels(level_names, level_scores)
    else
        menu = MainMenu.new(level_names, level_scores)
    end
end

local function reset_input_state()
    command_pause_before=nil
    command_mode = "normal"
    command_action = nil
    command_hover_target = nil
    command_feedbacks = {}
    pending_command_units = {}
    selection_start = nil
    selection_rect = nil
    dragging_camera = false
    context_menu:hide()
    global_menu:hide()
    camera:enable_edge_scroll(false)
end

local function start_level(index)
    if index < 1 or index > #level_files then return false end

    local ok, err = LevelManager.load_level(level_files[index], game)
    if not ok then
        print("Failed to load level: " .. tostring(err))
        return false
    end

    current_level_name = game.level_name or level_files[index]
    current_level_file = level_files[index]
    game.player_team_id=game.player_team_id or Registry.default_player()
    game.enemy_team_id=game.enemy_team_id or Registry.default_enemy()
    game.team_id=game.player_team_id
    Mission.start(game,level_files[index])
    Advisor.start(game)
    local ms=game:get_mothership(game.player_team)
    local cx,cy=get_units_center()
    if ms then cx,cy=ms.x,ms.y end
    camera:focus_on(cx, cy)
    camera.zoom = 0.8
    camera.target_zoom = 0.8
    camera:stop_follow()
    reset_input_state()
    game:resume()
    game_state = "playing"
    if not _G.VERIFY_RUNNING and not (game.advisor and game.advisor.tutorial) then
        game_state="deployment"
        game:pause()
    end
    return true
end

local function begin_briefing()
    Simulation.deploy(game,Deployment.player_id(),Deployment.enemy_id(),Deployment.formation)
    -- 队伍已部署后再生成战前小剧场，确保说话人和阵营映射完整。
    Mission.start(game,current_level_file)
    game.briefing={time=0}
    game_state="briefing"
    game:pause()
    local ms=game:get_mothership(0)
    camera:focus_on(ms.x,ms.y)
end

local function finish_briefing()
    game.briefing=nil
    Mission.advance(game,true)
    game.reports={}
    game_state="playing"
    game:resume()
end

function love.load(args)
    love.math.setRandomSeed(os.time())
    love.graphics.setDefaultFilter("linear", "linear")

    settings = TBL.parse_file("config/settings.tbl") or {}
    _G.SETTINGS = settings

    local sw = settings.screen and settings.screen.width or 1280
    local sh = settings.screen and settings.screen.height or 800
    love.window.setMode(sw, sh, {resizable = true, minwidth = 960, minheight = 600, vsync = 1, msaa = 4})
    love.window.setTitle("Deep Space Command")

    level_files = LevelManager.scan_levels()
    load_high_scores()

    game = Game.new()
    game:reset()

    local mw = settings.map and settings.map.width or 3000
    local mh = settings.map and settings.map.height or 3000
    camera = Camera.new(mw, mh)

    context_menu = ContextMenu.new()
    global_menu = ContextMenu.new()
    unit_panel = UnitPanel.new()
    rebuild_menu()
    game_state = "menu"
    for _, arg in ipairs(args or {}) do
        if arg == "--verify" then
            _G.VERIFY_RUNNING=true
            require("tools.verify").run()
            start_level(2)
            for _ = 1, 60 do game:update(1/60) end
            require("tools.verify").input(game,camera,unit_panel,show_context_menu,execute_menu_action,execute_targeted_command,cancel_command)
            local friendly=game:get_units_by_team(game.player_team)[2]
            game:select_unit(friendly)
            game:report_event(friendly,"command","收到指令，正在前往指定空域。")
            game:pause()
            camera:focus_on(friendly.x+100,friendly.y+80)
            camera.zoom, camera.target_zoom = 1.3,1.3
            _G.VERIFY_CAPTURE = 3
        end
        if arg == "--compact" then love.window.setMode(960,600,{resizable=true}) end
        if arg == "--far" then
            camera.zoom,camera.target_zoom=0.16,0.16
            camera:focus_on(2900,1700)
            _G.VERIFY_NAME="verification-far.png"
        end
        if arg == "--enemy" then
            unit_panel.side="enemy"
            game.inspected_unit=game:get_enemy_units(game.player_team)[1]
            camera:focus_on(game.inspected_unit.x,game.inspected_unit.y)
            local u=game:get_units_by_team(game.player_team)[2]
            game:report_event(u,"hit","机体受到攻击，正在规避！")
            _G.VERIFY_NAME="verification-enemy.png"
        end
        if arg == "--battle" then
            local friendlies=game:get_units_by_team(game.player_team)
            local enemies=game:get_enemy_units(game.player_team)
            for i,u in ipairs(friendlies) do u.x=1800+(i%4)*75; u.y=700+math.floor(i/4)*85; u.route=nil end
            for i,u in ipairs(enemies) do u.x=2400+(i%4)*75; u.y=700+math.floor(i/4)*85; u.route=nil end
            Orders.issue(game,friendlies,"attack",nil,2450,900)
            game:resume()
            for _=1,180 do game:update(1/60) end
            game:pause()
            camera.zoom,camera.target_zoom=0.8,0.8
            camera:focus_on(2250,900)
            _G.VERIFY_NAME="verification-battle.png"
        end
        if arg=="--tutorial" then
            start_level(1)
            game:pause()
            Advisor.update(game,2.5)
            _G.VERIFY_NAME="verification-tutorial.png"
        end
        if arg=="--tutorial-noah" then
            -- 教学第六步：诺阿接手后勤课程的常驻状态，验证立绘站位未漂移。
            start_level(1)
            game:pause()
            require("systems.mission_script").advance(game,true)
            local a=game.advisor
            a.step=6
            local Slots=require("systems.comms_slots")
            Slots.clear(a)
            Slots.replace(game.researcher,require("levels.scripts.level_00").training[6].text,"idle",6)
            Advisor.update(game,1.5)
            _G.VERIFY_NAME="verification-tutorial-noah.png"
        end
        if arg=="--radio" then
            command_feedbacks={}
            local units=game:get_units_by_team(game.player_team)
            game.reports={}
            for i=2,4 do
                units[i].report_times={}
                game:report_event(units[i],i==3 and "hit" or "command","前往指定空域。")
            end
            Comms.update(game,1.4)
            Advisor.update(game,1.4)
            _G.VERIFY_NAME="verification-radio.png"
        end
        if arg=="--skill-shot" then
            local u=game:get_units_by_team(game.player_team)[2]
            Cinema.start(game,u)
            game.cinematic.time=0.7
            _G.VERIFY_NAME="verification-skill.png"
        end
        if arg=="--logistics-shot" then
            -- 塔克特队顾问替换回归截图：雷斯特接战术位、阿尔茉接后勤位，
            -- 可可/诺阿转入侧翼频道，敌方索尔贝红色垫底。
            local Slots=require("systems.comms_slots")
            local L=game.logistics
            game.player_team_id="moon"; game.enemy_team_id="rune"
            require("systems.advisor").apply_squad(game)
            Slots.replace(L.tact,"卡兹亚君，队形散了才会被抓住破绽。复盘时逐条分析。","failed",9)
            Slots.replace(L.almo,"目标击破。战斗数据已记录，保持这个节奏。","praise",9)
            Slots.replace(L.enemy,"就这点本事？你们的失误，我们全都记录在案。","attack",9)
            Slots.replace(L.player,"增援、建设、研究——想把资源花在哪里？","idle",9)
            Comms.update(game,1.4)
            Advisor.update(game,1.4)
            _G.VERIFY_NAME="verification-logistics.png"
        end
        if arg=="--mixed-radio" then
            local enemy=game:get_enemy_units(game.player_team)[2]
            enemy.character_id=11; enemy.report_times={}
            game:report_event(enemy,"praise","")
            Comms.update(game,1.4)
            _G.VERIFY_NAME="verification-mixed.png"
        end
        if arg=="--exercise-check" then
            game_state="deployment"
            love.keypressed("return")
            assert(game_state=="briefing" and game:is_paused(),"deployment enters paused briefing")
            love.keypressed("space")
            assert(game_state=="playing" and not game:is_paused(),"briefing skip starts battle")
            for _=1,900 do game:update(1/30) end
            game:pause()
            _G.VERIFY_NAME="verification-exercise.png"
        end
        if arg=="--deployment-shot" then
            game_state="deployment"
            _G.VERIFY_CAPTURE=50  -- 等入场动画播完再拍
            _G.VERIFY_NAME="verification-deployment.png"
        end
        if arg=="--shield-shot" then
            local u=game:get_units_by_team(game.player_team)[2]
            u.skill_data={type="shield",duration=8,shield_amount=900}
            require("systems.skill").execute(u,game)
            _G.VERIFY_NAME="verification-shield.png"
        end
        if arg=="--menu-shot" then game_state="menu"; _G.VERIFY_NAME="verification-menu.png" end
        if arg=="--audio-diag" then _G.AUDIO_DIAG={frame=0} end
        if arg=="--pilots-diag" then
            local P=require("ui.pilots")
            local rival={character_id=11,team=1,team_id="moon"}
            local ok,err=pcall(function()
                local base=love.filesystem.getSource().."/"
                local f=assert(io.open(base.."pilots-diag.txt","w"))
                f:write("info="..tostring(P.info("moon","11")).."\n")
                f:write("line="..tostring(P.line(rival,"attack","FB")).."\n")
                f:write("padded info="..tostring(P.info("moon",11)).."\n")
                f:write("padded line="..tostring(P.line({character_id=11,team=1,team_id="moon"},"attack","FB")).."\n")
                f:close()
            end)
            if not ok then error(err) end
            love.event.quit()
        end
        if arg=="--pacing" then require("tools.verify").pacing() end
        if arg=="--mission-pacing" then require("tools.verify_missions").pacing() end
        if arg=="--economy-shot" then
            game.economy.open=true
            require("systems.economy").enqueue(game,"weapons")
            game.researcher.age=2
            game.advisor.age=2
            _G.VERIFY_NAME="verification-economy.png"
        end
        if arg=="--flip" then
            for _,r in ipairs(game.reports or {}) do r.age=0.18 end
            _G.VERIFY_NAME="verification-flip.png"
        end
        if arg=="--cutins-shot" then
            Mission.advance(game,true);game.advisor.life=0;game.researcher.life=0;game.reports={};game.cutins={}
            local units=game:get_units_by_team(0)
            units[1].character_id=0;units[2].character_id=6;units[3].character_id=10
            for i=1,3 do Cinema.start(game,units[i]);game.cutins[i].time=0.75 end
            _G.VERIFY_NAME="verification-cutins.png"
        end
        if arg=="--story-shot" then
            Mission.advance(game,true)
            Mission.say(game,{id=11,text="阿妮丝，这次的侧翼不会再让给你了。",kind="attack"})
            local enemy=game:get_enemy_units(0)[1];enemy.character_id=11
            Mission.update(game,0);Mission.update(game,2)
            _G.VERIFY_NAME="verification-story.png"
        end
        if arg=="--release-shot" then
            Mission.advance(game,true);game.advisor.life=0;game.researcher.life=0;game.reports={}
            local u=game:get_units_by_team(0)[2]
            local target=game:get_enemy_units(0)[1]
            target.x,target.y=u.x+600,u.y
            u.skill_data={type="charge_beam",range=1800,damage=650};u.skill_target=target
            require("systems.special_attacks").prepare(u)
            require("systems.skill").execute(u,game)
            camera:focus_on(u.x+300,u.y);camera.zoom=0.8;camera.target_zoom=0.8
            _G.VERIFY_NAME="verification-release.png"
        end
    end
    if not _G.VERIFY_RUNNING then
        local preferences=require("systems.preferences")
        preferences.load();preferences.save()
    end
end

function love.quit()
    local preferences=require("systems.preferences")
    preferences.load();preferences.save()
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    -- 音频诊断：--audio-diag 启动时把 love.audio 实际状态写入 audio-diag.txt。
    if _G.AUDIO_DIAG then
        local d=_G.AUDIO_DIAG
        d.frame=d.frame+1
        if d.frame==5 and love.audio then
            local ok,src=pcall(love.audio.newSource,"assets/se/ui-confirm.ogg","static")
            d.load_ok=ok
            if ok then src:setLooping(true); src:setVolume(0.8); src:play(); d.src=src end
        end
        if d.frame>=40 then
            local f=assert(io.open(love.filesystem.getSource().."/audio-diag.txt","w"))
            f:write(string.format(
                "has_audio=%s load_ok=%s playing=%s\n",
                tostring(love.audio~=nil),tostring(d.load_ok),tostring(d.src and d.src:isPlaying())))
            f:close()
            love.event.quit()
        end
        return
    end
    -- 部署界面预览当前我方队伍的音乐，切换队伍时立即跟随。
    if game_state=="deployment" then game.player_team_id=Deployment.player_id() end
    -- 背景音乐按状态切换：菜单/简报用标题曲，战斗用战斗曲，结算用胜负曲。
    if game_state=="menu" or game_state=="deployment" or game_state=="briefing" then
        require("systems.bgm").play_pack(game,"menu")
    elseif game_state=="playing" then
        require("systems.bgm").play_pack(game,"battle")
    elseif game_state=="victory" then
        require("systems.bgm").play_pack(game,"victory",false)
    elseif game_state=="defeat" then
        require("systems.bgm").play_pack(game,"defeat",false)
    end
    if game_state=="deployment" then return end
    if game_state=="briefing" then
        local b=game.briefing
        b.time=b.time+dt
        Mission.update(game,dt)
        if not game.mission.current and #game.mission.queue==0 then finish_briefing() end
        return
    end

    if game_state == "menu" then
        if menu then menu:update(dt) end
        return
    end

    if game_state == "victory" or game_state == "defeat" then
        Mission.update(game,dt)
        Screens.update(dt)
        return
    end

    if game_state ~= "playing" then return end

    camera:update(dt)
    camera:edge_scroll_update(dt)
    Comms.update(game,dt)
    if not game.cinematic then Mission.update(game,dt) end
    SkillVisuals.update(game,dt)
    Advisor.update(game,dt)
    if not game:is_paused() then Cinema.update(game,dt) end

    for i = #command_feedbacks, 1, -1 do
        local f = command_feedbacks[i]
        f.life = f.life - dt
        if f.life <= 0 then table.remove(command_feedbacks, i) end
    end


    game:update(dt*(game.skill_slow and game.skill_slow.scale or 1),dt)

    if not game:is_paused() and not (game.advisor and game.advisor.tutorial) then
        if LevelManager.check_victory(game) then
            Mission.finish(game,"victory")
            calc_score()
            save_high_score()
            require("systems.audio").play("victory")
            game_state = "victory"
        elseif LevelManager.check_defeat(game) then
            Mission.finish(game,"defeat")
            require("systems.audio").play("defeat")
            game_state = "defeat"
        end
    end
end

local function draw_terrain()
    local Terrain = require("systems.terrain")
    for _, t in ipairs(game.terrain_objects) do
        Terrain.draw(t)
    end
end

local function draw_projectiles()
    for _, p in ipairs(game.projectiles) do
        if p.draw then p:draw() end
    end
end

local function draw_effects()
    for _, e in ipairs(game.effects) do
        if e.draw then e:draw() end
    end
end

local function draw_selection_rect()
    if not selection_start or not selection_rect then return end

    local r = selection_rect
    love.graphics.setColor(0.2, 0.8, 0.2, 0.25)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(0.3, 1, 0.3, 0.6)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function command_color(action, target)
    if target then
        if target.team ~= game.player_team then return 1.0, 0.16, 0.12, 0.92 end
        return 0.18, 1.0, 0.35, 0.92
    end
    if action == "move" then return 0.85, 0.92, 1.0, 0.82 end
    if action == "attack" then return 1.0, 0.22, 0.14, 0.72 end
    if action == "repair" or action == "follow" then return 0.20, 1.0, 0.36, 0.72 end
    return 1, 1, 1, 0.75
end

local function draw_arrow_screen(x1, y1, x2, y2, r, g, b, a, width)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 12 then return end
    dx, dy = dx / len, dy / len

    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(width or 3)
    love.graphics.line(x1, y1, x2, y2)

    local head = math.min(26, len * 0.22)
    local spread = 0.55
    local lx = x2 - head * (dx * math.cos(spread) - dy * math.sin(spread))
    local ly = y2 - head * (dy * math.cos(spread) + dx * math.sin(spread))
    local rx = x2 - head * (dx * math.cos(-spread) - dy * math.sin(-spread))
    local ry = y2 - head * (dy * math.cos(-spread) + dx * math.sin(-spread))
    love.graphics.line(x2, y2, lx, ly)
    love.graphics.line(x2, y2, rx, ry)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function screen_to_extended_world(mx, my)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local ex = math.max(0, math.min(w, mx))
    local ey = math.max(0, math.min(h, my))
    return camera:screen_to_world(ex, ey)
end

local function draw_command_indicators()
    for _, f in ipairs(command_feedbacks) do
        local a = math.max(0, f.life / f.duration)
        local sx, sy = camera:world_to_screen(f.x1, f.y1)
        local ex, ey = camera:world_to_screen(f.x2, f.y2)
        draw_arrow_screen(sx, sy, ex, ey, f.r, f.g, f.b, a * 0.72, 3)
    end

    if command_mode ~= "targeting" or #pending_command_units == 0 then return end

    local mx, my = love.mouse.getPosition()
    local wx, wy = screen_to_extended_world(mx, my)
    command_hover_target = game:get_unit_at(wx, wy, nil, camera.zoom)
    local r, g, b, a = command_color(command_action, command_hover_target)

    for _, u in ipairs(pending_command_units) do
        if u.alive and u.state ~= "dead" then
            local sx, sy = camera:world_to_screen(u.x, u.y - (u.z or 0) * 0.22)
            draw_arrow_screen(sx, sy, math.max(0, math.min(love.graphics.getWidth(), mx)), math.max(0, math.min(love.graphics.getHeight(), my)), r, g, b, a, 3)
        end
    end

    love.graphics.setColor(r, g, b, a)
    if command_hover_target then
        love.graphics.circle("line", mx, my, 18)
        love.graphics.circle("line", mx, my, 9)
    else
        love.graphics.circle("line", mx, my, 10)
        love.graphics.line(mx - 8, my, mx + 8, my)
        love.graphics.line(mx, my - 8, mx, my + 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_units()
    local visible = {}
    for _, u in ipairs(game.units) do visible[#visible + 1] = u end
    table.sort(visible, function(a, b)
        return ((a.y or 0) + (a.z or 0) * 0.2) < ((b.y or 0) + (b.z or 0) * 0.2)
    end)
    for _, u in ipairs(visible) do
        if u.alive and u.state ~= "dead" then
            ShipRenderer.draw(u, game.player_team)
        end
    end
end

local function draw_playing()
    local view=camera
    love.graphics.push("all")
    Cinema.apply(game)
    SpaceScene.draw_background(game, view)

    view:apply()
    SpaceScene.draw_world_layers(game)
    draw_terrain()
    require("systems.minerals").draw(game)
    draw_units()
    draw_projectiles()
    draw_effects()
    view:reset()
    love.graphics.pop()
    Markers.draw(game,view)
    require("systems.objectives").draw(game,view)
    SkillVisuals.draw(game)

    draw_selection_rect()
    draw_command_indicators()
    unit_panel:draw(game)
    HUD.draw(game, current_level_name, command_mode)
    if game.menu_confirm and game:is_paused() then
        local w,h=love.graphics.getWidth(),love.graphics.getHeight()
        love.graphics.setColor(0,0,0,0.45)
        love.graphics.rectangle("fill",0,0,w,h)
        love.graphics.setColor(0.04,0.08,0.14,0.95)
        love.graphics.rectangle("fill",w/2-250,h/2-52,500,104,12,12)
        love.graphics.setColor(0.35,0.62,0.95,0.9)
        love.graphics.rectangle("line",w/2-250,h/2-52,500,104,12,12)
        love.graphics.setFont(require("core.fonts").get(19))
        love.graphics.setColor(1,1,1)
        love.graphics.printf("已暂停：再按一次 ESC 返回主菜单",0,h/2-30,w,"center")
        love.graphics.setFont(require("core.fonts").get(14))
        love.graphics.setColor(0.75,0.8,0.9)
        love.graphics.printf("空格继续游戏 · 战斗不会因返回菜单而保存",0,h/2+4,w,"center")
    end
    SelectionPanel.draw(game)
    if not Mission.busy(game) then Comms.draw(game) end
    if not Mission.busy(game) then Advisor.draw(game) end
    EconomyPanel.draw(game)
    if not game.cinematic then Mission.draw(game) end
    Cinema.draw(game)
    context_menu:draw()
    global_menu:draw()
end

function love.draw()
    if game_state=="deployment" then Deployment.draw(game)
    elseif game_state=="briefing" then
        draw_playing()
    elseif game_state == "menu" then
        if menu then menu:draw() end
    elseif game_state == "victory" then
        Screens.draw_victory(game, current_level_name)
        Mission.draw(game)
    elseif game_state == "defeat" then
        Screens.draw_defeat()
        Mission.draw(game)
    elseif game_state == "playing" then
        draw_playing()
    end
    if _G.VERIFY_CAPTURE then
        _G.VERIFY_CAPTURE = _G.VERIFY_CAPTURE - 1
        if _G.VERIFY_CAPTURE == 0 then
            _G.VERIFY_CAPTURE = false
            love.graphics.captureScreenshot(function(data)
                local encoded=data:encode("png")
                local file=assert(io.open(love.filesystem.getSource().."/"..(_G.VERIFY_NAME or "verification.png"),"wb"))
                file:write(encoded:getString()); file:close()
            end)
            love.event.quit()
        end
    end
end

function hide_all_menus()
    context_menu:hide()
    global_menu:hide()
    if game and game.advisor and game.advisor.panel_active then
        require("systems.comms_slots").clear(game.advisor)
        game.advisor.panel_active=false
    end
    if command_mode ~= "targeting" then restore_command_pause() end
end

function start_targeting(action)
    command_mode = "targeting"
    command_action = action
    command_hover_target = nil
    pending_command_units = {}
    for _, u in ipairs(game.selected_units) do
        if u.alive and u.state ~= "dead" then table.insert(pending_command_units, u) end
    end
    pause_for_command()
    camera:stop_follow()
    camera:enable_edge_scroll(true)
    context_menu:hide()
    global_menu:hide()
end

function cancel_command()
    command_mode = "normal"
    command_action = nil
    command_hover_target = nil
    pending_command_units = {}
    restore_command_pause()
    camera:enable_edge_scroll(false)
    context_menu:hide()
    global_menu:hide()
end

local function commandable_selected_units(include_mothership)
    local result = {}
    for _, u in ipairs(game.selected_units) do
        if u.alive and u.state ~= "dead" and u.state ~= "disabled" and (include_mothership or u.unit_type ~= "mothership") then
            table.insert(result, u)
        end
    end
    return result
end

local function set_units_returning(units)
    for _, u in ipairs(units) do
        if u.unit_type ~= "mothership" then
            u.attack_target = nil
            u.repair_target = nil
            u.follow_target = nil
            u.attack_move = nil
            u.burst_queue = {}
            u.route = nil
            u.state = "returning"
        end
    end
end


local function select_all_command_units()
    local all = game:get_all_friendly_units(game.player_team)
    game:clear_selection()
    for _, u in ipairs(all) do
        u.selected = true
        table.insert(game.selected_units, u)
    end
    return all
end

local function command_defense(units)
    local ms = game:get_mothership(game.player_team)
    if not ms then return end
    for i, u in ipairs(units) do
        if u.unit_type ~= "mothership" then
            local angle = (i / math.max(1, #units)) * math.pi * 2
            local radius = 150 + (i % 3) * 45
            local tx = ms.x + math.cos(angle) * radius
            local ty = ms.y + math.sin(angle) * radius
            u.follow_target = ms
            u.attack_target = nil
            u.target_pos = {tx, ty}
            u.state = "moving"
            table.insert(command_feedbacks, {
                x1 = u.x,
                y1 = u.y - (u.z or 0) * 0.22,
                x2 = tx,
                y2 = ty,
                r = 0.20, g = 1.0, b = 0.36,
                life = 0.9,
                duration = 0.9,
            })
        end
    end
end

function love.mousepressed(mx, my, button)
    if game_state=="deployment" then if button==1 and Deployment.click(mx,my) then begin_briefing() end; return end
    if game_state=="briefing" then
        if button==2 or my>love.graphics.getHeight()-90 then finish_briefing()
        else Mission.advance(game); if not Mission.busy(game) then finish_briefing() end end
        return
    end
    if game_state == "menu" then
        if menu then
            local action, index = menu:mousepressed(mx, my, button)
            if action == "start" then require("systems.audio").play("confirm"); start_level(index)
            elseif action == "quit" then love.event.quit() end
        end
        return
    end

    if game_state == "victory" or game_state == "defeat" then
        if button == 1 then
            if Mission.busy(game) then Mission.advance(game);return end
            game_state = "menu"
            rebuild_menu()
        end
        return
    end

    if game_state ~= "playing" then return end
    if command_mode=="normal" and button==1 and EconomyPanel.click(game,mx,my) then return end
    if command_mode=="normal" and EconomyPanel.contains(game,mx,my) then return end
    if Mission.contains(game,mx,my) then if button==1 then Mission.advance(game) end;return end

    if button == 1 then
        if global_menu.active then
            local action = global_menu:get_clicked(mx, my)
            if action then execute_global_command(action) else hide_all_menus() end
            return
        end

        if context_menu.active then
            local action = context_menu:get_clicked(mx, my)
            if action then execute_menu_action(action) else hide_all_menus() end
            return
        end

        if command_mode == "targeting" then
            execute_targeted_command(mx, my)
            return
        end

        if Comms.contains(game,mx,my) or Advisor.contains(game,mx,my) then return end

        local panel_action, panel_unit = unit_panel:handle_click(mx, my, game, 1)
        if panel_action == "consume" then return end
        if panel_action == "inspect" then
            game.inspected_unit = panel_unit
            camera:set_follow(panel_unit)
            return
        end
        if panel_action == "select" and panel_unit then
            game.inspected_unit = nil
            game:select_unit(panel_unit)
            camera:set_follow(panel_unit)
            return
        end

        local wx, wy = camera:screen_to_world(mx, my)
        local clicked = Markers.pick(game,camera,mx,my) or game:get_unit_at(wx, wy, nil, camera.zoom)
        if clicked then
            if clicked.team == game.player_team then
                game.inspected_unit=nil
                game:select_unit(clicked)
                camera:set_follow(clicked)
            else
                game.inspected_unit = clicked
                camera:set_follow(clicked)
            end
        else
            selection_start = {mx, my}
            game:clear_selection()
            camera:stop_follow()
        end
    elseif button == 2 then
        if command_mode == "targeting" then
            cancel_command()
            return
        end
        if Comms.contains(game,mx,my) or Advisor.contains(game,mx,my) then return end

        local panel_action, panel_unit = unit_panel:handle_click(mx, my, game, 2)
        if panel_action == "consume" then return end
        if panel_action == "inspect" then
            game.inspected_unit = panel_unit
            camera:set_follow(panel_unit)
            return
        end
        if panel_action == "select_and_menu" and panel_unit then
            game.inspected_unit = nil
            game:select_unit(panel_unit)
            camera:set_follow(panel_unit)
            show_context_menu(mx, my)
            return
        end

        local wx, wy = camera:screen_to_world(mx, my)
        local clicked = Markers.pick(game,camera,mx,my) or game:get_unit_at(wx, wy, nil, camera.zoom)
        if clicked and clicked.team == game.player_team then
            game:select_unit(clicked)
            camera:set_follow(clicked)
        elseif clicked and clicked.team ~= game.player_team and #game.selected_units > 0 then
            direct_attack(clicked)
            return
        elseif clicked and clicked.team ~= game.player_team then
            game.inspected_unit = clicked
            camera:set_follow(clicked)
            return
        end

        show_context_menu(mx, my)
    elseif button == 3 then
        camera:stop_follow()
        dragging_camera = true
        drag_start_x, drag_start_y = mx, my
        drag_cam_x, drag_cam_y = camera.x, camera.y
    end
end

function love.mousereleased(mx, my, button)
    if button == 1 and selection_start then
        local wx1, wy1 = camera:screen_to_world(selection_start[1], selection_start[2])
        local wx2, wy2 = camera:screen_to_world(mx, my)
        game:select_units_in_rect(wx1, wy1, wx2, wy2)
        selection_start = nil
        selection_rect = nil
    end

    if button == 3 then
        if dragging_camera then
            camera.x = camera.x-(mx-drag_start_x)/camera.zoom
            camera.y = camera.y-(my-drag_start_y)/camera.zoom
        end
        dragging_camera = false
    end
end

function love.mousemoved(mx, my)
    if dragging_camera then
        Advisor.event(game,"pan")
        camera:stop_follow()
        camera.x=camera.x-(mx-drag_start_x)/camera.zoom
        camera.y=camera.y-(my-drag_start_y)/camera.zoom
        drag_start_x,drag_start_y=mx,my
        return
    end
    if not selection_start then return end
    local sx, sy = selection_start[1], selection_start[2]
    selection_rect = {
        x = math.min(sx, mx),
        y = math.min(sy, my),
        w = math.abs(mx - sx),
        h = math.abs(my - sy),
    }
end

function love.wheelmoved(dx, dy)
    if game_state == "menu" then
        if menu then menu:wheelmoved(dx, dy) end
        return
    end
    if game_state == "deployment" then
        local mx,my=love.mouse.getPosition()
        Deployment.wheelmoved(dy,mx,my)
        return
    end

    if game_state ~= "playing" then return end

    local mx,my = love.mouse.getPosition()
    if command_mode ~= "targeting" and unit_panel:contains(mx,my) then
        unit_panel:handle_scroll(dy)
    elseif dy ~= 0 then
        Advisor.event(game,"zoom")
        camera.target_zoom = math.max(camera.zoom_min,math.min(camera.zoom_max,camera.target_zoom*1.35^dy))
    end
end

function love.keypressed(key)
    if game_state=="deployment" then
        if key=="return" then begin_briefing()
        elseif key=="escape" then game_state="menu"
        else Deployment.keypressed(key) end
        return
    end
    if game_state=="briefing" then
        if key=="escape" or key=="space" then finish_briefing()
        elseif key=="return" then Mission.advance(game);if not Mission.busy(game) then finish_briefing() end end
        return
    end
    if game_state == "menu" then
        if menu then
            local action, index = menu:keypressed(key)
            if action == "start" then
                require("systems.audio").play("confirm")
                start_level(index)
            elseif action == "quit" then
                love.event.quit()
            end
        end
        return
    end

    if game_state == "victory" or game_state == "defeat" then
        if Screens.accept_key(key) then
            if Mission.busy(game) then Mission.advance(game,key=="escape");return end
            game_state = "menu"
            rebuild_menu()
        end
        return
    end

    if game_state ~= "playing" then return end

    if key=="return" and game.tutorial_complete then
        game_state="menu"; rebuild_menu(); return
    end
    if key == "escape" then
        if command_mode == "targeting" then
            cancel_command()
        elseif context_menu.active or global_menu.active then
            hide_all_menus()
        elseif game.menu_confirm then
            -- 第二次 ESC 才真正返回主菜单，防止战斗中误触。
            require("systems.audio").play("confirm")
            game.menu_confirm = nil
            game_state = "menu"
            rebuild_menu()
        else
            if not game:is_paused() then game:pause() end
            game.menu_confirm = true
        end
    elseif key == "tab" then
        unit_panel:toggle()
    elseif key == "space" then
        if command_mode=="normal" and not context_menu.active and not global_menu.active then
            if game:is_paused() then game:resume(); game.menu_confirm=nil else game:pause() end
        end
    end
end

function show_context_menu(mx, my)
    if #game.selected_units == 0 then return end
    pause_for_command()
    -- 调出指挥面板时左手入位，并说一句面板预设台词（类比右手管资源面板）。
    if game.advisor then
        if game.advisor.unit.character_id then
            local line=require("ui.pilots").line(game.advisor.unit,"panel","")
            if line and line~="" then
                require("systems.comms_slots").replace(game.advisor,line,"idle",3600)
                game.advisor.panel_active=true
            end
        end
    end
    global_menu:hide()
    local u = game.selected_units[1]
    local opts = {{"全体命令", "global"}, {"移动", "move"}}
    if (u.attack_damage or 0) > 0 then table.insert(opts, {"攻击", "attack"}) end
    table.insert(opts, {"跟随", "follow"})
    if u.unit_type == "repair" or u.unit_type == "mothership" then table.insert(opts, {"修理", "repair"}) end
    if u.unit_type ~= "mothership" then table.insert(opts, {"补给", "supply"}) end
    if u.sp >= u.max_sp then table.insert(opts, {"必杀技  >", "skill_menu"}) end
    table.insert(opts,{u.auto_skill and "自动技能：开" or "自动技能：关","auto_skill"})
    context_menu:show(mx, my, opts)
end

function execute_menu_action(action)
    if action=="skill_menu" then
        local u=game.selected_units[1]
        if u.unit_type=="repair" then
            context_menu:show(context_menu.x,context_menu.y,{{"全舰修复","fleet_heal"},{"维修工具：选友舰","repair_tool"},{"返回","back"}})
        elseif require("systems.skill").target_mode(u)=="enemy" then
            local Skill=require("systems.skill")
            if u.sp<u.max_sp then
                game:report_event(u,"failed","能量还没充满，再等等。")
                require("systems.audio").play("error")
            elseif not Skill.can_execute(u,game) then
                game:report_event(u,"failed","当前没有合适的目标。")
                require("systems.audio").play("error")
            else
                start_targeting("skill_target")
            end
        else execute_menu_action("skill") end
    elseif action=="back" then show_context_menu(context_menu.x,context_menu.y)
    elseif action=="fleet_heal" then
        for _,u in ipairs(game.selected_units) do if u.unit_type=="repair" and not u.skill_pending then u.skill_data={type="fleet_heal"}; u:use_skill(game) end end
        hide_all_menus()
    elseif action=="repair_tool" then start_targeting("repair_tool")
    elseif action == "auto_skill" then
        local enabled=not game.selected_units[1].auto_skill
        for _,u in ipairs(game.selected_units) do
            u.auto_skill=enabled
            require("systems.preferences").set("auto_skill_"..u.character_id,enabled)
        end
        hide_all_menus()
    elseif action == "global" then
        global_menu:show(context_menu.x + context_menu.width + 6, context_menu.y, {
            {"全体移动", "global_move"}, {"全体攻击", "global_attack"}, {"全体跟随", "global_follow"},
            {"全体防御", "global_defend"}, {"全体补给", "global_supply"},
        })
    elseif action == "move" or action == "attack" or action == "follow" or action == "repair" then
        start_targeting(action)
    elseif action == "supply" then
        set_units_returning(commandable_selected_units(false))
        hide_all_menus()
    elseif action == "skill" then
        for _, u in ipairs(commandable_selected_units(true)) do
            if not u:use_skill(game) then game:report_event(u,"failed","技能尚未就绪，或附近没有有效目标。") end
        end
        hide_all_menus()
    else
        hide_all_menus()
    end
end

function execute_global_command(action)
    local all = select_all_command_units()
    if #all == 0 then hide_all_menus(); return end
    if action == "global_move" then
        start_targeting("move")
    elseif action == "global_attack" then
        start_targeting("attack")
    elseif action == "global_follow" then
        start_targeting("follow")
    elseif action == "global_defend" then
        command_defense(all)
        hide_all_menus()
    elseif action == "global_supply" then
        set_units_returning(all)
        hide_all_menus()
    end
end

function execute_targeted_command(mx, my)
    local wx, wy = screen_to_extended_world(mx, my)
    local target = Markers.pick(game,camera,mx,my) or game:get_unit_at(wx, wy, nil, camera.zoom)
    if command_action=="skill_target" then
        local success=false
        for _,u in ipairs(pending_command_units) do
            if target and target.alive and target.team~=u.team and not u.skill_pending then
                u.skill_target=target
                if u:use_skill(game) then success=true else u.skill_target=nil end
            end
        end
        if success then cancel_command() end
        return
    end
    if command_action=="repair_tool" then
        local success=false
        for _,u in ipairs(pending_command_units) do
            if u.unit_type=="repair" and not u.skill_pending and target and target~=u and target.team==u.team then
                u.repair_target=target; u.skill_data={type="repair_tool",range=600}
                success=u:use_skill(game) or success
            end
        end
        if success then cancel_command() end
        return
    end
    if Orders.issue(game,pending_command_units,command_action,target,wx,wy) == 0 then return end
    local r,g,b=command_color(command_action,target)
    for _,u in ipairs(pending_command_units) do
        table.insert(command_feedbacks,{x1=u.x,y1=u.y-(u.z or 0)*0.22,x2=wx,y2=wy,r=r,g=g,b=b,life=0.9,duration=0.9})
    end
    cancel_command()
end

function direct_attack(enemy)
    if not enemy or enemy.team==game.player_team then return end
    Orders.issue(game,game.selected_units,"attack",enemy,enemy.x,enemy.y)
end

local default_errorhandler=love.errorhandler
function love.errorhandler(message)
    if not _G.VERIFY_RUNNING then return default_errorhandler(message) end
    local trace=debug.traceback(tostring(message),2)
    print(trace)
    local file=io.open(love.filesystem.getSource().."/verification-error.txt","w")
    if file then file:write(trace); file:close() end
    return function() return 1 end
end
