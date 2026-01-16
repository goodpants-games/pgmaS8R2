local Concord = require("concord")
local Input = require("input")
local bit = require("bit")

local consts = require("game.consts")

local system = Concord.system({
    pool = {"player_control"}
})

function system:update(dt)
    local game = self:getWorld().game --[[@as game.Game]]
    local input = Input.players[1]

    for _, ent in ipairs(self.pool) do
        local pctl = ent.player_control

        local move_x, move_y = input:get("move")

        -- normalize move_x, move_y vector to always touch the perimeter of
        -- a square with side length 2 centered at the origin. this is so that
        -- holding up/down does not make the player move slower horizontally.
        if move_x * move_x + move_y * move_y > 1e-3 then
            local slope = move_y / move_x
            local slope_inv = move_x / move_y
            local d = math.sqrt(math.min(1.0 + slope * slope, math.min(1.0 + slope_inv * slope_inv)))
            move_x, move_y = move_x * d, move_y * d
        end

        if game._room_transition and game._room_transition.ticks < 15 then
            move_x = game._room_transition.pmv
            move_y = 0.0
        end
        pctl.move_x = move_x
        pctl.move_y = move_y

        if input:pressed("player_jump") then
            pctl.jump_trigger = true
        end

        if input:pressed("player_action2") then
            pctl.selected_tool = pctl.selected_tool + 1
            pctl.selected_tool = (pctl.selected_tool - 1) % 2 + 1
        end

        if input:pressed("player_action1") then
            pctl.drop_trigger = 8
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

        if player_control.action_sink then
            player_control.drop_trigger = 0
        end

        if game.dialogue:is_active() then
            actor.move_x = 0.0
            actor.jump_trigger = 0.0
            player_control.drop_trigger = 0
        else
            local mana = assert(ent.mana, "no 'mana' component")
            if player_control.drop_trigger > 0 then
                if player_control.selected_tool == 1 and mana.value >= 10 and actor.grounded then
                    player_control.did_spit = true
                    mana.value = math.max(0, mana.value - 10)
                    player_control.drop_trigger = 0

                    -- up spit
                    if player_control.move_y < 0.0 then
                        local droplet =
                            game:new_entity()
                                :give("position", position.x, position.y)
                                :give("velocity", 0, -3.0)
                                :give("gmult", consts.PLAYER_SPIT_G_MULT)
                                :give("behavior", "player_droplet", "up_platform")
                                :give("sprite", game.res:get_image("res/graphics/game/water_droplet.png"))
                        
                    -- side spit
                    else
                        local droplet =
                            game:new_entity()
                                :give("position", position.x, position.y)
                                :give("velocity",
                                    actor.face_dir * consts.PLAYER_SIDE_SPIT_VX,
                                    consts.PLAYER_SIDE_SPIT_VY)
                                :give("gmult", consts.PLAYER_SPIT_G_MULT)
                                :give("behavior", "player_droplet", "side_platform")
                                :give("sprite", game.res:get_image("res/graphics/game/water_droplet.png"))
                    end
                
                elseif player_control.selected_tool == 2 and mana.value >= 1 then
                    mana.value = math.max(0, mana.value - 1)
                    player_control.drop_trigger = 0

                    local vx = actor.face_dir * 4.0
                    local vy = 0.0

                    if player_control.move_y < -0.1 then
                        vx = 0.0
                        vy = -4.0
                    elseif player_control.move_y > 0.1 then
                        vx = 0.0
                        vy = 4.0
                    end

                    local droplet =
                        game:new_entity()
                            :give("position", position.x, position.y)
                            :give("velocity", vx, vy)
                            :give("gmult", 0.0)
                            :give("behavior", "player_droplet", "bullet")
                            :give("collision", 4, 4)
                            :give("touch_monitor")
                            :give("sprite", game.res:get_image("res/graphics/game/water_droplet.png"))

                    droplet.collision.monitor_only = true
                    droplet.collision.mask = bit.bnot(consts.COLGROUP_PLAYER)
                end
            end
        end

        player_control.drop_trigger = player_control.drop_trigger - 1
        if player_control.drop_trigger < 0 then
            player_control.drop_trigger = 0
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