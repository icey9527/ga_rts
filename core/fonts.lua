-- Shared font loading. Prefer the bundled Source Han Sans Medium font so Chinese text
-- renders consistently regardless of the user's Windows font configuration.
local Fonts = {
    cache = {},
    bundled_path = "assets/fonts/SourceHanSansCN-Medium.otf",
}

function Fonts.get(size)
    size = size or 14
    if Fonts.cache[size] then return Fonts.cache[size] end
    local font
    if love.filesystem.getInfo(Fonts.bundled_path) then
        local ok, loaded = pcall(love.graphics.newFont, Fonts.bundled_path, size)
        if ok and loaded then
            font = loaded
        end
    end
    font = font or love.graphics.newFont(size)
    Fonts.cache[size] = font
    return font
end

return Fonts
