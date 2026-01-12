---@class game.behavior.Enemy: game.behavior.Base
---@overload fun():game.behavior.Enemy
local Enemy = batteries.class {
    name = "game.behavior.Enemy",
    extends = require("game.ecsconfig.behaviors.base")
}

function Enemy:tick()
    local ent = self.entity

    local actor = ent.actor
    actor.move_x = -1
end

return Enemy