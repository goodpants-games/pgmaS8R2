---@class game.Room: batteries.Class
---@overload fun():game.Room
local Room = batteries.class({ name = "game.Room" })
local Tiled = require("tiled")
local consts = require("game.consts")

function Room:new()
    self.tiled = Tiled.loadMap("res/maps/testmap.lua")
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