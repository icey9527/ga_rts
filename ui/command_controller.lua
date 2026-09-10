local Controller={}
Controller.__index=Controller
function Controller:color(action,target,team)
    return require("ui.tactical_arrows").color(action,target,team)
end

function Controller.new()
    return setmetatable({feedbacks={},mode="normal",action=nil,pending={},follow_before=nil},Controller)
end

function Controller:reset()
    self.feedbacks={}
    self.mode="normal";self.action=nil;self.pending={};self.follow_before=nil
end

function Controller:begin(camera,selected,action)
    self.mode="targeting";self.action=action;self.pending={}
    for _,unit in ipairs(selected or {}) do
        if unit.alive and unit.state~="dead" then self.pending[#self.pending+1]=unit end
    end
    self.follow_before=camera.follow_target
    camera:stop_follow();camera:enable_edge_scroll(true)
    return self.pending
end

function Controller:cancel(camera)
    self.mode="normal";self.action=nil;self.pending={}
    camera:enable_edge_scroll(false)
    if self.follow_before and self.follow_before.alive then camera:set_follow(self.follow_before) end
    self.follow_before=nil
end

function Controller:execute(game,camera,action,pending,mx,my,forced_target,add_feedback,cancel)
    local Markers=require("ui.tactical_markers")
    local Orders=require("systems.orders")
    local wx,wy=camera:screen_to_world(mx,my)
    local target=forced_target or Markers.pick(game,camera,mx,my) or game:get_unit_at(wx,wy,nil,camera.zoom)
    if action=="skill_target" then
        local success=false
        for _,u in ipairs(pending or {}) do
            if target and target.alive and target.team~=u.team and not u.skill_pending then
                u.skill_target=target
                if u:use_skill(game) then success=true else u.skill_target=nil end
            end
        end
        if success then cancel() end
        return
    end
    if action=="repair_tool" then
        local success=false
        for _,u in ipairs(pending or {}) do
            if u.unit_type=="repair" and not u.skill_pending and target and target~=u and target.team==u.team then
                u.repair_target=target;u.skill_data={type="repair_tool",range=600}
                success=u:use_skill(game) or success
            end
        end
        if success then cancel() end
        return
    end
    if Orders.issue(game,pending,action,target,wx,wy)==0 then return end
    local visual=(action=="attack" and not target) and "move" or action
    local r,g,b=self.color(visual,target,game.player_team)
    for _,u in ipairs(pending or {}) do add_feedback(u,wx,wy,r,g,b) end
    cancel()
end

function Controller:update(dt)
    for i=#self.feedbacks,1,-1 do
        local item=self.feedbacks[i]
        item.life=item.life-dt
        if item.life<=0 then table.remove(self.feedbacks,i) end
    end
end

function Controller:add_feedback(unit,x,y,r,g,b,duration)
    duration=duration or 0.9
    self.feedbacks[#self.feedbacks+1]={
        x1=unit.x,y1=unit.y-(unit.z or 0)*0.22,x2=x,y2=y,
        r=r,g=g,b=b,life=duration,duration=duration,
    }
end

return Controller
