local View={}
function View.draw_projectiles(game)
    for _,p in ipairs(game.projectiles or {}) do if p.draw then p:draw() end end
end
function View.draw_effects(game)
    for _,e in ipairs(game.effects or {}) do if e.draw then e:draw() end end
end
function View.draw_units(game,renderer)
    local visible={}
    for _,u in ipairs(game.units or {}) do visible[#visible+1]=u end
    table.sort(visible,function(a,b) return ((a.y or 0)+(a.z or 0)*0.2)<((b.y or 0)+(b.z or 0)*0.2) end)
    for _,u in ipairs(visible) do if u.alive and u.state~="dead" then renderer.draw(u,game.player_team) end end
end
return View
