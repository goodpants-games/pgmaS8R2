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

        if input:pressed("player_jump") then
            player_control.jump_trigger = true
        end

        if input:pressed("player_action") then
            player_control.action_trigger = true
        end
    end
end

function system:tick()
    local game = self:getWorld().game --[[@as game.Game]]

    for _, ent in ipairs(self.pool) do
        local player_control = ent.player_control
        local actor = ent.actor
        local position = assert(ent.position, "player_control has no position component")

        if actor then
            actor.move_x = player_control.move_x

            if player_control.jump_trigger then
                player_control.jump_trigger = false
                actor.jump_trigger = 6
            end
        end

        if player_control.action_trigger then
            player_control.action_trigger = false

            local mana = assert(ent.mana, "no 'mana' component")
            if mana.value > 0 then
                mana.value = mana.value - 1
                game:new_entity()
                    :give("position", position.x, position.y - 6)
                    :give("collision", 16, 4)
                    :give("sprite")
            end
        end
    end
end

return system