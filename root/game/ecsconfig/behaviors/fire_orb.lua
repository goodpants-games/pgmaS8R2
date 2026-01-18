local Base = require("game.ecsconfig.behaviors.base")

---@class game.behavior.FireOrb: game.behavior.Base
---@overload fun(color:"red"|"blue"):game.behavior.FireOrb
local FireOrb = batteries.class {
    name = "game.behavior.FireOrb",
    extends = Base
}

---@param color "red"|"blue"
function FireOrb:new(color)
    self:super()
    self.color = color
end

function FireOrb:init(ent, game, soft_init)
    Base.init(self, ent, game, soft_init)
    
    local gid = self.entity:get("gid").v

    if game:is_orb_collected(gid) then
        self.entity:destroy()
    end
end

function FireOrb:touch_began(o_ent)
    local game = self.game
    if o_ent == game.player then
        print("fire orb collected")
        local gid = self.entity:get("gid").v

        game:collect_orb(gid, self.color)
        self.entity:destroy()

        self.game.dialogue:start("collect_fire_orb", self.color, game)
    end
end

function FireOrb:tick()
    local ent = self.entity
    local game = self.game
    local sprite = ent.sprite
    
    sprite.oy = math.round(math.sin(game.frame * math.pi * 2.0 / 120) * 2.0)
end

return FireOrb