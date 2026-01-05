-- TODO: find color distance formula that is more accurate to human perception
local palette_img = love.image.newImageData(256, 256)

for ri=0, 255 do
    for gi=0, 255 do
        for bi=0, 255 do
            local r = ri / 255
            local g = gi / 255
            local b = bi / 255

            local x = ri
            local y = g * 32 + math.floor(b * 7) * 32
            y = math.round(y / 256 * 255)

            local min_dist = math.huge
            local write_col
            for i=1, #P8_PAL do
                local col = P8_PAL[i]
                local dr = col[1] - r
                local dg = col[2] - g
                local db = col[3] - b
                local dist = dr*dr + dg*dg + db*db

                if dist < min_dist then
                    min_dist = dist
                    write_col = col
                end
            end

            palette_img:setPixel(x, y, write_col[1], write_col[2], write_col[3])
        end
    end
end

local file_data = palette_img:encode("png")
local file = assert(io.open(love.filesystem.getSource() .. "/res/pico8_palette_map.png", "wb"))
file:write(file_data:getString())
file:close()