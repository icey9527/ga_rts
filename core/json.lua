-- Minimal JSON encoder/decoder. The decoder is intentionally defensive:
-- malformed save files return nil instead of locking the Love2D main thread.
local JSON = {}

local function encode_string(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
end

function JSON.encode(obj)
    if type(obj) == "table" then
        local parts = {}
        local is_array = true
        local max_idx = 0
        for k in pairs(obj) do
            if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then is_array = false; break end
            if k > max_idx then max_idx = k end
        end
        if is_array and max_idx == #obj then
            for i, v in ipairs(obj) do
                table.insert(parts, JSON.encode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end

        for k, v in pairs(obj) do
            table.insert(parts, encode_string(tostring(k)) .. ":" .. JSON.encode(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(obj) == "string" then
        return encode_string(obj)
    elseif type(obj) == "number" then
        return tostring(obj)
    elseif type(obj) == "boolean" then
        return obj and "true" or "false"
    else
        return "null"
    end
end

function JSON.decode(str)
    if type(str) ~= "string" then return nil, "expected string" end
    local idx = 1
    local len = #str

    local function fail(msg)
        return nil, msg .. " at byte " .. idx
    end

    local function skip()
        while idx <= len do
            local c = str:sub(idx, idx)
            if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then return end
            idx = idx + 1
        end
    end

    local parse_value

    local function parse_string()
        if str:sub(idx, idx) ~= '"' then return fail("expected string") end
        idx = idx + 1
        local out = {}
        while idx <= len do
            local c = str:sub(idx, idx)
            if c == '"' then
                idx = idx + 1
                return table.concat(out)
            elseif c == "\\" then
                idx = idx + 1
                if idx > len then return fail("unterminated escape") end
                local e = str:sub(idx, idx)
                local map = {['"']='"', ["\\"]="\\", ["/"]="/", b="\b", f="\f", n="\n", r="\r", t="\t"}
                table.insert(out, map[e] or e)
            else
                table.insert(out, c)
            end
            idx = idx + 1
        end
        return fail("unterminated string")
    end

    local function parse_number()
        local start = idx
        while idx <= len and str:sub(idx, idx):match("[%d%.%+%-eE]") do
            idx = idx + 1
        end
        if idx == start then return fail("expected number") end
        local n = tonumber(str:sub(start, idx - 1))
        if n == nil then return fail("invalid number") end
        return n
    end

    local function parse_literal(word, value)
        if str:sub(idx, idx + #word - 1) ~= word then
            return fail("expected " .. word)
        end
        idx = idx + #word
        return value
    end

    local function parse_array()
        idx = idx + 1
        local arr = {}
        skip()
        if str:sub(idx, idx) == "]" then idx = idx + 1; return arr end
        while idx <= len do
            local value, err = parse_value()
            if err then return nil, err end
            table.insert(arr, value)
            skip()
            local c = str:sub(idx, idx)
            if c == "]" then idx = idx + 1; return arr end
            if c ~= "," then return fail("expected ',' or ']'") end
            idx = idx + 1
        end
        return fail("unterminated array")
    end

    local function parse_object()
        idx = idx + 1
        local obj = {}
        skip()
        if str:sub(idx, idx) == "}" then idx = idx + 1; return obj end
        while idx <= len do
            skip()
            local key, key_err = parse_string()
            if key_err then return nil, key_err end
            skip()
            if str:sub(idx, idx) ~= ":" then return fail("expected ':'") end
            idx = idx + 1
            local value, value_err = parse_value()
            if value_err then return nil, value_err end
            obj[key] = value
            skip()
            local c = str:sub(idx, idx)
            if c == "}" then idx = idx + 1; return obj end
            if c ~= "," then return fail("expected ',' or '}'") end
            idx = idx + 1
        end
        return fail("unterminated object")
    end

    function parse_value()
        skip()
        if idx > len then return fail("unexpected end") end
        local c = str:sub(idx, idx)
        if c == '"' then return parse_string() end
        if c == "{" then return parse_object() end
        if c == "[" then return parse_array() end
        if c == "t" then return parse_literal("true", true) end
        if c == "f" then return parse_literal("false", false) end
        if c == "n" then return parse_literal("null", nil) end
        return parse_number()
    end

    local value, err = parse_value()
    if err then return nil, err end
    skip()
    if idx <= len then return fail("trailing data") end
    return value
end

return JSON
