local palette_img = love.image.newImageData(512, 512)

local oklab_p8_pal = {}
for i=1, #P8_PAL do
    local rgb_col = P8_PAL[i]
    local l, a, b = batteries.colour.rgb_to_oklab(rgb_col[1], rgb_col[2], rgb_col[3])
    oklab_p8_pal[i] = {l, a, b}
end

for ri=0, 255 do
    for gi=0, 255 do
        for bi=0, 255 do
            local r = ri / 255
            local g = gi / 255
            local b = bi / 255
            local ok_l, ok_a, ok_b = batteries.colour.rgb_to_oklab(r, g, b)

            local cell = math.floor(b * 63)
            local cx = cell % 8
            local cy = math.floor(cell / 8)

            local x = r * 64 + cx * 64
            local y = g * 64 + cy * 64
            x = math.floor(x / 512 * 511)
            y = math.floor(y / 512 * 511)

            local min_dist = math.huge
            local final_color_idx
            for i=1, #oklab_p8_pal do
                local col = oklab_p8_pal[i]
                local dl = col[1] - ok_l
                local da = col[2] - ok_a
                local db = col[3] - ok_b
                local dist = dl*dl + da*da + db*db

                if dist < min_dist then
                    min_dist = dist
                    final_color_idx = i
                end
            end

            local write_col = P8_PAL[final_color_idx]
            palette_img:setPixel(x, y, write_col[1], write_col[2], write_col[3])
        end
    end
end

local file_data = palette_img:encode("png")
local file = assert(io.open(love.filesystem.getSource() .. "/res/pico8_palette_map.png", "wb"))
file:write(file_data:getString())
file:close()