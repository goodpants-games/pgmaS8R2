local consts = require("game.consts")
local bit = require("bit")

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
     :give("sprite", game.res:get_image("res/graphics/game/water_tank.png"))
     :give("interactable")
     :give("behavior", "water_tank")
    e.collision.monitor_only = true
    e.sprite.oy = -4
    e.sprite.z_index = -100
end

return asm