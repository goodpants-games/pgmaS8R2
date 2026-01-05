local Room = require("game.room")
local Sprite = require("sprite")
local Concord = require("concord")
local fontres = require("fontres")

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
---@field player any
---@overload fun():game.Game
local Game = batteries.class({ name = "game.Game" })

function Game:new()
    self.res = ResourceManager()

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.behavior,
        ecsconfig.systems.actor,
        ecsconfig.systems.physics,
        ecsconfig.systems.render)

    -- px/ticks^2
    self.gravity = 0.1

    self.cam = {
        x = 0.0,
        y = 0.0
    }

    self.room = Room(self)

    if not self.player then
        self.player =
            self:new_entity()
            :assemble(ecsconfig.asm.entity.player, self, 12.0, 12.0)
    end
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
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
    Debug.draw:push()
    Debug.draw:scale(2.0, 2.0)
    Debug.draw:translate(-cam_x, -cam_y)

    self.ecs_world:emit("update", dt)

    Debug.draw:pop()
end

function Game:tick()
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
    Debug.draw:push()
    Debug.draw:scale(2.0, 2.0)
    Debug.draw:translate(-cam_x, -cam_y)

    self.ecs_world:emit("tick")
    self.cam.x = math.floor(self.player.position.x / 120) * 120 + DISPLAY_WIDTH / 2.0
    self.cam.y = math.floor(self.player.position.y / 88) * 88 + DISPLAY_HEIGHT / 2.0

    Debug.draw:pop()
end

function Game:draw()
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)

    Lg.push()
    Lg.translate(-cam_x, -cam_y)

    Debug.draw:push()
    Debug.draw:translate(-cam_x, -cam_y)

    self.room:draw()
    self.ecs_world:emit("draw")

    Lg.pop()
    Debug.draw:pop()

    self:_draw_ui()
end

---@private
function Game:_draw_ui()
    -- local mana_percent = self.player.mana.value / self.player.mana.max
    -- Lg.setColor(1, 0, 0)
    -- Lg.rectangle("fill", 0, 0, math.round(DISPLAY_WIDTH * mana_percent), 1)

    Lg.push()
    Lg.translate(0, math.floor(DISPLAY_HEIGHT) - 5)

    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, 5)
    Lg.setColor(P8_PAL.white)
    Lg.setFont(fontres.quinque)
    Lg.print(("WTR:%i"):format(self.player.mana.value), 0, -1)

    Lg.pop()
end

return Game