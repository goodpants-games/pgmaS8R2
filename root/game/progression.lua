local progression = {}

---@class game.OrbData
---@field gid string
---@field kind string

function progression.reset()
    ---@type game.OrbData[]
    progression.collected_orbs = {}
end

return progression