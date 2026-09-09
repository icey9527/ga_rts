local UI = {player = 1, enemy = 2, bar = "player", formation = "line", clock = 0, arrows = {},
anim = {player = {at = -10, dir = 1}, enemy = {at = -10, dir = 1}}}

local Fonts = require("core.fonts")
local Pilots = require("ui.pilots")
local Registry = require("systems.pack_registry")
local SHOW_H = 340

function UI.list()
    if not UI._list then
        local ok, ids = pcall(Registry.ids)
        local real = (ok and type(ids) == "table" and #ids > 0) and ids or {"rune", "moon"}
        local filtered = {}
        for _, id in ipairs(real) do
            if id ~= "default" and id ~= "random" then filtered[#filtered + 1] = id end
        end
        if #filtered == 0 then filtered = {"rune", "moon"} end
        filtered[#filtered + 1] = "random"  -- 随机永远排在最末尾
        UI._list = filtered
        for i, id in ipairs(UI._list) do
            if id == "rune" then UI.player = i end
            if id == "moon" then UI.enemy = i end
        end
    end
    return UI._list
end

function UI.reset()
    UI._list = nil
    UI.player, UI.enemy, UI.bar = 1, 2, "player"
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

local function draw_standing(g, team_id, char_id, cx, anchor_y, height, anchor, alpha, flash)
    local img = Pilots.standing({character_id = char_id, team_id = team_id})
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
        Pilots.draw({character_id = char_id, team_id = team_id}, cx - size / 2, ay, size, size, "bare")
    end
end

local function draw_avatar(g, team_id, char_id, cx, cy, size, game, team)
    Pilots.draw({character_id = char_id, team_id = team_id, game = game, team = team}, cx - size / 2, cy - size / 2, size, size)
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
    local font = Fonts.get(size)
    g.setFont(font)
    g.setColor(color)
    local fh = font:getHeight()
    local box_w = size * 4
    g.printf(text, cx - box_w / 2, cy - fh / 2, box_w, "center")
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
        return UI.random_preview or {commander = {team = "rune", id = 0}, left = {team = "rune", id = 25}, right = {team = "rune", id = 22}, members = {}}
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

-- ==========================================
-- 核心卡牌绘制逻辑统一合并
-- ==========================================
local function draw_portrait_card(g, which, x, y, w, h, role, pilot, random, slide, flash)
    local col = side_colors(which)
    local strip_h = 30 -- 文字区域尺寸
    local r = 12       -- 圆角半径

    -- 1. 绘制底层黑色蒙版背景
    g.setColor(0.04, 0.07, 0.13, 0.92)
    g.rectangle("fill", x, y, w, h, r, r)

    -- 2. 绘制底部阵营颜色条（使用剪裁区域实现外侧完美贴合）
    g.setScissor(x, y + h - strip_h, w, strip_h)
    g.setColor(col.strip[1], col.strip[2], col.strip[3], 0.95)
    g.rectangle("fill", x, y, w, h, r, r) 
    g.setScissor()

    -- 3. 绘制立绘区域
    g.setScissor(x, y, w, h - strip_h)
    if random then
        draw_mark(g, "？", x + w / 2, y + (h - strip_h) / 2, math.floor(w * 0.35), {1, 0.95, 0.6})
    else
        draw_standing(g, pilot.team, pilot.id, x + w / 2 + (slide or 0), y + h - strip_h, h - strip_h - 4, "bottom", 1, flash)
    end
    g.setScissor()

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
    if which == "player" then
        g.setColor(1, 0.92, 0.5)
        g.print(team_name(id), 34, y0 + 8)
    else
        g.setColor(1, 0.42, 0.38)
        g.printf(team_name(id), w - 34 - 420, y0 + SHOW_H - 40, 420, "right")
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
    draw_portrait_card(g, which, commander_cx - 95, cmd_y, 190, 250, "指挥", side.commander, id == "random", slide, flash)
    draw_portrait_card(g, which, lx - 85, off_y, 170, 190, "左手", side.left, id == "random", slide, flash)
    draw_portrait_card(g, which, rx - 85, off_y, 170, 190, "右手", side.right, id == "random", slide, flash)

    local gap = 74
    local x0 = commander_cx - (#side.members - 1) * gap / 2 + slide
    for i, m in ipairs(side.members) do
        -- 队员一律按原始顺序从左往右排列
        draw_avatar(g, m.team, m.id, x0 + (i - 1) * gap, mem_cy, 58, game, mirror and 1 or 0)
    end

    g.pop()

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
    if my >= show_y("player") and my < show_y("player") + SHOW_H then which = "player" end
    if my >= show_y("enemy") and my < show_y("enemy") + SHOW_H then which = "enemy" end
    UI.cycle(which, dy > 0 and -1 or 1)
end

function UI.click(x, y)
    local w = love.graphics.getWidth()
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
    
    require("systems.space_scene").draw_background(game, {x = 0, y = 0, zoom = 0.5})
    update_random_preview()
    
    UI.arrows = {}
    draw_side(g, game, "player", show_y("player"), UI.bar == "player")
    draw_side(g, game, "enemy", show_y("enemy"), UI.bar == "enemy")
    draw_vs(g, w, (show_y("player") + SHOW_H + show_y("enemy")) / 2)
end

return UI