local P={values={},path="saves/preferences.tbl",loaded=false}
function P.load()
    if P.loaded then return end
    P.loaded=true
    if _G.VERIFY_RUNNING then return end
    local data=love.filesystem.getInfo(P.path) and require("core.tbl").parse_file(P.path) or {}
    P.values=data.preferences or {}
end
function P.save()
    if _G.VERIFY_RUNNING then return true end
    local keys,lines={}, {"[preferences]"}
    for k in pairs(P.values) do keys[#keys+1]=k end
    table.sort(keys)
    for _,k in ipairs(keys) do
        local v=P.values[k]
        if type(v)=="boolean" or type(v)=="number" then lines[#lines+1]=k.." = "..tostring(v)
        elseif type(v)=="string" then lines[#lines+1]=k..' = "'..v..'"' end
    end
    love.filesystem.createDirectory("saves")
    return love.filesystem.write(P.path,table.concat(lines,"\n").."\n")
end
function P.get(key,default)
    P.load()
    if P.values[key]==nil or type(P.values[key])~=type(default) then return default end
    return P.values[key]
end
function P.set(key,value)
    P.load();P.values[key]=value
    return P.save()
end
function P.apply(unit)
    if unit.game and unit.team==unit.game.player_team then
        unit.auto_skill=P.get("auto_skill_"..unit.character_id,false)
    end
end
return P
