-- 武器类型注册表。普通武器与必杀技分离；视觉/音效可在此扩展。
local Weapons={
    cannon={attack_type="ranged",sound="main_gun",visual="cannon"},
    machine_gun={attack_type="ranged",sound="shot",visual="machine_gun"},
    missile={attack_type="missile",sound="missile",visual="missile"},
    beam={attack_type="beam",sound="beam",visual="beam"},
    artillery={attack_type="artillery",sound="artillery",visual="artillery"},
}
function Weapons.resolve(id,fallback)
    local base=Weapons[id or ""]
    if not base then return fallback end
    local out={};for k,v in pairs(base) do out[k]=v end
    return out
end
return Weapons
