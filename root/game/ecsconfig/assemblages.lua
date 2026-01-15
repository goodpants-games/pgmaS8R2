local bit = require("bit")
local consts = require("game.consts")
local GameUtil = require("game.util")

local asm = {}
asm.entity = {}

function asm.actor(e, x, y, w, h)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", w, h)
     :give("actor")
     :give("damping")
     :give("mass", 1.0)

    e.collision.group = consts.COLGROUP_ACTOR
    e.collision.mask = consts.COLGROUP_DEFAULT
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.ice_block(e, game, x, y)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", 8.0, 8.0)
     :give("mass", 2.0)
     :give("damping", 0.9)
     :give("sprite", game.res:get_image("res/graphics/game/ice_block.png"))
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.spring(e, game, x, y)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", 8.0, 8.0)
     :give("mass", 2.0)
     :give("damping", 0.9)
     :give("spring", 3.0)
     :give("sprite", game.res:get_image("res/graphics/game/spring.png"))
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.player(e, game, x, y)
    e:assemble(asm.actor, x, y, 6, 8)
     :give("player_control")
     :give("mana", 100)
     :give("sprite", game.res:new_sprite("player"))
     :give("touch_monitor")
     :give("behavior", "player")
    
    e.sprite.ox = -1
    e.sprite.oy = -2
    e.collision.group = bit.bor(e.collision.group, consts.COLGROUP_PLAYER)

    game.player = e
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.water_tank(e, game, x, y)
    e:give("position", x, y)
     :give("collision", 8.0, 8.0)
     :give("sprite", game.res:new_sprite("water_tank"))
     :give("behavior", "water_tank")
    
    e.collision.monitor_only = true
    e.sprite.oy = -9
    e.sprite.z_index = -100
end

function asm.entity.enemy(e, game, x, y)
    e:assemble(asm.actor, x, y, 6, 8)
     :give("sprite")
     :give("behavior", "enemy")
     :give("touch_monitor")
    
    e.actor.move_speed = GameUtil.accel_damp_at_speed(0.5, 0.8)
end

return asm