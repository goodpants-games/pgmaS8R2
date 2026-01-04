---@class game.behavior.Player: game.behavior.Base
---@overload fun():game.behavior.Player
local Player = batteries.class {
    name = "game.behavior.Player",
    extends = require("game.ecsconfig.behaviors.base")
}

function Player:new()
    self:super()
    self.is_spitting = false
end

function Player:init(ent, game)
    self.__super.init(self, ent, game)
    ent.sprite.obj:play("idle")
end

function Player:tick()
    local ent = self.entity
    local csprite = ent.sprite
    local control = ent.player_control
    local actor = ent.actor

    local sprite = csprite.obj --[[@as pklove.Sprite]]

    if control.did_spit then
        sprite:play("spit")
        ent.velocity.x = 0.0
        self.is_spitting = true
    end

    if self.is_spitting then
        if sprite.curAnim == nil then
            sprite:play("idle")
            self.is_spitting = false
        else
            actor.move_x = 0.0
        end
    end

    -- print(controller.side_drop_trigger)
end

return Player