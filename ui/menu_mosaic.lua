-- 主界面背景：从 teams 头像池随机抽取，按俄罗斯方块块形拼接铺底。
-- 整幅预渲染到 canvas，运行时一次 draw；每次进入主菜单重新随机。
-- 留洞即留洞（露出底色）是俄罗斯方块的味道，不追求铺满。
local Mosaic = {}
local CELL = 56

local TETROMINOES = {
    {{0,0},{1,0},{2,0},{3,0}},          -- I
    {{0,0},{1,0},{2,0},{2,1}},          -- J
    {{0,0},{1,0},{2,0},{0,1}},          -- L
    {{0,0},{1,0},{0,1},{1,1}},          -- O
    {{1,0},{2,0},{0,1},{1,1}},          -- S
    {{1,0},{0,1},{1,1},{2,1}},          -- T
    {{0,0},{1,0},{1,1},{2,1}},          -- Z
}

-- 头像池：teams/<队>/chara/<ID>/face 下**仅默认表情**（语义码 _0000）。
-- 表情变体不进拼图——表情系统重构（计划 14）后再考虑动态版。
local function avatar_paths()
    local out = {}
    local ok, teams = pcall(love.filesystem.getDirectoryItems, "teams")
    if not ok then return out end
    for _, team in ipairs(teams) do
        local cdir = "teams/" .. team .. "/chara"
        local okc, chars = pcall(love.filesystem.getDirectoryItems, cdir)
        if okc then
            for _, cid in ipairs(chars) do
                local fdir = cdir .. "/" .. cid .. "/face"
                local okf, files = pcall(love.filesystem.getDirectoryItems, fdir)
                if okf then
                    for _, f in ipairs(files) do
                        if f:match("%.png$") and f:find("_0000", 1, true) then
                            out[#out + 1] = fdir .. "/" .. f
                        end
                    end
                end
            end
        end
    end
    return out
end

local canvas

function Mosaic.build()
    local Pilots = require("ui.pilots")
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local cols, rows = math.ceil(w / CELL), math.ceil(h / CELL)
    local images = {}
    for _, path in ipairs(avatar_paths()) do
        local img = Pilots.image(path)
        if img then images[#images + 1] = img end
    end
    if #images == 0 then return nil end

    local out = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(out)
    love.graphics.clear(0.02, 0.03, 0.06, 1)
    love.graphics.setColor(1, 1, 1, 1)

    local occupied = {}
    local function place()
        local shape = TETROMINOES[math.random(#TETROMINOES)]
        local rot = math.random(0, 3)
        local cells = {}
        for _, c in ipairs(shape) do
            local x, y = c[1], c[2]
            for _ = 1, rot do
                x, y = y, -x
            end
            cells[#cells + 1] = {x, y}
        end
        -- 落点允许越出屏幕边缘：越界格不占也不画，块形因此被自然裁切。
        local cx, cy = math.random(-3, cols + 3), math.random(-3, rows + 3)
        for _, c in ipairs(cells) do
            local gx, gy = cx + c[1], cy + c[2]
            if gx >= 0 and gx < cols and gy >= 0 and gy < rows and occupied[gy * 4096 + gx] then
                return false
            end
        end
        for _, c in ipairs(cells) do
            local gx, gy = cx + c[1], cy + c[2]
            if gx >= 0 and gx < cols and gy >= 0 and gy < rows then
                occupied[gy * 4096 + gx] = true
                local img = images[math.random(#images)]
                local s = math.max(CELL / img:getWidth(), CELL / img:getHeight()) * 1.02
                love.graphics.setColor(0.34, 0.38, 0.46, 0.55)
                love.graphics.draw(img, gx * CELL + CELL / 2, gy * CELL + CELL / 2,
                    0, s, s, img:getWidth() / 2, img:getHeight() / 2)
            end
        end
        return true
    end

    -- 失败容忍度控制覆盖率：留出三成左右的洞，块状剪影才读得出来。
    local failures = 0
    while failures < 90 do
        if not place() then failures = failures + 1 end
    end
    -- 整体压暗 + 暗角：中央菜单区更暗，块状背景向四周渐隐。
    love.graphics.setColor(0.01, 0.02, 0.05, 0.34)
    love.graphics.rectangle("fill", 0, 0, w, h)
    for i = 0, 5 do
        local inset = i * math.min(w, h) * 0.045
        love.graphics.setColor(0.01, 0.02, 0.05, 0.10)
        love.graphics.rectangle("fill", 0, 0, w, inset)
        love.graphics.rectangle("fill", 0, h - inset, w, inset)
        love.graphics.rectangle("fill", 0, inset, inset, h - inset * 2)
        love.graphics.rectangle("fill", w - inset, inset, inset, h - inset * 2)
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    return out
end

function Mosaic.get()
    return canvas
end

-- 每次启动只随机一次（同一局内布局稳定，不随进出主菜单变化）；
-- 仅当画布尺寸与窗口不一致（ resize ）时重建。动态下沉式背景
-- 属表情/立绘系统重构（计划 14）后的工作，暂不实现。
function Mosaic.refresh()
    if canvas and canvas:getWidth() == love.graphics.getWidth()
        and canvas:getHeight() == love.graphics.getHeight() then
        return
    end
    canvas = Mosaic.build()
end

return Mosaic
