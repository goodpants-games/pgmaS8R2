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

---@return table
function Behavior:serialize()
    local data = table.shallow_copy(self) --[[@as table]]
    data.entity = nil
    data.game = nil
    return data
end

function Behavior:deserialize(data)
    local ent, game = self.entity, self.game
    
    for k, v in pairs(data) do
        self[k] = v
    end

    -- just in case?
    self.entity, self.game = ent, game
end

return Behavior