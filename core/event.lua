-- Simple event bus for decoupled system communication
local Event = {}

function Event.new()
    local self = { listeners = {} }
    setmetatable(self, {__index = Event})
    return self
end

function Event:on(name, fn)
    if not self.listeners[name] then
        self.listeners[name] = {}
    end
    table.insert(self.listeners[name], fn)
end

function Event:emit(name, ...)
    local fns = self.listeners[name]
    if not fns then return end
    for _, fn in ipairs(fns) do
        fn(...)
    end
end

function Event:clear()
    self.listeners = {}
end

return Event
