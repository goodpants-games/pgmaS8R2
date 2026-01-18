local Base = require("game.ecsconfig.behaviors.base")
---@class game.behavior.Player: game.behavior.Base
---@overload fun():game.behavior.Player
local Player = batteries.class {
    name = "game.behavior.Player",
    extends = Base
}

local consts = require("game.consts")
local GameUtil = require("game.util")
local Input = require("input")

local TILE_SIZE = consts.TILE_SIZE
local RAINBOW = {
    P8_PAL.red, P8_PAL.orange, P8_PAL.yellow, P8_PAL.green, P8_PAL.blue,
    P8_PAL.pink
}

function Player:new()
    self:super()
    self.is_spitting = false
    self.dead = false
    self.death_timer = 0
end

function Player:init(ent, game, soft_init)
    Base.init(self, ent, game, soft_init)
    
    if not ent.sprite.obj.curAnim then
        ent.sprite.obj:play("idle")
    end

    local function draw_func(ent, sprite)
        Lg.setLineWidth(1)
        Lg.rectangle("line", -2.5, -1.5, 5, 3)
    end

    self.vis_ent =
        game:new_entity(true)
            :give("position", 0.0, 0.0)
            :give("sprite", draw_func)
    self.vis_ent:remove("serializable")
end

function Player:removed()
    self.vis_ent:destroy()
end

function Player:serialize()
    local data = Base.serialize(self)
    data.vis_ent = nil
    return data
end

function Player:tick()
    local game = self.game
    local ent = self.entity
    local csprite = ent.sprite
    local control = ent.player_control
    local actor = ent.actor

    if self.dead then
        self.vis_ent.sprite.visible = false
        self.death_timer = self.death_timer + 1
        if self.death_timer > 30 then
            game:queue_restore()
        end

        return
    end

    if ent.collision.in_water then
        ent.player_control.enabled = false
        self.game.sound:play("player_die")
        self.dead = true
        csprite.obj:play("frozen")
        return
    end

    local sprite = csprite.obj --[[@as pklove.Sprite]]

    if control.did_spit then
        sprite:play("spit")
        ent.velocity.x = 0.0
        self.is_spitting = true
    end

    if actor then
        csprite.sx = math.binsign(actor.face_dir)
        if self.is_spitting then
            if sprite.curAnim == nil then
                sprite:play("idle")
                self.is_spitting = false
            else
                actor.move_x = 0.0
            end
        else
            local anim
            if actor.move_x ~= 0.0 and actor.grounded then
                anim = "walk"
            else
                anim = "idle"
            end

            if sprite.curAnim ~= anim then
                sprite:play(anim)
            end
        end

        if actor.did_jump then
            game.sound:play("jump")
        end
    end

    local vis_ent = self.vis_ent

    if actor and actor.grounded and not control.action_sink
       and control.selected_tool == 1
    then
        local vis_tx = 0
        local vis_ty = 0

        if control.move_y < 0.0 then
            vis_tx = math.floor((ent.position.x) / TILE_SIZE * 2.0 - 0.5) / 2.0
            vis_ty = math.floor(ent.position.y / TILE_SIZE - 1.0)
        else
            local vy = consts.PLAYER_SIDE_SPIT_VY
            local g = game.gravity * consts.PLAYER_SPIT_G_MULT
            local y0 = -consts.PLAYER_SIDE_SPIT_TARGET_Y_OFF

            -- local t = math.ceil((-vy + math.sqrt(vy * vy + 2.0 * g * y0)) / g)
            -- local dx = math.ceil(consts.PLAYER_SIDE_SPIT_VX * t) * math.sign(actor.face_dir)

            -- okay for some reason using the model isn't 100% accurate, it's
            -- probably fp error accumulation and i can't seem to be able to
            -- fix it. so i'm just going to simulate the physics in a loop. that
            -- way the fp errors will be simulated as well
            local vx = consts.PLAYER_SIDE_SPIT_VX * math.sign(actor.face_dir)
            local x = 0.0
            local y = 0
            local i = 1
            while true do
                if i >= 100 then
                    softerror("platform vis took too long?? why??")
                    break
                end

                vy = vy + g
                x = x + vx
                y = y + vy
                if y > -y0 then break end
                i=i+1
            end
            
            vis_tx = math.floor((ent.position.x + x) / TILE_SIZE * 2.0) / 2.0
            vis_ty = math.floor((ent.position.y + y) / TILE_SIZE)
        end

        vis_ent.position.x = vis_tx * TILE_SIZE + 4
        vis_ent.position.y = vis_ty * TILE_SIZE + 2
        vis_ent.sprite.visible = self.game.frame % 2 == 0
    else
        vis_ent.sprite.visible = false
    end

    local vis_color_index = (math.floor(self.game.frame / 8.0) % #RAINBOW) + 1
    vis_ent.sprite.r, vis_ent.sprite.g, vis_ent.sprite.b =
        unpack(RAINBOW[vis_color_index])
end

function Player:msg_attacked(from_ent, x, y)
    local ent = self.entity
    ent.collision.enabled = false
    ent.player_control.enabled = false

    ent:ensure("velocity")
    ent.velocity.x = math.binsign(x) * 0.25
    ent.velocity.y = -0.8

    ent:remove("actor")
        :give("gmult", 0.6)
        :remove("damping")

    self.game.sound:play("player_die")
    ent.sprite.obj:play("gooped")
    ent.sprite.sx = math.binsign(x)
    self.dead = true
    -- self.game:queue_restore()
end

return Player