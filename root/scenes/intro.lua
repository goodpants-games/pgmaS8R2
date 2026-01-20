local sceneman = require("sceneman")
local scene = sceneman.scene()
local Input = require("input")
local Menu = require("ui.menu")

local self

local TEXT = {
[[The winters of this world are extraordinarily cold.]],
[[During the winter months, Unyus migrate to live within the caverns of The Big Mountain.]],
[[But that alone is not sufficient for survival.]],
[[Fortunately, Fire Orbs accumulate inside the caverns during the summer.]],
[[These mysterious, elusive objects provide a long-lasting and versatile source of heat.]],
[[In order for Unyus to survive the winters, they must explore the caverns to find them.]],
[[But this is no easy task. Other, more dangerous creatures live in the caverns.]],
[[And, unfortunately, Unyus taste yummy. Muahaha...]],
}

local OBJECT_TEXT = [[OBJECTIVE:
Find four red fire orbs.
]]

function scene.load()
    self = {}
    Lg.setBackgroundColor(P8_PAL.black)

    self.page = "objective"
    self.obj_menu = Menu()
        :add_label("OBJECTIVE")
        :add_text("Find four red fire orbs.", DISPLAY_WIDTH, "center")
        :add_action("OK", "ok")
    
    self.obj_menu.centered = true
    self.obj_menu.min_width = DISPLAY_WIDTH

    self.obj_menu.on_signal = function(menu, signal)
        if signal == "ok" then
            sceneman.switchScene("game")
        end
    end
end

function scene.unload()
    self = nil
end

function scene.update(dt)
    if self.page == "objective" then
        self.obj_menu:update()
    elseif Input.players[1]:pressed("player_jump") then
        self.page = self.page + 1

        if self.page > #TEXT then
            self.page = "objective"
        end
    end
end

function scene.tick()
    if self.page == "objective" then
        self.obj_menu:tick()
    end
end

function scene.draw()
    if self.page == "objective" then
        local _, h = self.obj_menu:get_size()
        self.obj_menu:draw(0, math.round((DISPLAY_HEIGHT - h) / 2.0))
        -- Lg.printf(OBJECT_TEXT, 0, math.round((DISPLAY_HEIGHT - 12) / 2.0), DISPLAY_WIDTH, "center")
    else
        Lg.setColor(P8_PAL.red)
        Lg.rectangle("fill", 4, 4, DISPLAY_WIDTH - 8, DISPLAY_HEIGHT - 40)
        Lg.setColor(P8_PAL.white)
        Lg.printf(TEXT[self.page], 4, DISPLAY_HEIGHT - 36, DISPLAY_WIDTH - 8, "left")
    end
end

return scene