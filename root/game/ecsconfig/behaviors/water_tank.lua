---@class game.behavior.WaterTank: game.behavior.Base
---@overload fun():game.behavior.Player
local WaterTank = batteries.class {
    name = "game.behavior.WaterTank",
    extends = require("game.ecsconfig.behaviors.base")
}

function WaterTank:new()
    self:super()
end

function WaterTank:msg_interact(from_ent)
    local ent = self.entity
    local game = self.game

    if from_ent.mana then
        from_ent.mana.value = from_ent.mana.max    
    end

    if from_ent == game.player then
        local p_pos, p_vel, p_actor = from_ent.position, from_ent.velocity,
                                      from_ent.actor
        assert(p_pos and p_vel, "player did not have position and velocity")

        for _, e in ipairs(game.ecs_world:query({"remove_on_checkpoint"})) do
            e:destroy()    
        end

        game.checkpoint_marker = ent
        
        local vx, vy = p_vel.x, p_vel.y
        local px = p_pos.x
        local mvx = p_actor.move_x

        p_vel.x = 0.0
        p_vel.y = 0.0
        p_pos.x = ent.position.x
        p_actor.move_x = 0

        print("save world state!")
        self.game:save_state()

        p_vel.x = vx
        p_vel.y = vy
        p_pos.x = px
        p_actor.move_x = mvx
    end
end

function WaterTank:tick()
    local ent = self.entity
    local game = self.game
    local sprite = ent.sprite

    if game.checkpoint_marker == ent then
        sprite.obj:play("normal_active")
    else
        sprite.obj:play("normal_inactive")
    end

    -- local ent = self.entity
    -- local touching = ent.touch_monitor.touching

    -- local is_touching_player = false
    -- local player = self.game.player

    -- for _, e in ipairs(touching) do
    --     if e == player then
    --         is_touching_player = true
    --         break
    --     end
    -- end

    -- if is_touching_player then
    --     print("replenish water supply")
    --     player.mana.value = player.mana.max
    -- end

    -- self._was_touching_player = is_touching_player
end

return WaterTank