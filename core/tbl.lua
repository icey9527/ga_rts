-- TBL config file parser (INI-like format)
-- Supports: [sections], key = value, quoted strings, arrays, ;/# comments.
local TBL = {}

local function trim(v)
    return (v or ""):match("^%s*(.-)%s*$")
end

local function strip_inline_comment(v)
    local in_quote = false
    for i = 1, #v do
        local c = v:sub(i, i)
        if c == '"' then
            in_quote = not in_quote
        elseif not in_quote and (c == ";" or c == "#") then
            return trim(v:sub(1, i - 1))
        end
    end
    return trim(v)
end

local function parse_value(v)
    v = v:match("^%s*(.-)%s*$") -- trim
    if v == "true" then return true end
    if v == "false" then return false end
    local quoted = v:match('^"(.*)"$')
    if quoted ~= nil then return quoted end
    quoted = v:match("^'(.*)'$")
    if quoted ~= nil then return quoted end
    local n = tonumber(v)
    if n then return n end
    return v
end

function TBL.parse_file(path)
    local f, err = love.filesystem.read(path)
    if not f then return nil, err end
    return TBL.parse(f)
end

function TBL.parse(content)
    local result = {}
    local current = result
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        -- skip empty lines and comments
        if line == "" or line:sub(1,1) == ";" or line:sub(1,1) == "#" then
            goto continue
        end

        -- section header
        local section = line:match("^%[(.+)%]$")
        if section then
            current = {}
            result[section] = current
            goto continue
        end

        -- key = value
        local key, val = line:match("^([^=]+)=(.*)$")
        if key then
            key = key:match("^%s*(.-)%s*$")
            val = strip_inline_comment(val)
            -- handle arrays: key = {a, b, c}
            local array = val:match("^%s*%{(.+)%}%s*$")
            if array then
                local arr = {}
                for item in array:gmatch("[^,]+") do
                    table.insert(arr, parse_value(item))
                end
                if key:lower():find("color", 1, true) then
                    for i, n in ipairs(arr) do
                        if type(n) == "number" and n > 1 then
                            arr[i] = n / 255
                        end
                    end
                end
                current[key] = arr
            else
                current[key] = parse_value(val)
            end
        end

        ::continue::
    end

    return result
end

function TBL.serialize(data)
    local lines = {}
    for section, values in pairs(data or {}) do
        if type(values) == "table" then
            table.insert(lines, "[" .. tostring(section) .. "]")
            for key, value in pairs(values) do
                if type(value) == "string" then
                    local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"')
                    table.insert(lines, tostring(key) .. ' = "' .. escaped .. '"')
                elseif type(value) == "number" or type(value) == "boolean" then
                    table.insert(lines, tostring(key) .. " = " .. tostring(value))
                end
            end
            table.insert(lines, "")
        end
    end
    return table.concat(lines, "\n")
end

return TBL
