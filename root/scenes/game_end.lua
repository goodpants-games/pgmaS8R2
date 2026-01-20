local sceneman = require("sceneman")
local game_prog = require("game.progression")
local const = require("game.consts")
local Menu = require("ui.menu")
local GameUtil = require("game.util")

local scene = sceneman.scene()

local self

local TEXT =
[[

YOU BEAT THE GAME!
RED ORBS: $RED_ORBS/$MAX_RED_ORBS
SECRET ORBS: $BLUE_ORBS/$MAX_BLUE_ORBS
]]

function scene.load()
    self = {}
    local rc, bc = GameUtil.count_orbs(game_prog.collected_orbs)

    self.red_orbs = rc
    self.blue_orbs = bc

    local text = TEXT:gsub("$BLUE_ORBS", self.blue_orbs)
                     :gsub("$MAX_BLUE_ORBS", const.BLUE_ORB_COUNT)
                     :gsub("$RED_ORBS", self.red_orbs)
                     :gsub("$MAX_RED_ORBS", const.RED_ORB_COUNT)

    self.menu = Menu()
        :add_label("CONGRATULATIONS!")
        :add_text(text, DISPLAY_WIDTH - 4.0, "center")
        :add_action("YAY!", "ok")

    self.menu.centered = true
    self.menu.min_width = DISPLAY_WIDTH
    self.menu.on_signal = function()
        sceneman.switchScene("main_menu")
    end

    self.music = love.audio.newSource("res/music/DT&AP_ED.XM", "stream")
    self.music:setVolume(0.5)
    self.music:setLooping(true)
    self.music:play()
end

function scene.unload()
    self.music:stop()
    self.music:release()
    self = nil
end

function scene.update(dt)
    self.menu:update()
end

function scene.tick()
    self.menu:tick()
end

function scene.draw()
    local _, h = self.menu:get_size()
    self.menu:draw(0, math.round((DISPLAY_HEIGHT - h) / 2.0))
end

return scene