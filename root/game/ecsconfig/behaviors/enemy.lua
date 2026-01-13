---@class game.behavior.Enemy: game.behavior.Base
---@overload fun():game.behavior.Enemy
local Enemy = batteries.class {
    name = "game.behavior.Enemy",
    extends = require("game.ecsconfig.behaviors.base")
}

function Enemy:init(ent, game)
    self.__super.init(self, ent, game)

    ent.actor.move_x = 1
end

function Enemy:tick()
    local ent = self.entity

    local actor = ent.actor
    if actor.touched_wall then
        actor.move_x = -actor.move_x
    end
end

function Enemy:msg_attacked()
    self.entity:destroy()
end

return Enemy