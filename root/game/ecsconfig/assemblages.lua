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

function asm.entity.crawler(e, game, x, y, props)
    e:assemble(asm.actor, x, y, 6, 8)
     :give("sprite")
     :give("behavior", "crawler", props)
     :give("touch_monitor")
     :give("health", 3)
    
    e.actor.move_speed = GameUtil.accel_damp_at_speed(0.5, 0.8)
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
---@param props {[string]:any}
function asm.entity.sign(e, game, x, y, props)
    e:give("position", x, y)
     :give("collision", 6, 8)
     :give("sprite", game.res:get_image("res/graphics/game/sign.png"))
     :give("dialogue", props.text)
     
    e.collision.monitor_only = true
    e.sprite.z_index = -100
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
local function init_orb(e, game, x, y)
    e:give("position", x, y)
     :give("collision", 4, 4)
     :give("touch_monitor")
     :give("sprite", game.res:new_sprite("fire_orb"))

    e.collision.monitor_only = true

    return e
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.red_orb(e, game, x, y)
    init_orb(e, game, x, y)
        :give("behavior", "fire_orb", "red")    
    e.sprite.obj:play("red")
end

---@param e any
---@param game game.Game
---@param x number
---@param y number
function asm.entity.blue_orb(e, game, x, y)
    init_orb(e, game, x, y)
        :give("behavior", "fire_orb", "blue")
    e.sprite.obj:play("blue")
end

return asm