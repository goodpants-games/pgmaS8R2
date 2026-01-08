local Concord = require("concord")

local system = Concord.system({
    pool = {"behavior"}
})

function system:init()
    self._prev_entities = {}
end

function system:tick()
    local game = self:getWorld().game

    -- collect current entity list into a hashset
    local new_ents = {}
    for _, ent in ipairs(self.pool) do
        new_ents[ent] = true
    end

    -- handle removed entities
    for ent, _ in pairs(self._prev_entities) do
        if not new_ents[ent] then
            print("behavior: entity removed")
            local behavior = ent.behavior
            if behavior.inst.removed then
                behavior.inst:removed()
            end
        end
    end

    -- handle newly added entities
    local prev_ents = self._prev_entities
    for _, ent in ipairs(self.pool) do
        if not prev_ents[ent] then
            print("behavior: entity added")
            local behavior = ent.behavior
            behavior.inst:init(ent, game)
        end
    end

    -- swap
    self._prev_entities = new_ents

    -- tick behaviors
    for _, ent in ipairs(self.pool) do
        ---@type {inst: game.behavior.Base, _is_init:boolean?}
        local behavior = ent.behavior
        behavior.inst:tick()
    end
end

return system