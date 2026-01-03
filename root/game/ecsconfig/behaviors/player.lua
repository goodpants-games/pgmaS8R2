---@class game.behavior.Player: game.behavior.Base
---@overload fun():game.behavior.Player
local Player = batteries.class {
    name = "game.behavior.Player",
    extends = require("game.ecsconfig.behaviors.base")
}

function Player:tick()

end