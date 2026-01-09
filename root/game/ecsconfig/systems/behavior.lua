local Concord = require("concord")

local system = Concord.system({
    pool = {"behavior"}
})

function system:init()    
    function self.pool.onAdded(_, ent)
        print("behavior: entity added")
        local behavior = ent.behavior
        behavior.inst:init(ent, self:getWorld().game)
    end

    function self.pool.onRemoved(_, ent)
        print("behavior: entity removed")
        local behavior = ent.behavior
        if behavior.inst.removed then
            behavior.inst:removed()
        end
    end
end

function system:tick()
    -- tick behaviors
    for _, ent in ipairs(self.pool) do
        ---@type {inst: game.behavior.Base, _is_init:boolean?}
        local behavior = ent.behavior
        behavior.inst:tick()
    end
end

return system