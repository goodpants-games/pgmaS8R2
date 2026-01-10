---@class game.behavior.BuilderDroplet: game.behavior.Base
local BuilderDroplet = batteries.class {
    name = "game.behavior.BuilderDroplet",
    extends = require("game.ecsconfig.behaviors.base")
}

local consts = require("game.consts")
local TILE_SIZE = consts.TILE_SIZE

---@param target_y number
function BuilderDroplet:new(target_y)
    self:super()
    
    if not target_y then
        error("must provide target y position to droplet when constructing!")
    end

    self.target_y = math.floor(target_y / TILE_SIZE) * TILE_SIZE + 1
end

function BuilderDroplet:tick()
    local game = self.game
    local ent = self.entity

    local position = assert(ent.position, "droplet has no position")
    local velocity = assert(ent.velocity, "droplet has no velocity")

    if velocity.y > 0 and position.y >= self.target_y then
        print("droplet is done")

        local x_snap = TILE_SIZE / 2.0

        local platform =
            game:new_entity()
                :give("position",
                      math.floor((position.x) / x_snap) * x_snap + 4.0,
                      math.floor(self.target_y))
                :give("collision", 6, 2)
                :give("sprite")
                :give("remove_on_checkpoint")
        platform.collision.floor_only = true

        -- TODO: make platform have sprite
        platform.sprite.r, platform.sprite.g, platform.sprite.b =
            unpack(P8_PAL.white)

        ent:destroy()
    end
end

return BuilderDroplet
