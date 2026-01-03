local consts = require("game.consts")
local bit = require("bit")

local asm = {}
asm.entity = {}

function asm.actor(e, x, y, w, h)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", w, h)
     :give("actor")

    e.collision.group = consts.COLGROUP_ACTOR
end

function asm.pushable_block(e, x, y)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", 16.0, 16.0)
end

function asm.entity.player(e, x, y)
    e:assemble(asm.actor, x, y, 12, 16)
     :give("player_control")
     :give("mana", 10)
    
    e.collision.group = bit.bor(e.collision.group, consts.COLGROUP_PLAYER)
end

return asm