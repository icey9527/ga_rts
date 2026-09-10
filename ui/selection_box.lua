local Box={}
function Box.draw(rect)
    if not rect then return end
    love.graphics.setColor(0.2,0.8,0.2,0.25);love.graphics.rectangle("fill",rect.x,rect.y,rect.w,rect.h)
    love.graphics.setColor(0.3,1,0.3,0.6);love.graphics.rectangle("line",rect.x,rect.y,rect.w,rect.h)
    love.graphics.setColor(1,1,1,1)
end
return Box
