-- 随机编队逻辑：从所有队伍（含混池 default）混编指挥/左右手/成员。
-- 同一支随机编队内角色不重复；可传入排除表避免与对方阵营重复。
local Registry=require("systems.pack_registry")
local R={}

-- 汇总所有可选角色（含混池 default 队）
function R.pool()
    local out={}
    for _,tid in ipairs(Registry.ids()) do
        local cfg=Registry.load(tid).team or {}
        if cfg.commander then out[#out+1]={team=tid,id=tonumber(cfg.commander)} end
        for _,cid in ipairs(cfg.chara or {}) do
            cid=tonumber(cid)
            if cid then out[#out+1]={team=tid,id=cid} end
        end
    end
    return out
end

-- 组建一支随机编队；excluded_ids 为不可用的角色编号列表（通常是对方全体）。
function R.roster(excluded_ids)
    local excluded={}
    for _,id in ipairs(excluded_ids or {}) do
        if type(id)=="table" then excluded[tostring(id.team)..":"..tostring(id.id)]=true
        else excluded[id]=true end
    end
    local pool=R.pool()
    local used={}
    local function pick()
        for _=1,60 do
            local c=pool[math.random(math.max(1,#pool))]
            local key=c.team..":"..c.id
            if not excluded[key] and not used[key] then
                used[key]=true
                return c
            end
        end
        -- 池子耗尽时放宽排除表，但保证编队内仍不重复
        for _,c in ipairs(pool) do
            local key=c.team..":"..c.id
            if not used[key] then used[key]=true return c end
        end
        return nil
    end
    local roster={commander=pick(),left=pick(),right=pick(),members={}}
    if not roster.commander then
        -- 池子全空的兜底：用第一支可用队伍的司令
        local pid=Registry.default_player()
        roster.commander={team=pid,id=tonumber((Registry.load(pid).team or {}).commander) or 0}
    end
    for _=1,6 do
        local m=pick()
        if m then roster.members[#roster.members+1]=m end
    end
    return roster
end

return R
