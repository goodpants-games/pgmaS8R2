---@class game.behavior.Base: batteries.Class
---@field entity any
---@field game game.Game
---@overload fun():game.behavior.Base
local Behavior = batteries.class { name = "game.Behavior" }

function Behavior:new() end

---@param ent any
---@param game game.Game
function Behavior:init(ent, game)
    self.entity = ent
    self.game = game
end

function Behavior:tick()
end

return Behavior