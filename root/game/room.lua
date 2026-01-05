---@class game.Room: batteries.Class
---@field tiled_obj_layer pklove.tiled.ObjectLayer?
---@overload fun(game:game.Game, map_path:string, tex_load_cb:nil|fun(path:string):love.Image):game.Room
local Room = batteries.class({ name = "game.Room" })
local Tiled = require("tiled")
local consts = require("game.consts")
local ecsconfig = require("game.ecsconfig")

---@param game game.Game
---@param map_path string
---@param tex_load_cb nil|fun(path:string):love.Image
function Room:new(game, map_path, tex_load_cb)
    self.tiled = Tiled.loadMap(map_path, {
        loadTexture = tex_load_cb
    })

    assert(self.tiled.tilewidth == consts.TILE_WIDTH)
    assert(self.tiled.tileheight == consts.TILE_HEIGHT)

    local col_layer = self.tiled.layers[1] --[[@as pklove.tiled.TileLayer]]
    local w = self.tiled.width
    local h = self.tiled.height

    self.width = w
    self.height = h
    self.col_map = {}

    local i=1
    for y=0, h-1 do
        for x=0, w-1 do
            local v = col_layer:get(x, y)
            if v > 0 then
                self.col_map[i] = 1
            else
                self.col_map[i] = 0
            end
            i=i+1
        end
    end

    for _, layer in ipairs(self.tiled.layers) do
        if layer.type == "objectgroup" then
            self.tiled_obj_layer = layer --[[@as pklove.tiled.ObjectLayer]]
            break
        end
    end

    if self.tiled_obj_layer then
        for _, obj in ipairs(self.tiled_obj_layer.objects) do
            if obj.type == "entity" then
                assert(obj.shape == "rectangle", "entity object is not a rect")

                if obj.name == "player" then
                    goto continue
                end

                local x = math.round(obj.x + obj.width / 2.0)
                local y = math.round(obj.y + obj.height / 2.0)

                game:new_entity()
                    :assemble(ecsconfig.asm.entity[obj.name], game, x, y)
            end

            ::continue::
        end
    else
        print("no objects")
    end
end

function Room:release()
    self.tiled:release()
end

---@param x integer
---@param y integer
function Room:get_col(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return 0
    end
    return self.col_map[y * self.width + x + 1]
end

function Room:draw()
    self.tiled.layers[1]:draw()
end

return Room