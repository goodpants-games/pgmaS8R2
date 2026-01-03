local consts = require("game.consts")
local bit = require("bit")

local asm = {}
asm.entity = {}

function asm.actor(e, x, y, w, h, spr)
    e:give("position", x, y)
     :give("velocity")
     :give("collision", w, h)
     :give("actor")

    e.collision.group = consts.COLGROUP_ACTOR
    
    if spr then
        e:give("sprite", spr)
    end
end

function asm.entity.player(e, x, y, spr)
    e:assemble(asm.actor, x, y, 6, 8, spr)
     :give("player_control")
     :give("mana", 10)
    
    e.collision.group = bit.bor(e.collision.group, consts.COLGROUP_PLAYER)
end

return asm