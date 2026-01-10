---@class game.behavior.Player: game.behavior.Base
---@overload fun():game.behavior.Player
local Player = batteries.class {
    name = "game.behavior.Player",
    extends = require("game.ecsconfig.behaviors.base")
}

local consts = require("game.consts")
local ecs_util = require("game.ecs_util")
local Input = require("input")

local TILE_SIZE = consts.TILE_SIZE
local RAINBOW = {
    P8_PAL.red, P8_PAL.orange, P8_PAL.yellow, P8_PAL.green, P8_PAL.blue,
    P8_PAL.pink
}

function Player:new()
    self:super()
    self.is_spitting = false
end

function Player:init(ent, game)
    self.__super.init(self, ent, game)
    
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
    local data = self.__super.serialize(self)
    data.vis_ent = nil
    return data
end

function Player:tick()
    local game = self.game
    local ent = self.entity
    local csprite = ent.sprite
    local control = ent.player_control
    local actor = ent.actor
    local touching = ent.touch_monitor.touching

    local sprite = csprite.obj --[[@as pklove.Sprite]]

    if control.did_spit then
        sprite:play("spit")
        ent.velocity.x = 0.0
        self.is_spitting = true
    end

    if self.is_spitting then
        if sprite.curAnim == nil then
            sprite:play("idle")
            self.is_spitting = false
        else
            actor.move_x = 0.0
        end
    end

    control.action_sink = false
    for _, other_ent in ipairs(touching) do
        if other_ent.interactable then
            control.action_sink = true

            if Input.players[1]:pressed("player_action1") then
                ecs_util.trigger_interaction(ent, other_ent)    
            end

            break
        end
    end

    local vis_ent = self.vis_ent

    if actor.grounded and not control.action_sink then
        local vis_tx = 0
        local vis_ty = 0

        if control.selected_tool == 1 then
            local vy = consts.PLAYER_SIDE_SPIT_VY
            local g = game.gravity * consts.PLAYER_SPIT_G_MULT
            local y0 = -consts.PLAYER_SIDE_SPIT_TARGET_Y_OFF

            local t = math.ceil((-vy + math.sqrt(vy * vy + 2.0 * g * y0)) / g)
            -- oh my god what the hell. why so precise. maybe fp error
            -- accumulation?
            local dx = math.ceil(consts.PLAYER_SIDE_SPIT_VX * t + 1.0001) * math.sign(actor.face_dir)
            
            vis_tx = math.floor((ent.position.x + dx) / TILE_SIZE * 2.0) / 2.0
            vis_ty = math.floor((ent.position.y - y0) / TILE_SIZE)
        elseif control.selected_tool == 2 then
            vis_tx = math.floor((ent.position.x) / TILE_SIZE * 2.0) / 2.0
            vis_ty = math.floor(ent.position.y / TILE_SIZE - 1.0)
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

return Player