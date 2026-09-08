-- 通讯槽位：每个后勤/教官槽位持有独立 FIFO 队列，逐条显示，互不抢占。
-- 槽位记录同时保留 text/kind/age/life 字段，现有绘制代码无需感知队列。
local Slots={}
function Slots.new(unit,life)
    return {unit=unit,age=0,life=0,text="",kind="idle",queue={},default_life=life or 8}
end
-- 入队：槽位空闲则立即显示，否则排队等待。
function Slots.say(slot,text,kind,life)
    if not slot then return end
    local item={text=text,kind=kind or "idle",life=life or slot.default_life or 8}
    if not slot.life or slot.life<=0 or slot.text=="" then
        slot.text,slot.kind,slot.age,slot.life=item.text,item.kind,0,item.life
    else
        slot.queue[#slot.queue+1]=item
    end
end
-- 覆盖式发言：清空队列立即显示，供教学步骤等必须立刻生效的场景使用。
function Slots.replace(slot,text,kind,life)
    if not slot then return end
    slot.queue={}
    slot.text,slot.kind,slot.age,slot.life=text,kind or "idle",0,life or slot.default_life or 8
end
function Slots.update(slot,dt)
    if not slot then return end
    slot.age=slot.age+dt
    slot.life=slot.life-dt
    if slot.life<=0 and #slot.queue>0 then
        local item=table.remove(slot.queue,1)
        slot.text,slot.kind,slot.age,slot.life=item.text,item.kind,0,item.life
    end
end
function Slots.clear(slot)
    if not slot then return end
    slot.queue={}
    slot.text=""
    slot.life=0
end
return Slots
