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
    Mark_perf_heavy_frame()

    self.tiled = Tiled.loadMap(map_path, {
        loadTexture = tex_load_cb
    })

    assert(self.tiled.tilewidth == consts.TILE_SIZE)
    assert(self.tiled.tileheight == consts.TILE_SIZE)

    local sky_bg = false
    if self.tiled.properties then
        sky_bg = not not self.tiled.properties.sky_bg
    end

    local col_layer = self.tiled.layers[1] --[[@as pklove.tiled.TileLayer]]
    local w = self.tiled.width
    local h = self.tiled.height

    self.sky_bg = sky_bg
    self.width = w
    self.height = h
    self.col_map = {}

    local base_tileset ---@type pklove.tiled.Tileset
    for _, tileset in ipairs(self.tiled.tilesets) do
        if tileset.name == "tileset" then
            base_tileset = tileset
            break
        end
    end

    if not base_tileset then
        error(("level '%s' does not use base tileset!"):format(map_path))
    end

    local tile_info = {}
    for _, v in ipairs(base_tileset.tiles) do
        tile_info[v.id + 1] = v
    end

    local i=1
    for y=0, h-1 do
        for x=0, w-1 do
            local v = col_layer:get(x, y)
            local col_id = 0

            if v and v > 0 then
                local ginfo = self.tiled:getTileInfo(v)
                assert(self.tiled.tilesets[ginfo.tilesetId] == base_tileset,
                       "tile in collision layer does not use base tileset!")

                local tinfo = tile_info[ginfo.id]
                col_id = 1
                if tinfo then
                    if tinfo.type == "water" then
                        col_id = 2
                    elseif tinfo.type == "heat" then
                        col_id = 3
                    elseif tinfo.type == "decor" then
                        col_id = 0
                    end
                end
            end

            if sky_bg then
                if col_id == 3 then
                    col_id = 0
                elseif col_id == 0 then
                    col_id = 3
                end
            end

            self.col_map[i] = col_id
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
                    :assemble(ecsconfig.asm.entity[obj.name], game, x, y,
                              obj.properties or {})
                    :give("gid", map_path, obj.id)
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