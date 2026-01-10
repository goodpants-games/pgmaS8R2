local ecs_util = {}

function ecs_util.trigger_interaction(ent_from, ent_to, ...)
    if ent_to.behavior and ent_to.behavior.inst.interact then
        ent_to.behavior.inst:interact(ent_from, ...)
    end
end

return ecs_util