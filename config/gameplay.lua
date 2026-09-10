-- 运行时玩法参数单一来源：battle/ 与 systems/ 直接 require 本模块，
-- 不再读 _G.SETTINGS。main.lua 启动时把 config/settings.tbl 的 [gameplay]
-- 段合并进来作为用户覆盖（设置文件仍可调参）。
local Gameplay = {
    supply_range = 100,
    supply_rate = 80,
    supply_hp_rate = 50,
    energy_attack_cost = 5,
    energy_repair_cost = 3,
    fighter_auto_range = 2200,
    ai_lock_range = 2800,
}

function Gameplay.apply_overrides(section)
    for k, v in pairs(section or {}) do
        if type(v) == "number" then Gameplay[k] = v end
    end
end

return Gameplay
