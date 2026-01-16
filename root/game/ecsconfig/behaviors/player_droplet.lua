---@class game.behavior.PlayerDroplet: game.behavior.Base
local PlayerDroplet = batteries.class {
    name = "game.behavior.PlayerDroplet",
    extends = require("game.ecsconfig.behaviors.base")
}

local consts = require("game.consts")
local GameUtil = require("game.util")
local TILE_SIZE = consts.TILE_SIZE
local DROPLET_TYPES = {"side_platform", "up_platform", "bullet"}

---@param droplet_type "side_platform"|"up_platform"|"bullet"
function PlayerDroplet:new(droplet_type)
    self:super()

    if table.index_of(DROPLET_TYPES, droplet_type) then
        self.droplet_type = droplet_type
        self.is_platform = droplet_type == "up_platform"
                        or droplet_type == "side_platform"

        if droplet_type == "bullet" then
            self.life = 60
        end
    else
        softerror("invalid droplet type!")
    end
end

function PlayerDroplet:init(ent, game)
    self.__super.init(self, ent, game)

    if (self.droplet_type == "side_platform" or self.droplet_type == "up_platform") and not self.target_y then
        local py = ent.position.y
        local target_y

        if self.droplet_type == "side_platform" then
            target_y = py + consts.PLAYER_SIDE_SPIT_TARGET_Y_OFF
        else
            target_y = py - 8
        end

        self.target_y = math.floor(target_y / TILE_SIZE) * TILE_SIZE + 1
    end
end

function PlayerDroplet:touch_began(ent2)
    if self.droplet_type == "bullet" then
        local ent1 = self.entity
        if ent2 and ent2.collision.monitor_only then return end
        if ent2 == self.game.player then return end

        if ent2 then
            GameUtil.send_message(ent2, "attacked", ent1, ent1.velocity.x, ent1.velocity.y)
        end

        if ent2 ~= self.game.player then
            self.entity:destroy()
        end
    end
end

function PlayerDroplet:tick()
    local game = self.game
    local ent = self.entity

    local position = assert(ent.position, "droplet has no position")
    local velocity = assert(ent.velocity, "droplet has no velocity")

    if self.droplet_type == "bullet" then
        self.life = self.life - 1
        if self.life <= 0 or ent.collision.in_water then
            ent:destroy()
            return
        end
    elseif self.is_platform then
        if velocity.y > 0 and position.y >= self.target_y then
            local tx = math.floor(position.x / TILE_SIZE)
            local ty = math.floor(position.y / TILE_SIZE)
            local col = game.room:get_col(tx, ty)
            if col == 2 then
                col = game.room:get_col(tx, ty - 1)
            end
            
            if col ~= 3 then
                local x_snap = TILE_SIZE / 2.0
                local offset = 0.0
                if self.droplet_type == "up_platform" then
                    offset = -0.5
                end

                local platform =
                    game:new_entity()
                        :give("position",
                            math.floor((position.x) / x_snap + offset) * x_snap + 4.0,
                            math.floor(self.target_y))
                        :give("collision", 6, 2)
                        :give("sprite")
                        :give("remove_on_checkpoint")
                platform.collision.floor_only = true

                -- TODO: make platform have sprite
                platform.sprite.r, platform.sprite.g, platform.sprite.b =
                    unpack(P8_PAL.white)
            end

            ent:destroy()
        end
    end
end

return PlayerDroplet
