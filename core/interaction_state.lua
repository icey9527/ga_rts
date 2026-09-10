local State={}

function State.new()
    return {command_pause_before=nil,mode="normal",action=nil,hover=nil,pending={},selection_start=nil,selection_rect=nil,dragging=false}
end

function State.pause_for_command(s,game)
    if s.command_pause_before==nil then s.command_pause_before=game:is_paused() end
    game:pause()
end

function State.restore_command_pause(s,game)
    if s.command_pause_before~=nil then game.paused=s.command_pause_before;s.command_pause_before=nil end
end

function State.reset(s,game,camera,context_menu,global_menu,controller)
    s.command_pause_before=nil;s.mode="normal";s.action=nil;s.hover=nil;s.pending={}
    s.selection_start=nil;s.selection_rect=nil;s.dragging=false
    if controller then controller:reset() end
    if context_menu then context_menu:hide() end
    if global_menu then global_menu:hide() end
    camera:enable_edge_scroll(false)
end

return State
