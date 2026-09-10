-- 命令层：玩家命令与自动命令（AI、机体自动行为）设置战斗状态的唯一入口。
-- entities/unit.lua 的状态机只消费命令产生的字段，其内部流转（接敌转环绕、
-- 返航转补给、补给离舰）不经过这里；机型脚本延续自身攻击状态同样属于内部流转。
--
-- 优先级仲裁：
--   * 玩家命令覆盖一切（包括补给流程，与旧 orders 行为一致）。
--   * 玩家命令在位（unit.command.source=="player"）期间，自动命令一律拒绝。
--   * 自动命令之间后者覆盖前者；补给流程（returning/supplying/undocking）
--     期间只接受 "return" 的重复下发。
--   * 命令完成点（到达、目标死亡转空闲、跟随/维修结束、补给离舰）由状态机
--     调用 Commands.finish 清除命令，自动行为随之恢复。
--
-- 清理约定：所有下发都会清掉与旧命令冲突的目标字段；玩家命令额外取消连发
-- 队列并作废航线，自动命令保留两者（与迁移前双方路径的实际行为一致）。
local Commands = {}

local SUPPLY_FLOW = { returning = true, supplying = true, undocking = true }

local function clear_stale(unit, game, source, kind)
    local had_follow = unit.follow_target
    unit.attack_target = nil
    unit.follow_target = nil
    unit.repair_target = nil
    unit.target_pos = nil
    unit.attack_move = nil
    if had_follow and kind ~= "follow" and game then
        game:report_event(unit, "formation_follow_end", "")
    end
    if source == "player" or kind == "return" then
        require("battle.unit.combat").cancel_bursts(unit)
        unit.route = nil
    end
end

-- 同命令重复下发不重复清理，避免 AI 每 tick 重发攻击时打断连发。
local function already_doing(unit, kind, options)
    local c = unit.command
    if not c or c.kind ~= kind then return false end
    if kind == "attack" then
        return c.target == options.target and unit.state == "attacking"
    elseif kind == "follow" then
        return c.target == options.target and unit.state == "following"
    elseif kind == "repair" then
        return c.target == options.target and unit.state == "repairing"
    elseif kind == "move" or kind == "attack_move" then
        return math.abs((c.x or 0) - (options.x or 0)) + math.abs((c.y or 0) - (options.y or 0)) <= 12
            and unit.state == "moving"
    elseif kind == "return" then
        return SUPPLY_FLOW[unit.state] ~= nil
    elseif kind == "defend" then
        return c.anchor == options.anchor and unit.state == "moving"
    end
    return false
end

-- kind: "move"|"attack_move"|"attack"|"follow"|"repair"|"return"|"defend"
-- options: { source="player"|"auto"(默认), target=, x=, y=, anchor=, engage= }
-- attack_move 的 engage 为移动期间保持锁定的敌人（AI 侧翼/巡逻用）。
function Commands.issue(game, unit, kind, options)
    if not unit or not unit.alive or unit.state == "disabled" or unit.state == "dead" then
        return false
    end
    options = options or {}
    local source = options.source or "auto"
    local current = unit.command
    if current and current.source == "player" and source == "auto" then return false end
    if source == "auto" and SUPPLY_FLOW[unit.state] and kind ~= "return" then return false end
    if already_doing(unit, kind, options) then return false end

    -- 返航前记录当前目标，补给完成后由状态机恢复接战。
    local resume_target = unit.attack_target
    clear_stale(unit, game, source, kind)

    if kind == "move" or kind == "attack_move" then
        unit.target_pos = { options.x or unit.x, options.y or unit.y }
        unit.state = "moving"
        if kind == "attack_move" then
            unit.attack_move = { options.x or unit.x, options.y or unit.y }
            unit.attack_target = options.engage
        end
    elseif kind == "attack" then
        unit.attack_target = options.target
        unit.state = "attacking"
    elseif kind == "follow" then
        unit.follow_target = options.target
        unit.follow_report_time = game and game.level_time or 0
        unit.state = "following"
        if source == "player" and game then
            game:report_event(unit, "formation_follow_start", "")
        end
    elseif kind == "repair" then
        unit.repair_target = options.target
        unit.state = "repairing"
    elseif kind == "return" then
        -- 无条件覆写：目标为 nil 时清掉上一轮的陈旧恢复目标。
        unit.supply_resume_target = resume_target
        unit.state = "returning"
    elseif kind == "defend" then
        unit.follow_target = options.anchor
        unit.target_pos = { options.x or unit.x, options.y or unit.y }
        unit.state = "moving"
    else
        return false
    end

    unit.command = {
        kind = kind, source = source,
        target = options.target, anchor = options.anchor,
        x = options.x, y = options.y,
    }
    unit.state_timer = 0
    return true
end

-- 命令完成点由状态机调用；清除后自动行为（AI、自动接敌）恢复可用。
function Commands.finish(unit)
    unit.command = nil
end

function Commands.active_player_command(unit)
    return unit.command and unit.command.source == "player" and unit.command or nil
end

return Commands
