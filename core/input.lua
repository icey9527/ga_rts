local Input={}
function Input.screen_to_extended_world(camera,mx,my)
    local w,h=love.graphics.getWidth(),love.graphics.getHeight()
    local sx=math.max(0,math.min(w,mx));local sy=math.max(0,math.min(h,my))
    return camera:screen_to_world(sx,sy)
end
return Input
