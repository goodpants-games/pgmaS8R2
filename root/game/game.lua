local Room = require("game.room")
local Sprite = require("sprite")
local Concord = require("concord")

local ecsconfig = require("game.ecsconfig")

---@class game.ResourceManager: batteries.Class
---@overload fun():game.ResourceManager
local ResourceManager = batteries.class({ name = "game.ResourceManager" })

function ResourceManager:new()
    ---@type {[string]:pklove.SpriteResource|love.Image}
    self.cache = {}
end

function ResourceManager:clear()
    for _, v in pairs(self.cache) do
        v:release()
    end
    table.clear(self.cache)
end

---@param name string
---@return pklove.SpriteResource
function ResourceManager:get_sprite_res(name)
    local path = ("res/sprites/%s.json"):format(name)
    local res = self.cache[path]
    if not res then
        res = Sprite.loadResource(path)
        self.cache[path] = res
    end
    assert(Sprite.isSpriteResource(res), "not a SpriteResource")
    ---@cast res pklove.SpriteResource
    return res
end

---@param path string
---@return love.Image
function ResourceManager:get_image(path)
    local res = self.cache[path]
    if not res then
        res = Lg.newImage(path)
        self.cache[path] = res
    end
    assert(res.typeOf and res:typeOf("Image"), "not an Image")
    ---@cast res love.Image
    return res
end

function ResourceManager:new_sprite(name)
    local res = self:get_sprite_res(name)
    return Sprite.new(res)
end




---@class game.Game: batteries.Class
---@overload fun():game.Game
local Game = batteries.class({ name = "game.Game" })

function Game:new()
    self.room = Room()
    self.res = ResourceManager()

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(ecsconfig.systems.render)

    self.cam = {
        x = 0.0,
        y = 0.0
    }
end

function Game:release()
    self.room:release()
    self.res:clear()
end

function Game:new_entity()
    return Concord.entity(self.ecs_world)
end

---@param dt number
function Game:update(dt)
    self.ecs_world:emit("update", dt)
end

function Game:tick()
    self.ecs_world:emit("tick")
end

function Game:draw()
    local cam_x = math.round(self.cam.x)
    local cam_y = math.round(self.cam.y)

    Lg.push()
    Lg.translate(-cam_x, -cam_y)

    self.room:draw()
    self.ecs_world:emit("draw")

    Lg.pop()
end

return Game