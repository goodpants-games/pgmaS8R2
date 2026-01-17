local Base = require("game.ecsconfig.behaviors.base")

---@class game.behavior.FragileBlockBehavior: game.behavior.Base
local FragileBlockBehavior = batteries.class {
    name = "game.behavior.FragileBlockBehavior",
    extends = Base
}

---@param is_static boolean
function FragileBlockBehavior:new(is_static)
    self:super()
    self.is_static = is_static
end

function FragileBlockBehavior:init(ent, game, soft_init)
    Base.init(self, ent, game, soft_init)
    if soft_init then return end
end

function FragileBlockBehavior:tick()
    Base.tick(self)

    local ent = self.entity
    local sprite = ent.sprite.obj --[[@as pklove.Sprite]]
    local health = ent.health.value

    local frame_base = self.is_static and 4 or 1
    sprite.cel = frame_base + 3 - health
end

function FragileBlockBehavior:msg_attacked()
    print("Attacked")
    local ent = self.entity
    local health = ent.health

    health.value = health.value - 1
    if health.value <= 0 then
        self.entity:destroy()
    end
end

return FragileBlockBehavior