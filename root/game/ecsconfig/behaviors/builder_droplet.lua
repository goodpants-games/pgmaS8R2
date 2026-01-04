---@class game.behavior.BuilderDroplet: game.behavior.Base
local BuilderDroplet = batteries.class {
    name = "game.behavior.BuilderDroplet",
    extends = require("game.ecsconfig.behaviors.base")
}

---@param target_y number
function BuilderDroplet:new(target_y)
    if not target_y then
        error("must provide target y position to droplet when constructing!")
    end

    self.target_y = target_y
end

function BuilderDroplet:tick()
    local game = self.game
    local ent = self.entity

    local position = assert(ent.position, "droplet has no position")
    local velocity = assert(ent.velocity, "droplet has no velocity")

    if velocity.y > 0 and position.y >= self.target_y then
        print("droplet is done")

        local platform =
            game:new_entity()
                :give("position",
                      math.round(position.x),
                      math.round(self.target_y))
                :give("collision", 8, 2)
                :give("sprite")
        platform.collision.floor_only = true

        ent:destroy()
    end
end

return BuilderDroplet
