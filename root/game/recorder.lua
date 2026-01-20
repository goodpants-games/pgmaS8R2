---@class game.Recorder: batteries.Class
---@overload fun(game:game.Game):game.Recorder
local Recorder = batteries.class {
    name = "game.Recorder"
}

local Sprite = require("sprite")

---@param room_name string
---@param map pklove.tiled.Map
local function export_room(room_name, map)
    local canvas = Lg.newCanvas(960, 720, { dpiscale = 1.0 })

    local layer = map.layers[1] --[[@as pklove.tiled.TileLayer]]
    Lg.push("all")
    Lg.setCanvas(canvas)
    Lg.clear(P8_PAL.black)
    layer:draw()
    Lg.pop()

    local img = canvas:newImageData()
    local png_dat = img:encode("png")

    local file_name = ("ignore/maps/room %s.png"):format(room_name)
    local f, err = io.open(file_name, "wb")
    if not f then
        error(("could not open '%s': %s"):format(file_name, err))
    end

    f:write(png_dat:getString())

    f:close()
    png_dat:release()
    img:release()


    -- local scr_cols = 960 / 64
    -- -- assert(scr_cols % 1 == 0)
    -- local scr_rows = 720 / 64
    -- -- assert(scr_rows % 1 == 0)

    -- local layer = map.layers[1] --[[@as pklove.tiled.TileLayer]]
    -- for y=0, math.ceil(map.height / scr_rows) - 1 do
    --     for x=0, math.ceil(map.width / scr_cols) - 1 do
    --         Lg.push("all")
    --         Lg.setCanvas(canvas)
    --         Lg.clear(P8_PAL.black)
    --         Lg.scale(8, 8)
    --         Lg.translate(math.floor(-x * scr_cols * 8), math.floor(-y * scr_rows * 8))
    --         layer:draw()
    --         Lg.pop()

    --         local img = canvas:newImageData()
    --         local png_dat = img:encode("png")

    --         local file_name = ("ignore/maps/room %s %i %i.png"):format(room_name, x, y)
    --         local f, err = io.open(file_name, "wb")
    --         if not f then
    --             error(("could not open '%s': %s"):format(file_name, err))
    --         end

    --         f:write(png_dat:getString())

    --         f:close()
    --         png_dat:release()
    --         img:release()
    --     end
    -- end

    canvas:release()
end

---@param game game.Game
function Recorder:new(game)
    self.game = game
    ---@type (string|number)[]
    self.data = {}

    ---@type {[any]:string}
    self.res_lookup = {}

    local room_name = string.match(game.room_name, "^maps/(.+).tmx$")
    room_name = string.gsub(room_name, "/", " ")

    table.insert(self.data, room_name)

    export_room(room_name, game.room.tiled)
end

---@param path string
function Recorder:finish(path)
    print("done!")

    local file, err = io.open(path, "w")
    if not file then
        error(("could not open %s: %s"):format(path, err))
    end

    for _, line in ipairs(self.data) do
        file:write(line, "\n")
    end

    file:write("END")

    file:close()
end

function Recorder:capture()
    local tinsert = table.insert

    tinsert(self.data, "NF")
    tinsert(self.data, math.round(self.game.cam.x))
    tinsert(self.data, math.round(self.game.cam.y))

    self.game.ecs_world:__flush()
    for _, ent in ipairs(self.game.ecs_world:getEntities()) do
        local pos = ent.position
        local spr = ent.sprite

        if not (pos and spr) then
            goto continue
        end

        local draw = spr.obj
        local is_sprite = false
        local is_img = false

        if draw then
            if Sprite.isSprite(draw) then
                is_sprite = true
            elseif type(draw) == "userdata" and draw.typeOf and draw:typeOf("Texture") then
                is_img = true
            end
        end
        
        if not (is_sprite or is_img or ent.collision) then
            goto continue
        end

        tinsert(self.data, "E")
        tinsert(self.data, math.round(pos.x + spr.ox))
        tinsert(self.data, math.round(pos.y + spr.oy))
        tinsert(self.data, math.binsign(spr.sx))
        tinsert(self.data, math.binsign(spr.sy))

        if is_sprite then
            ---@cast draw pklove.Sprite
            tinsert(self.data, "s")
            
            local res_name = self.res_lookup[draw.res]
            if not res_name then
                for k, v in pairs(self.game.res.cache) do
                    if draw.res == v then
                        res_name = k
                    end
                end

                if res_name then
                    res_name = string.match(res_name, "res/sprites/(.+)%.json")
                end

                assert(res_name, "could not look up name of SpriteResource")
                print(res_name)
                self.res_lookup[draw.res] = res_name
            end

            tinsert(self.data, res_name)
            tinsert(self.data, draw.cel)
        elseif is_img then
            ---@cast draw love.Texture
            tinsert(self.data, "i")

            local res_name = self.res_lookup[draw]
            if not res_name then
                for k, v in pairs(self.game.res.cache) do
                    if draw == v then
                        res_name = k
                    end
                end

                if res_name then
                    res_name = string.match(res_name, "res/graphics/(.+)%.png")
                end

                assert(res_name, "could not look up name of Texture")
                res_name = string.gsub(res_name, "/", " ")

                print(res_name)
                self.res_lookup[draw] = res_name
            end

            tinsert(self.data, res_name)
        else
            tinsert(self.data, "r")
            tinsert(self.data, math.round(ent.collision.w))
            tinsert(self.data, math.round(ent.collision.h))
        end
        ::continue::
    end
end

return Recorder