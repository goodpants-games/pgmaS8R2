---@class game.behavior.Enemy: game.behavior.Base
---@overload fun():game.behavior.Enemy
local Enemy = batteries.class {
    name = "game.behavior.Enemy",
    extends = require("game.ecsconfig.behaviors.base")
}

local GameUtil = require("game.util")

function Enemy:new()
    self:super()
    self.dead = false
end

function Enemy:init(ent, game)
    self.__super.init(self, ent, game)

    if ent.actor then
        ent.actor.move_x = 1
    end
end

function Enemy:tick()
    local ent = self.entity

    if self.dead then
        if ent.velocity.y > 3.0 then
            ent:destroy()
            return
        end
    else
        local actor = ent.actor
        if actor and actor.touched_wall then
            actor.move_x = -actor.move_x
        end
    end
end

function Enemy:touch_began(ent2)
    local ent = self.entity
    local actor = ent.actor

    if ent2 then
        local damp = 1.0
        if ent.damping then
            damp = ent.damping.x
        end

        local max_speed = 1.0
        if damp >= 0.0 and damp < 1.0 then
            max_speed = GameUtil.accel_damp_limit(actor.move_speed, damp)
        end

        GameUtil.send_message(ent2, "attacked", actor.move_x * max_speed, 0.0)
    end
end

function Enemy:msg_attacked(from, x, y)
    local ent = self.entity

    ent.velocity.x = math.binsign(x) * 0.25
    ent.velocity.y = -0.8

    ent:remove("actor")
       :give("gmult", 0.6)
       :remove("damping")
    ent.collision.enabled = false

    self.dead = true
end

return Enemy