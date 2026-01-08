---@class game.behavior.Player: game.behavior.Base
---@overload fun():game.behavior.Player
local Player = batteries.class {
    name = "game.behavior.Player",
    extends = require("game.ecsconfig.behaviors.base")
}

local TILE_SIZE = require("game.consts").TILE_WIDTH
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
    ent.sprite.obj:play("idle")

    local function draw_func(ent, sprite)
        Lg.setLineWidth(1)
        Lg.rectangle("line", -3.5, -1.5, 7, 3)
    end

    self.vis_ent =
        game:new_entity()
            :give("position", 0.0, 0.0)
            :give("sprite", draw_func)
end

function Player:removed()
    self.vis_ent:destroy()
end

function Player:tick()
    local ent = self.entity
    local csprite = ent.sprite
    local control = ent.player_control
    local actor = ent.actor

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

    local vis_ent = self.vis_ent

    if actor.grounded then
        local vis_tx = 0
        local vis_ty = 0

        if control.selected_tool == 1 then
            vis_tx = math.round((ent.position.x + 28 * actor.face_dir) / TILE_SIZE)
            vis_ty = math.floor(ent.position.y / TILE_SIZE + 1)
        elseif control.selected_tool == 2 then
            vis_tx = math.floor((ent.position.x) / TILE_SIZE)
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