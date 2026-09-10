local Weapons={}
local Heat=require("battle.unit.heat")

function Weapons.normalize(list,defaults)
    local out={}
    for _,definition in ipairs((list and #list>0) and list or {defaults or {}}) do
        local weapon={}
        for k,v in pairs(definition) do weapon[k]=v end
        weapon.cooldown_timer=0
        weapon.heat=0
        weapon.overheated=false
        out[#out+1]=weapon
    end
    local registry=require("battle.weapons")
    for _,weapon in ipairs(out) do
        local kind=weapon.kind or weapon.id
        local preset=registry.resolve(kind)
        if preset then
            weapon.visual=weapon.visual or preset.visual
            weapon.sound=weapon.sound or preset.sound
            weapon.type=weapon.type or preset.attack_type
        end
        local id=weapon.id or "main"
        local defaults_by_id={
            main={arc=100,direction="front"},
            cannon={arc=100,direction="front"},
            sniper_rifle={arc=35,direction="front",cooldown=6.2},
            machine_gun={arc=150,direction="front"},
            missile={arc=240,direction="front"},
            secondary={arc=180,direction="front"},
            artillery={arc=300,direction="front"},
        }
        local d=defaults_by_id[id] or defaults_by_id.main
        weapon.arc=weapon.arc or d.arc
        weapon.direction=weapon.direction or d.direction
        weapon.cooldown=weapon.cooldown or (defaults and defaults.cooldown) or 1
        weapon.cooldown_timer=weapon.cooldown_timer or 0
        local heat_defaults={
            machine_gun={heat_per_shot=2,max_heat=100,cool_rate=24},
            sniper_rifle={heat_per_shot=18,max_heat=100,cool_rate=14},
            missile={heat_per_shot=20,max_heat=100,cool_rate=8},
            artillery={heat_per_shot=18,max_heat=100,cool_rate=10},
            secondary={heat_per_shot=12,max_heat=100,cool_rate=12},
            main={heat_per_shot=8,max_heat=100,cool_rate=14},
        }
        local hd=heat_defaults[id] or heat_defaults.main
        weapon.heat_per_shot=weapon.heat_per_shot or hd.heat_per_shot
        weapon.max_heat=weapon.max_heat or hd.max_heat
        weapon.cool_rate=weapon.cool_rate or hd.cool_rate
    end
    Heat.initialize(out)
    return out
end

function Weapons.can_fire(weapon)
    return Heat.can_fire(weapon)
end

function Weapons.on_fire(weapon,shots)
    Heat.consume(weapon,shots)
end

function Weapons.update(list,dt)
    Heat.update(list,dt)
    for _,weapon in ipairs(list or {}) do weapon.cooldown_timer=math.max(0,(weapon.cooldown_timer or 0)-dt) end
end

return Weapons
