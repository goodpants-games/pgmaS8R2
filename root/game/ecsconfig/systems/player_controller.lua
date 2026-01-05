local Concord = require("concord")
local Input = require("input")

local system = Concord.system({
    pool = {"player_control"}
})

function system:update(dt)
    local game = self:getWorld().game --[[@as game.Game]]
    local input = Input.players[1]

    for _, ent in ipairs(self.pool) do
        local player_control = ent.player_control

        local move_x, move_y = input:get("move")
        if game._room_transition and game._room_transition.ticks < 15 then
            move_x = game._room_transition.pmv
        end
        player_control.move_x = move_x

        if input:pressed("player_jump") then
            player_control.jump_trigger = true
        end

        if input:pressed("player_lb") then
            player_control.up_drop_trigger = 8
        end

        if input:pressed("player_rb") then
            player_control.side_drop_trigger = 8
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
                actor.jump_trigger = 8
            end
        end

        player_control.did_spit = false

        local mana = assert(ent.mana, "no 'mana' component")
        if mana.value > 0 and actor.grounded then
            if player_control.side_drop_trigger > 0 then
                player_control.did_spit = true
                mana.value = mana.value - 1
                player_control.side_drop_trigger = 0

                local droplet =
                    game:new_entity()
                        :give("position", position.x, position.y)
                        :give("velocity", actor.face_dir * 1.0, -3.0)
                        :give("gmult", 2)
                        :give("behavior", "builder_droplet", position.y + 4.5)
                        :give("sprite", game.res:get_image("res/graphics/game/water_droplet.png"))
            
            elseif player_control.up_drop_trigger > 0 then
                player_control.did_spit = true
                mana.value = mana.value - 1
                player_control.up_drop_trigger = 0
                
                local droplet =
                    game:new_entity()
                        :give("position", position.x, position.y)
                        :give("velocity", 0, -3.0)
                        :give("gmult", 2)
                        :give("behavior", "builder_droplet", position.y - 8)
                        :give("sprite", game.res:get_image("res/graphics/game/water_droplet.png"))
            end
        end

        player_control.side_drop_trigger = player_control.side_drop_trigger - 1
        player_control.up_drop_trigger = player_control.up_drop_trigger - 1

        if player_control.side_drop_trigger < 0 then
            player_control.side_drop_trigger = 0
        end

        if player_control.up_drop_trigger < 0 then
            player_control.up_drop_trigger = 0
        end

        local room_trans = game._room_transition
        if room_trans and room_trans.phase == 0 then
            if room_trans.dir == "u" then
                ent.velocity.y = -1.0    
            elseif room_trans.dir == "l" or room_trans.dir == "r" then
                ent.velocity.y = -game.gravity
            end
        end
    end
end

return system