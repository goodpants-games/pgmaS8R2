local sceneman = require("sceneman")
local game_prog = require("game.progression")
local const = require("game.consts")
local Menu = require("ui.menu")

local scene = sceneman.scene()

local self

local TEXT =
[[

YOU BEAT THE GAME!
YOU ALSO HAVE COLLECTED $BLUEORBS/$MAXBLUEORBS BLUE ORBS.
]]

function scene.load()
    self = {}
    local rc, bc = 0, 0

    for i, v in ipairs(game_prog.collected_orbs) do
        if v.kind == "red" then
            rc = rc + 1
        elseif v.kind == "blue" then
            bc = bc + 1
        end
    end

    self.red_orbs = rc
    self.blue_orbs = bc

    local text = TEXT:gsub("$BLUEORBS", self.blue_orbs)
                     :gsub("$MAXBLUEORBS", const.BLUE_ORB_COUNT)

    self.menu = Menu()
        :add_label("CONGRATULATIONS!")
        :add_text(text, DISPLAY_WIDTH - 4.0, "center")
        :add_action("YAY!", "ok")

    self.menu.centered = true
    self.menu.min_width = DISPLAY_WIDTH
    self.menu.on_signal = function()
        sceneman.switchScene("main_menu")
    end
end

function scene.unload()
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