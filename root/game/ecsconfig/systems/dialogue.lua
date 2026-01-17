local Concord = require("concord")
local Input = require("input")

local system = Concord.system {
    pool = {"position", "collision", "dialogue"}
}

local ANIM_COLORS = {
    P8_PAL.red, P8_PAL.orange, P8_PAL.yellow,
    P8_PAL.green, P8_PAL.blue, P8_PAL.pink
}

function system:init()
    self.potential_sign = nil
    self.anim_frames = 0

    self._dialogue_key_pressed = false
end

function system:update()
    if Input.players[1]:pressed("player_action1") then
        self._dialogue_key_pressed = true
    end
end

function system:tick()
    local key_pressed = self._dialogue_key_pressed
    self._dialogue_key_pressed = false

    local game = self:getWorld().game --[[@as game.Game]]
    local player = game.player

    for _, ent in ipairs(self.pool) do
        local name = ent.dialogue.name
        game.dialogue:preload(name)
    end

    self.potential_sign = nil

    if not game.dialogue:is_active() and player and player.touch_monitor then
        for _, ent in ipairs(player.touch_monitor.touching) do
            if table.index_of(self.pool, ent) then
                self.potential_sign = ent
                break     
            end
        end
    end

    if self.potential_sign then
        self.anim_frames = self.anim_frames + 1

        if key_pressed then
            local name = self.potential_sign.dialogue.name
            game.dialogue:start(name, self.potential_sign)
        end
    else
        self.anim_frames = 0
    end
end

function system:draw()
    local game = self:getWorld().game --[[@as game.Game]]
    
    local sign = self.potential_sign
    if not sign or game.dialogue:is_active() then
        return
    end

    local arrow_img = game.res:get_image("res/graphics/down_arrow_8x8.png")
    local btn_img = game.res:get_image("res/graphics/button_x_8x8.png")

    local top = sign.position.y - sign.collision.h / 2.0

    local color_idx = math.floor(self.anim_frames / 8) % #ANIM_COLORS
    Lg.setColor(ANIM_COLORS[color_idx + 1])

    local ypos = 7.0 + math.sin(self.anim_frames / 60 * math.pi * 2.0) * 1.0
    Lg.draw(arrow_img, math.round(sign.position.x - 4), math.round(top - ypos))

    Lg.setColor(1, 1, 1)
    Lg.draw(btn_img, math.round(sign.position.x - 4), math.round(top - ypos - 6))
end

return system