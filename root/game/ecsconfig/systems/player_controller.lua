local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:update(dt)
    local input = Input.players[1]

    for _, ent in ipairs(self.pool) do
        local player_control = ent.player_control

        local move_x, move_y = input:get("move")
        player_control.move_x = move_x
        player_control.jump_trigger = input:pressed("player_jump")
    end
end

function system:tick()
    for _, ent in ipairs(self.pool) do
        local player_control = ent.player_control
        local actor = ent.actor

        if actor then
            actor.move_x = player_control.move_x

            if player_control.jump_trigger then
                player_control.jump_trigger = false
                actor.jump_trigger = 10
            end
        end
    end
end

return system