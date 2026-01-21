local Concord = require("concord")

local system = Concord.system({
    pool = {"behavior"}
})

function system:init()
    function self.pool.onAdded(_, ent)
        local behavior = ent.behavior
        behavior.inst:init(ent, self:getWorld().game, behavior._soft_init)
        behavior._soft_init = nil
    end

    function self.pool.onRemoved(_, ent)
        local behavior = ent.behavior
        if behavior.inst.removed then
            behavior.inst:removed()
        end
    end
end

function system:tick()
    Jprof.push("tick behaviors")

    -- tick behaviors
    for _, ent in ipairs(self.pool) do
        ---@type {inst: game.behavior.Base, _is_init:boolean?}
        local behavior = ent.behavior
        behavior.inst:tick()
    end

    Jprof.pop("tick behaviors")
end

return system