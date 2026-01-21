local Concord = require("concord")
local system = Concord.system({
    pool = {"velocity", "actor"}
})

function system:tick()
    Jprof.push("tick actors")

    for _, ent in ipairs(self.pool) do
        local velocity = ent.velocity
        local actor = ent.actor

        actor.did_jump = false

        if actor.move_x ~= 0.0 then
            actor.face_dir = math.sign(actor.move_x)
        end

        velocity.x = velocity.x + actor.move_x * actor.move_speed

        if actor.jump_trigger > 0 then
            if actor.grounded then
                actor.jump_trigger = 0
                velocity.y = -actor.jump_velocity
                actor.grounded = false
                actor.did_jump = true
            else
                actor.jump_trigger = actor.jump_trigger - 1
            end
        end
    end

    Jprof.pop("tick actors")
end

return system