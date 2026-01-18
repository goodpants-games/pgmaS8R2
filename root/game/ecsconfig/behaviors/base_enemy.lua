local Base = require("game.ecsconfig.behaviors.base")

---@class game.behavior.BaseEnemy: game.behavior.Base
---@overload fun(props:table):game.behavior.BaseEnemy
local BaseEnemy = batteries.class {
    name = "game.behavior.BaseEnemy",
    extends = Base
}

local GameUtil = require("game.util")
local consts = require("game.consts")

---@param props table
function BaseEnemy:new(props)
    props = props or {}

    self:super()
    self.dead = false
    self.max_dist = (props.max_dist or math.huge) * consts.TILE_SIZE
end

function BaseEnemy:init(ent, game, soft_init)
    Base.init(self, ent, game, soft_init)
    if soft_init then return end

    self.home = ent.position.x
end

function BaseEnemy:tick()
    local ent = self.entity

    if self.dead and ent.velocity.y > 3.0 then
        ent:destroy()
        return
    end
end

function BaseEnemy:touch_began(ent2)
    local ent = self.entity
    local actor = ent.actor

    if ent2 and ent2 == self.game.player then
        if actor then
            -- local damp = 1.0
            -- if ent.damping then
            --     damp = ent.damping.x
            -- end

            -- local max_speed = 1.0
            -- if damp >= 0.0 and damp < 1.0 then
            --     max_speed = GameUtil.accel_damp_limit(actor.move_speed, damp)
            -- end

            -- GameUtil.send_message(ent2, "attacked", ent, actor.face_dir * max_speed, 0.0)
            GameUtil.send_message(ent2, "attacked", ent, math.binsign(ent2.position.x - ent.position.x), 0.0)
        else
            GameUtil.send_message(ent2, "attacked", ent, 0.0, 0.0)
        end
    end
end

function BaseEnemy:msg_attacked(from, x, y)
    local ent = self.entity

    if ent.velocity then
        ent.velocity.x = 0.0
        ent.velocity.y = 0.0
    end

    if ent.health then
        ent.health.value = math.max(0, ent.health.value - 1)
        if ent.health.value <= 0 then
            ent:ensure("velocity")
            ent.velocity.x = math.binsign(x) * 0.25
            ent.velocity.y = -0.8

            ent:remove("actor")
               :give("gmult", 0.6)
               :remove("damping")
            ent.collision.enabled = false

            self.game.sound:play("enemy_hurt")
            self.dead = true     
        end
    end
end

return BaseEnemy