local Arrows={}

--------------------------------------------------
-- 颜色
--------------------------------------------------

function Arrows.color(action,target,player_team)
    if action=="move" then
        return 0.25,0.65,1.0,0.82
    end

    if action=="repair" or action=="follow" then
        return 0.20,1.0,0.36,0.82
    end

    if action=="attack" then
        if target then
            if target.team~=player_team then
                return 1.0,0.16,0.12,0.82
            end
            return 0.20,1.0,0.36,0.82
        end

        return 1.0,0.22,0.14,0.72
    end

    return 1,1,1,0.75
end


--------------------------------------------------
-- Shader
--
-- 根据像素在箭头长度方向上的位置计算 alpha。
-- 不再使用 64 段线，因此不会产生断层。
--------------------------------------------------

local gradient_shader=love.graphics.newShader([[
extern vec2 line_start;
extern vec2 line_end;
extern number gradient_start;
extern number gradient_end;
extern number gradient_power;
extern number alpha_strength;

vec4 effect(
    vec4 color,
    Image texture,
    vec2 texture_coords,
    vec2 screen_coords
)
{
    vec2 direction=line_end-line_start;
    float length_squared=dot(direction,direction);

    if(length_squared<=0.0001)
        return color;

    float position=dot(
        screen_coords-line_start,
        direction
    )/length_squared;

    position=clamp(position,0.0,1.0);

    /*
        smoothstep：
        0 → 完全透明
        中间 → 平滑过渡
        1 → 完整亮度
    */
    float gradient=smoothstep(
        gradient_start,
        gradient_end,
        position
    );

    /*
        控制渐变曲线。
        >1 会让前段更柔和。
    */
    gradient=pow(gradient,gradient_power);

    color.a*=gradient*alpha_strength;

    return color;
}
]])


--------------------------------------------------
-- Shader 参数
--------------------------------------------------

local function set_gradient(x1,y1,x2,y2,strength)
    gradient_shader:send("line_start",{x1,y1})
    gradient_shader:send("line_end",{x2,y2})

    -- 前 25% 比较淡
    gradient_shader:send("gradient_start",0.00)

    -- 到 42% 左右基本进入完整亮度
    gradient_shader:send("gradient_end",0.42)

    -- 渐变曲线
    gradient_shader:send("gradient_power",0.82)

    gradient_shader:send("alpha_strength",strength or 1)
end


--------------------------------------------------
-- 箭头绘制
--------------------------------------------------

function Arrows.draw(x1,y1,x2,y2,r,g,b,a,width,fade_in)

    local dx=x2-x1
    local dy=y2-y1

    local len=math.sqrt(dx*dx+dy*dy)

    if len<12 then
        return
    end

    dx=dx/len
    dy=dy/len

    width=width or 3


    --------------------------------------------------
    -- Glow
    --------------------------------------------------

    love.graphics.setShader(gradient_shader)

    set_gradient(
        x1,y1,
        x2,y2,
        0.65
    )

    love.graphics.setLineWidth(width+7)

    love.graphics.setColor(
        r,g,b,
        a*0.10
    )

    love.graphics.line(
        x1,y1,
        x2,y2
    )


    --------------------------------------------------
    -- 主箭杆
    --------------------------------------------------

    set_gradient(
        x1,y1,
        x2,y2,
        1.0
    )

    love.graphics.setLineWidth(width)

    love.graphics.setColor(
        r,g,b,
        a
    )

    love.graphics.line(
        x1,y1,
        x2,y2
    )


    --------------------------------------------------
    -- 关闭 Shader
    --------------------------------------------------

    love.graphics.setShader()


    --------------------------------------------------
    -- 箭头
    --------------------------------------------------

    local head=math.min(
        20,
        len*0.18
    )

    local spread=0.48

    local cs=math.cos(spread)
    local sn=math.sin(spread)


    local lx=x2-head*(dx*cs-dy*sn)
    local ly=y2-head*(dy*cs+dx*sn)

    local rx=x2-head*(dx*cs+dy*sn)
    local ry=y2-head*(dy*cs-dx*sn)


    --------------------------------------------------
    -- 箭头 Glow
    --------------------------------------------------

    love.graphics.setLineWidth(width+4)

    love.graphics.setColor(
        r,g,b,
        a*0.10
    )

    love.graphics.line(
        x2,y2,
        lx,ly
    )

    love.graphics.line(
        x2,y2,
        rx,ry
    )


    --------------------------------------------------
    -- 箭头主体
    --------------------------------------------------

    love.graphics.setLineWidth(width+1)

    love.graphics.setColor(
        r,g,b,
        a
    )

    love.graphics.line(
        x2,y2,
        lx,ly
    )

    love.graphics.line(
        x2,y2,
        rx,ry
    )


    love.graphics.setLineWidth(1)

    love.graphics.setColor(
        1,1,1,1
    )
