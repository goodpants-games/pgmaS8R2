---@class game.Room: batteries.Class
---@overload fun():game.Room
local Room = batteries.class({ name = "game.Room" })

local Tiled = require("tiled")

function Room:new()
    self.tiled = Tiled.loadMap("res/maps/testmap.lua")

    local col_layer = self.tiled.layers[1] --[[@as pklove.tiled.TileLayer]]
    local w = self.tiled.width
    local h = self.tiled.height

    self.width = w
    self.height = h
    self.col_map = {}
    for i=1, w * h do
        self.col_map[i] = col_layer.data[i] ~= 0
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