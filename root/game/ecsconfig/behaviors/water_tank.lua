---@class game.behavior.WaterTank: game.behavior.Base
---@overload fun():game.behavior.Player
local WaterTank = batteries.class {
    name = "game.behavior.WaterTank",
    extends = require("game.ecsconfig.behaviors.base")
}

function WaterTank:new()
    self:super()

    self._was_touching_player = false
end

function WaterTank:tick()
    local ent = self.entity
    local touching = ent.touch_monitor.touching

    local is_touching_player = false
    local player = self.game.player

    for _, e in ipairs(touching) do
        if e == player then
            is_touching_player = true
            break
        end
    end

    if is_touching_player and not self._was_touching_player then
        print("replenish water supply")
        player.mana.value = player.mana.max
    end

    self._was_touching_player = is_touching_player
end

return WaterTank