local UI = {player = 1, enemy = 2, bar = "player", formation = "line", clock = 0, arrows = {},
anim = {player = {at = -10, dir = 1}, enemy = {at = -10, dir = 1}}}

local Fonts = require("core.fonts")
local Pilots = require("ui.pilots")
local Registry = require("systems.pack_registry")
local Preferences = require("systems.preferences")
local Loadout = require("systems.loadout")
local SHOW_H = 340
local skins_for
local skin_label
local skin_fx = {player={time=0,old=nil,new=nil,current=nil}, enemy={time=0,old=nil,new=nil,current=nil}}
local skin_hover = {player=nil, enemy=nil}
local skin_hit = {}
local function skin_pref_key(which, team_id)
    return "skin_" .. tostring(which) .. "." .. tostring(team_id)
end
local function get_skin(which, team_id)
    return Preferences.get(skin_pref_key(which,team_id), "default")
end

function UI.list()
    if not UI._list then
        local ok, ids = pcall(Registry.playable_ids)
        -- 随机混池已废弃：选人界面只列真实队伍（增援也只从本阵营召唤）。
        UI._list = (ok and type(ids) == "table" and #ids > 0) and ids or {"random"}
    end
    return UI._list
end

-- 队员行数据：花名册顺序 + 上阵标记（从编队存档初始化，点击切换并即时保存）。
-- 返回 { {id=, ship=, selected=} }；随机编队全部视为已选。

function UI.reset()
    UI._list = nil
    UI._entries = nil
    UI.member_hits = nil
    UI.limit_flash = nil
    UI.player, UI.enemy, UI.bar = 1, 2, "player"
    skin_fx = {player={time=0,old=nil,new=nil,current=nil}, enemy={time=0,old=nil,new=nil,current=nil}}
    UI.anim = {player={at=-10,dir=1}, enemy={at=-10,dir=1}}
    UI.random_preview, UI._preview_step = nil, nil
end

function UI.player_id() return UI.list()[UI.player] end
function UI.enemy_id() return UI.list()[UI.enemy] end

local function show_y(which)
    return which == "player" and 16 or (love.graphics.getHeight() - SHOW_H - 16)
end

local function team_name(id)
    if id == "random" then return "随机编队" end
    local t = Registry.load(id)
    return (t.team and t.team.name) or id
end

local function side_colors(which)
    if which == "player" then
        return {border = {1, 0.85, 0.35}, strip = {1, 0.85, 0.35}, name = {1, 0.92, 0.5}, text = {0.12, 0.08, 0.02}}
    end
    return {border = {1, 0.35, 0.3}, strip = {1, 0.28, 0.24}, name = {1, 0.42, 0.38}, text = {1, 0.95, 0.92}}
end

local function draw_standing(g, team_id, char_id, cx, anchor_y, height, anchor, alpha, flash, skin)
    local img = Pilots.standing({character_id = char_id, team_id = team_id, skin = skin})
    g.push("all")
    if img then
        local s = height / img:getHeight()
        local oy = anchor == "top" and 0 or img:getHeight()
        g.setColor(1, 1, 1, alpha)
        g.draw(img, cx, anchor_y, 0, s, s, img:getWidth() / 2, oy)
        if flash and flash > 0 then
            -- 角色像素自身闪白：叠加绘制同一张图
            g.setBlendMode("add")
            g.setColor(1, 1, 1, flash)
            g.draw(img, cx, anchor_y, 0, s, s, img:getWidth() / 2, oy)
            g.setBlendMode("alpha")
        end
        g.pop()
    else
        g.pop()
        local size = math.floor(height * 0.62)
        local ay = anchor == "top" and anchor_y or anchor_y - height
        Pilots.draw({character_id = char_id, team_id = team_id, skin = skin}, cx - size / 2, ay, size, size, "bare")
    end
end

local function draw_avatar(g, team_id, char_id, cx, cy, size, game, team, skin)
    Pilots.draw({character_id = char_id, team_id = team_id, game = game, team = team, skin = skin}, cx - size / 2, cy - size / 2, size, size)
end

-- 白字细描边：名字条统一样式
local function outlined_text(g, text, x, y, w, align, font)
    g.setFont(Fonts.get(font or 15))
    for _, off in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        g.setColor(0, 0, 0, 0.8)
        g.printf(text, x + off[1], y + off[2], w, align)
    end
    g.setColor(1, 1, 1)
    g.printf(text, x, y, w, align)
end

-- 问号标识：修正字体渲染边界，精确水平/垂直居中
local function draw_mark(g, text, cx, cy, size, color)
    -- 按字形实际宽高精确居中
    local font = Fonts.get(size)
    g.setFont(font)
    g.setColor(color)
    local tw, th = font:getWidth(text), font:getHeight()
    g.print(text, cx - tw / 2, cy - th / 2)
end

-- 随机编队的预览数据：每 0.5 秒从所有队伍轮换一组候选。
local function update_random_preview()
    if not (UI.player_id() == "random" or UI.enemy_id() == "random") then return end
    local step = math.floor(UI.clock / 0.5)
    if UI.random_preview and UI._preview_step == step then return end
    UI._preview_step = step
    -- 随机编队含混池角色，内部自动去重
    UI.random_preview = require("systems.random_roster").roster()
end

local function side_display(side_id)
    if side_id == "random" then
        -- 预览轮换还没出第一组时直接组一支，避免画到写死的占位编队
        UI.random_preview = UI.random_preview or require("systems.random_roster").roster()
        return UI.random_preview
    end
    local cfg = Registry.load(side_id).team or {}
    local cmd = tonumber(cfg.commander)
    local members = {}
    for _, cid in ipairs(cfg.chara or {}) do
        cid = tonumber(cid)
        if cid and (not cmd or cid ~= cmd) then members[#members + 1] = {team = side_id, id = cid} end
    end
    return {
        commander = {team = side_id, id = cmd},
        left = {team = side_id, id = tonumber(cfg.left)},
        right = {team = side_id, id = tonumber(cfg.right)},
        members = members,
    }
end

function UI.team_entries(id)
    if not UI._entries then UI._entries = {} end
    local cached = UI._entries[id]
    if cached then return cached end
    local side = side_display(id)
    local entries = {}
    if id == "random" then
        for _, m in ipairs(side.members) do entries[#entries + 1] = { id = m.id, selected = true } end
    else
        local selected, ship = {}, {}
        for _, entry in ipairs(Loadout.for_team(id)) do
            selected[entry.id] = true
            ship[entry.id] = entry.ship
        end
        for _, m in ipairs(side.members) do
            entries[#entries + 1] = { id = m.id, ship = ship[m.id], selected = selected[m.id] or false }
        end
    end
    UI._entries[id] = entries
    return entries
end

function UI.selected_count(id)
    local n = 0
    for _, e in ipairs(UI.team_entries(id)) do
        if e.selected then n = n + 1 end
    end
    return n
end

function UI.toggle_member(id, cid)
    if id == "random" then return false end
    local entries = UI.team_entries(id)
    local target
    for _, e in ipairs(entries) do
        if e.id == cid then target = e break end
    end
    if not target then return false end
    if target.selected then
        target.selected = false
    elseif UI.selected_count(id) < Loadout.limit() then
        target.selected = true
    else
        UI.limit_flash = { team = id, expiry = UI.clock + 1.4 }
        return false
    end
    -- 按当前显示顺序保存（保留机型记录）
    local save = {}
    for _, e in ipairs(entries) do
        if e.selected then save[#save + 1] = { id = e.id, ship = e.ship } end
    end
    Loadout.set_team(id, save)
    return true
end

-- ==========================================
-- 核心卡牌绘制逻辑统一合并
-- ==========================================
local function draw_portrait_card(g, which, x, y, w, h, role, pilot, random, slide, flash, skin)
    local col = side_colors(which)
    local strip_h = 30 -- 文字区域尺寸
    local r = 12       -- 圆角半径

    -- 1. 绘制底层黑色蒙版背景
    g.setColor(0.04, 0.07, 0.13, 0.92)
    g.rectangle("fill", x, y, w, h, r, r)

    -- 2. 用卡片轮廓模板裁剪色条。模板会跟随当前变换，缩放时不会留下残影。
    g.stencil(function()
        g.rectangle("fill", x, y, w, h, r, r)
    end, "replace", 1)
    g.setStencilTest("equal", 1)
    g.setColor(col.strip[1], col.strip[2], col.strip[3], 0.95)
    g.rectangle("fill", x, y + h - strip_h, w, strip_h)
    g.setStencilTest()

    -- 3. 立绘也使用随卡片缩放的模板裁剪，避免固定裁剪框截留角色像素。
    g.stencil(function()
        g.rectangle("fill", x, y, w, h - strip_h, r, r)
    end, "replace", 1)
    g.setStencilTest("equal", 1)
    if random then
        draw_mark(g, "？", x + w / 2, y + (h - strip_h) / 2, math.floor(w * 0.35), {1, 0.95, 0.6})
    else
        draw_standing(g, pilot.team, pilot.id, x + w / 2 + (slide or 0), y + h - strip_h, h - strip_h - 4, "bottom", 1, flash, skin)
    end
    g.setStencilTest()

    -- 4. 绘制文字信息
    local name_str = random and "？？？" or Pilots.profile({character_id = pilot.id, team_id = pilot.team}).name
    outlined_text(g, role .. "：" .. name_str, x + 2, y + h - strip_h + 6, w - 4, "center", 14)

    -- 5. 绘制外边框
    g.setColor(col.border[1], col.border[2], col.border[3], 0.95)
    g.setLineWidth(2)
    g.rectangle("line", x, y, w, h, r, r)
end

-- 单侧完整绘制：面板、队名、指挥官卡、左右手卡、队员排、箭头（含切换动画）
local function draw_side(g, game, which, y0, selected)
    local w = love.graphics.getWidth()
    local id = UI.list()[which == "player" and UI.player or UI.enemy]
    local side = side_display(id)
    local mirror = (which == "enemy")
    local col = side_colors(which)
    local anim = UI.anim[which]
    local t = UI.clock - anim.at
    local p = math.min(1, math.max(0, t / 0.35))
    local ease = 1 - (1 - p) * (1 - p) * (1 - p)
    local slide = (1 - ease) * 140 * anim.dir
    local flash = 0
    
    if t > 0.35 and t < 0.75 then flash = 1 - (t - 0.35) / 0.4 end

    g.push("all")
    g.setScissor(0, y0, w, SHOW_H)
    g.setColor(0.02, 0.05, 0.1, 0.4)
    g.rectangle("fill", 0, y0, w, SHOW_H)

    g.setFont(Fonts.get(24))
    local name_str_display = team_name(id)
    local has_skin = skins_for(id) ~= nil
    if which == "player" then
        g.setColor(1, 0.92, 0.5)
        g.print(name_str_display, 34, y0 + 8)
    else
        g.setColor(1, 0.42, 0.38)
        g.printf(name_str_display, w - 34 - 420, y0 + SHOW_H - 40, 420, "right")
    end

    local commander_cx = 0.5 * w
    local lx, rx = 0.24 * w, 0.76 * w

    local cmd_y, off_y, mem_cy

    if which == "player" then
        cmd_y = y0 + 6
        off_y = y0 + 56
        mem_cy = y0 + SHOW_H - 36
    else
        cmd_y = y0 + SHOW_H - 250 - 6
        off_y = y0 + SHOW_H - 190 - 56
        mem_cy = y0 + 36
    end

    -- 指挥官 (190x250) & 左右手 (170x190) - 左右位置保持一致，不做水平翻转
    local sf=skin_fx[which]
    if sf and sf.team ~= id then
        sf.team=id; sf.current=get_skin(which,id); sf.time=0; sf.old=nil; sf.new=nil
    end
    local flip=(sf and sf.time>0) and math.min(1,sf.time/0.8) or 0
    -- 翻牌：绕水平中轴上下翻面，只压缩垂直方向，横向宽度保持不变。
    local flip_scale=flip>0 and math.max(0.04,math.abs(math.cos(flip*math.pi))) or 1
    local flip_progress = 1 - flip
    local display_skin = sf and sf.current
    if display_skin == nil then
        display_skin = get_skin(which, id)
        if sf then sf.current = display_skin end
    end
    if sf and sf.time > 0 then
        display_skin = flip_progress < 0.5 and sf.old or sf.new
    end
    if display_skin == "default" then display_skin = nil end
    local mx,my=love.mouse.getPosition()
    local hovered=nil
    local function hover_card(key,cx,cy,cw,ch)
        local h=has_skin and mx>=cx-cw/2 and mx<=cx+cw/2 and my>=cy and my<=cy+ch
        if h then hovered=key end
        skin_hit[which..":"..key]=has_skin and {team=id,x=cx-cw/2,y=cy,w=cw,h=ch} or nil
        return h and (1+0.035*(0.5+0.5*math.sin(UI.clock*7))) or 1
    end
    skin_hover[which]=hovered
    local cmd_scale=hover_card("commander",commander_cx,cmd_y,190,250)
    g.push("all");g.translate(commander_cx,cmd_y+125);g.scale(cmd_scale,flip_scale*cmd_scale);g.translate(-commander_cx,-cmd_y-125)
    draw_portrait_card(g, which, commander_cx - 95, cmd_y, 190, 250, "指挥", side.commander, id == "random", slide, flash, display_skin)
    g.pop()
    local left_scale=hover_card("left",lx,off_y,170,190)
    local right_scale=hover_card("right",rx,off_y,170,190)
    g.push("all");g.translate(lx,off_y+95);g.scale(left_scale,flip_scale*left_scale);g.translate(-lx,-off_y-95)
    draw_portrait_card(g, which, lx - 85, off_y, 170, 190, "左手", side.left, id == "random", slide, flash, display_skin);g.pop()
    g.push("all");g.translate(rx,off_y+95);g.scale(right_scale,flip_scale*right_scale);g.translate(-rx,-off_y-95)
    draw_portrait_card(g, which, rx - 85, off_y, 170, 190, "右手", side.right, id == "random", slide, flash, display_skin);g.pop()

    -- 队员行：全部成员按花名册排列；金色描边=上阵，暗化=增援池，点击切换。
    local entries = UI.team_entries(id)
    local gap = 74
    local x0 = commander_cx - (#entries - 1) * gap / 2 + slide
    UI.member_hits = UI.member_hits or {}
    UI.member_hits[which] = {}
    local count = 0
    for i, e in ipairs(entries) do
        local m = side.members[i]
        local cx = x0 + (i - 1) * gap
        if e.selected then count = count + 1 end
        local hot = mx >= cx - 32 and mx <= cx + 32 and my >= mem_cy - 4 and my <= mem_cy + 64
        UI.member_hits[which][i] = { x = cx - 32, y = mem_cy - 4, w = 64, h = 68, id = e.id }
        local sc = hot and (1 + 0.05 * (0.5 + 0.5 * math.sin(UI.clock * 7))) or 1
        g.push("all");g.translate(cx,mem_cy+29);g.scale(sc,flip_scale*sc);g.translate(-cx,-mem_cy-29)
        draw_avatar(g, m and m.team or id, e.id, cx-29, mem_cy, 58, game, mirror and 1 or 0, display_skin);g.pop()
        if e.selected then
            g.setColor(1,0.82,0.35,0.95); g.setLineWidth(2.5)
            g.rectangle("line", cx-31, mem_cy-3, 62, 66, 8, 8)
        else
            g.setColor(0.01,0.02,0.04,0.62)
            g.rectangle("fill", cx-31, mem_cy-3, 62, 66, 8, 8)
            g.setColor(0.45,0.5,0.55,0.8); g.setLineWidth(1.5)
            g.rectangle("line", cx-31, mem_cy-3, 62, 66, 8, 8)
        end
    end
    -- 上阵计数（满员时闪烁提示）；皮肤循环不再挂队员头像，只保留三张卡片。
    local flash = UI.limit_flash and UI.limit_flash.team == id and UI.clock < UI.limit_flash.expiry
    local label = string.format("上阵 %d/%d", count, Loadout.limit())
    g.setFont(Fonts.get(15))
    if flash then
        g.setColor(1,0.35,0.3,0.6+0.4*math.sin(UI.clock*18))
        label = label.."  已满员，先撤下一人"
    else
        g.setColor(1,0.9,0.6,0.9)
    end
    if which == "player" then g.print(label, 34, y0 + 40)
    else g.printf(label, w - 34 - 420, y0 + 8, 420, "right") end
    g.setColor(1, 1, 1, 1)

    g.pop()
    -- 队伍切换箭头仍属于编队选择，不与皮肤卡片交互混用。
    local cy = y0 + SHOW_H / 2 - 30
    UI.arrows[which] = {
        {x = 14, y = cy, w = 56, h = 60, dir = -1, side = which},
        {x = w - 70, y = cy, w = 56, h = 60, dir = 1, side = which}
    }
    for _, a in ipairs(UI.arrows[which]) do
        local hot = which == UI.bar
        g.setColor(0.06, 0.12, 0.22, 0.95)
        g.rectangle("fill", a.x, a.y, a.w, a.h, 10, 10)
        g.setColor(hot and 1 or 0.5, hot and 0.75 or 0.6, hot and 0.3 or 0.65, 0.95)
        g.setLineWidth(2)
        g.rectangle("line", a.x, a.y, a.w, a.h, 10, 10)
        g.setFont(Fonts.get(26))
        g.setColor(1, 1, 1)
        g.printf(a.dir < 0 and "◀" or "▶", a.x, a.y + 14, a.w, "center")
    end
    g.setColor(1, 1, 1, 1)
end

-- 中央 vs：拉长至屏幕边缘的白色分割线
local function draw_vs(g, w, cy)
    local pulse = 0.5 + 0.5 * math.sin(UI.clock * 4.2)
    g.push("all")
    
    g.setColor(1, 1, 1, 0.35 + 0.45 * pulse) 
    g.setLineWidth(1)
    g.line(70, cy, w / 2 - 50, cy)
    g.line(w / 2 + 50, cy, w - 70, cy)
    
    local sc = 1 + 0.06 * math.sin(UI.clock * 5)
    g.translate(w / 2, cy)
    g.scale(sc, sc)
    
    local font = Fonts.get(40)
    g.setFont(font)
    
    local font_h = font:getHeight()
    local ty = -font_h / 2
    
    g.setColor(0.9, 0.15, 0.12, 0.85)
    g.printf("vs", -124, ty + 2, 248, "center")
    g.setColor(1, 0.95, 0.9, 0.95)
    g.printf("vs", -124, ty, 248, "center")
    g.pop()
    g.setColor(1, 1, 1, 1)
end

function UI.cycle(which, delta)
    local n = #UI.list()
    if which == "player" then 
        UI.player = ((UI.player - 1 + delta) % n) + 1
    else 
        UI.enemy = ((UI.enemy - 1 + delta) % n) + 1 
    end
    UI.anim[which] = {at = UI.clock, dir = delta or 1}
end

function UI.keypressed(key)
    if key == "up" then UI.bar = "player"
    elseif key == "down" then UI.bar = "enemy"
    elseif key == "left" then UI.cycle(UI.bar, -1)
    elseif key == "right" then UI.cycle(UI.bar, 1) end
end

function UI.wheelmoved(dy, mx, my)
    local which = UI.bar
    if my >= show_y("player") and my < show_y("player") + SHOW_H then which = "player"
    elseif my >= show_y("enemy") and my < show_y("enemy") + SHOW_H then which = "enemy" end
    UI.cycle(which, dy > 0 and -1 or 1)
end

-- 皮肤列表：队伍有 skins 目录才可切换；cycle 按方向循环并写偏好。
-- 注意：getInfo 对目录首返回值为 nil，目录存在性一律用 getDirectoryItems 判断。
skins_for = function(team_id)
    if not team_id or team_id == "random" or team_id == "default" then return nil end
    local sdir = "teams/" .. team_id .. "/skins"
    if #(love.filesystem.getDirectoryItems(sdir)) == 0 then return nil end
    local skins = {"default"}
    for _, sk in ipairs(love.filesystem.getDirectoryItems(sdir)) do
        if #(love.filesystem.getDirectoryItems(sdir .. "/" .. sk)) > 0 and sk ~= "default" then skins[#skins + 1] = sk end
    end
    if #skins < 2 then return nil end
    return skins
end
function UI.cycle_skin(team_id, dir, target_which)
    local skins = skins_for(team_id)
    if not skins then return end
    local target = target_which
    if target ~= "player" and target ~= "enemy" then return end
    local key = skin_pref_key(target, team_id)
    local cur = (target and skin_fx[target].current) or Preferences.get(key, "default")
    if target and skin_fx[target].time > 0 then
        local progress=1-math.min(1,skin_fx[target].time/0.8)
        cur=(progress < 0.5) and skin_fx[target].old or skin_fx[target].new or cur
    end
    local idx = 1
    for i, s in ipairs(skins) do if s == cur then idx = i break end end
    local next_idx = ((idx - 1 + (dir or 1)) % #skins) + 1
    local next_skin=skins[next_idx]
    local saved=Preferences.set(key, next_skin)
    if saved == false then return end
    if target then
        skin_fx[target].team=team_id
        skin_fx[target].old=cur
        skin_fx[target].new=next_skin
        skin_fx[target].current=next_skin
    end
    if target then skin_fx[target].time=0.8 end
end
skin_label = function(team_id, which)
    local cur = Preferences.get(skin_pref_key(which or "player", team_id), "default")
    return cur == "default" and "默认" or cur
end

function UI.click(x, y)
    local w = love.graphics.getWidth()
    local click_side
    if y >= show_y("player") and y < show_y("player") + SHOW_H then click_side="player"
    elseif y >= show_y("enemy") and y < show_y("enemy") + SHOW_H then click_side="enemy" end
    -- 队员头像：点击切换上阵/增援池（两侧都可编辑，立即保存编队）。
    if click_side and UI.member_hits and UI.member_hits[click_side] then
        for _, hit in ipairs(UI.member_hits[click_side]) do
            if x >= hit.x and x <= hit.x + hit.w and y >= hit.y and y <= hit.y + hit.h then
                local id = UI.list()[click_side == "player" and UI.player or UI.enemy]
                UI.toggle_member(id, hit.id)
                return false
            end
        end
    end
    for _,which in ipairs({"player","enemy"}) do
        if click_side and which ~= click_side then goto continue_click_side end
        local id=UI.list()[which=="player" and UI.player or UI.enemy]
        if skins_for(id) then
            local y0 = show_y(which)
            local cmd_y = which == "player" and y0 + 6 or y0 + SHOW_H - 250 - 6
            local off_y = which == "player" and y0 + 56 or y0 + SHOW_H - 190 - 56
            local cx, lx, rx = 0.5 * w, 0.24 * w, 0.76 * w
            local hit = (x >= cx-95 and x <= cx+95 and y >= cmd_y and y <= cmd_y+250)
                or (x >= lx-85 and x <= lx+85 and y >= off_y and y <= off_y+190)
                or (x >= rx-85 and x <= rx+85 and y >= off_y and y <= off_y+190)
            if hit then
                if not skin_fx[which] or skin_fx[which].time <= 0 then UI.cycle_skin(id, 1, which) end
                return false
            end
        end
        ::continue_click_side::
    end
    for _, group in pairs(UI.arrows) do
        for _, a in ipairs(group) do
            if x >= a.x and x <= a.x + a.w and y >= a.y and y <= a.y + a.h then
                UI.cycle(a.side, a.dir)
                return false
            end
        end
    end
    local cy = (show_y("player") + SHOW_H + show_y("enemy")) / 2
    if math.abs(x - w / 2) <= 80 and math.abs(y - cy) <= 36 then return true end
    return false
end

function UI.draw(game)
    local g = love.graphics
    local w = love.graphics.getWidth()
    UI.clock = love.timer.getTime()
    local delta=love.timer.getDelta and love.timer.getDelta() or 0.016
    for _,fx in pairs(skin_fx) do fx.time=math.max(0,fx.time-delta) end
    require("systems.space_scene").draw_background(game, {x = 0, y = 0, zoom = 0.5})
    update_random_preview()
    
    UI.arrows = {}
    skin_hit = {}
    draw_side(g, game, "player", show_y("player"), UI.bar == "player")
    draw_side(g, game, "enemy", show_y("enemy"), UI.bar == "enemy")
    draw_vs(g, w, (show_y("player") + SHOW_H + show_y("enemy")) / 2)
end

return UI
