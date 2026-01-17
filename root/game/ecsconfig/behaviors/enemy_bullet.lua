local Base = require("game.ecsconfig.behaviors.base")
local bit = require("bit")

local GameUtil = require("game.util")
local const = require("game.consts")

---@class game.behavior.EnemyBullet: game.behavior.Base
local EnemyBullet = batteries.class {
    name = "game.behavior.EnemyBullet",
    extends = Base
}

function EnemyBullet:new(source_entity)
    self:super()
    self.life = 120
    self.source_entity = assert(source_entity.key, "ent has no key").value
end

function EnemyBullet:tick()
    Base.tick(self)

    if self.life == 0 then
        self.entity:destroy()
    else
        self.life = self.life - 1
    end
end

function EnemyBullet:touch_began(ent2)
    local ent1 = self.entity

    -- only ignore if it's an entity.
    -- don't ignore if it's the player.
    -- ignore if collision is marked as monitor only
    -- ignore if it's considered an actor.
    if ent2 and (ent2 ~= self.game.player and (ent2.collision.monitor_only or
       bit.band(ent2.collision.group, const.COLGROUP_ACTOR) ~= 0))
    then
        return
    end

    if ent2 then
        GameUtil.send_message(ent2, "attacked", ent1, ent1.velocity.x, ent1.velocity.y)
    end

    self.entity:destroy()
end

return EnemyBullet