end


--------------------------------------------------
-- 单位目标箭头
--------------------------------------------------

function Arrows.draw_target(game,camera,unit)

    if not unit or not unit.alive then
        return
    end

    local action
    local target

    -- 运行时目标优先。camera_target 只是指令落点缓存，不能覆盖
    -- 实际跟随/攻击/维修目标，否则目标死亡或切换后会继续画旧箭头。
    if unit.follow_target and unit.follow_target.alive then
        action="follow"
        target=unit.follow_target
    elseif unit.attack_target and unit.attack_target.alive then
        action="attack"
        target=unit.attack_target
    elseif unit.repair_target and unit.repair_target.alive then
        action="repair"
        target=unit.repair_target
    elseif unit.target_pos then
        action="move"
        target={x=unit.target_pos.x or unit.target_pos[1],y=unit.target_pos.y or unit.target_pos[2]}
    elseif unit.camera_target then
        local ct=unit.camera_target
        action=ct.kind
        target=ct.target or {x=ct.x,y=ct.y}
        if action=="camera_move" or action=="move_target" or action=="moving" then action="move" end
    end

    if action=="attack" and target and not target.alive then
        return
    end

    -- 兼容旧状态字段，但不让失效目标穿透到渲染层。
    if not target and unit.attack_target then

        action="attack"
        target=unit.attack_target
    elseif not target and unit.repair_target then
        action="repair"
        target=unit.repair_target
    elseif not target and unit.follow_target then
        action="follow"
        target=unit.follow_target
    end


    if not target then
        return
    end


    local sx,sy=
        camera:world_to_screen(
            unit.x,
            unit.y-(unit.z or 0)*0.22
        )


    local ex,ey=
        camera:world_to_screen(
            target.x,
            target.y
        )


    local r,g,b
    if action=="attack" and unit.team~=game.player_team then
        r,g,b=1.0,0.16,0.12
    else
        r,g,b=Arrows.color(action,action=="attack" and target or nil,game.player_team)
    end


    Arrows.draw(
        sx,sy,
        ex,ey,
        r,g,b,
        0.80,
        4,
        false
    )
end


--------------------------------------------------
-- Feedback 箭头
--------------------------------------------------

function Arrows.draw_feedback(camera,feedbacks)

    for _,f in ipairs(feedbacks or {}) do

        local a=
            math.max(
                0,
                f.life/f.duration
            )


        local sx,sy=
            camera:world_to_screen(
                f.x1,
                f.y1
            )


        local ex,ey=
            camera:world_to_screen(
                f.x2,
                f.y2
            )


        Arrows.draw(
            sx,sy,
            ex,ey,
            f.r,f.g,f.b,
            a*0.72,
            3,
            false
        )

    end
end


--------------------------------------------------
-- 玩家正在指定目标时的箭头
--------------------------------------------------

function Arrows.draw_targeting(
    game,
    camera,
    units,
    action,
    hover_target
)

    local mx,my=
        love.mouse.getPosition()


    local r,g,b,a=
        Arrows.color(
            action,
            hover_target,
            game.player_team
        )


    for _,u in ipairs(units or {}) do

        if u.alive
        and u.state~="dead" then

            local sx,sy=
                camera:world_to_screen(
                    u.x,
                    u.y-(u.z or 0)*0.22
                )


            Arrows.draw(
                sx,sy,
                mx,my,
                r,g,b,
                a,
                3,
                false
            )

        end
    end


    --------------------------------------------------
    -- 鼠标目标指示器
    --------------------------------------------------

    love.graphics.setColor(
        r,g,b,a
    )


    if hover_target then

        love.graphics.circle(
            "line",
            mx,my,
            18
        )

        love.graphics.circle(
            "line",
            mx,my,
            9
        )

    else

        love.graphics.circle(
            "line",
            mx,my,
            10
        )

        love.graphics.line(
            mx-8,my,
            mx+8,my
        )

        love.graphics.line(
            mx,my-8,
            mx,my+8
        )

    end


    love.graphics.setColor(
        1,1,1,1
    )
end


return Arrows
