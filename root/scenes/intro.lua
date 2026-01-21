local sceneman = require("sceneman")
local scene = sceneman.scene()
local Input = require("input")
local Menu = require("ui.menu")
local Sprite = require("sprite")
local fontres = require("fontres")

local font = fontres.quinque

local self

local TEXT = {
[[The winters of this world are extraordinarily cold.]],
[[During the winter months, Unyus migrate to live within the caverns of The Big Mountain.]],
[[But that alone is not sufficient for survival.]],
[[Fire Orbs accumulate inside the caverns during the summer.]],
[[These mysterious, elusive objects provide a long-lasting and versatile source of heat.]],
[[In order for Unyus to survive the winters, they must explore the caverns to find them.]],
[[But this is no easy task. Other, more dangerous creatures live in the caverns.]],
[[And, unfortunately, Unyus taste yummy. Muahaha...]],
}

local function load_page()
    local page = self.page
    assert(type(page) == "number")

    local mw, lines = font:getWrap(TEXT[page], DISPLAY_WIDTH - 8)
    self.page_text = table.concat(lines, "\n")
    self.page_display = ""
    self.tick_accum = 0
    self.page_done = false
end

function scene.load()
    self = {}
    Lg.setBackgroundColor(P8_PAL.black)

    self.page = 1
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

    self.intro_sprite = Sprite.new("res/sprites/intro.json")
    self.intro_sprite.alignment = "topleft"

    self.music = love.audio.newSource("res/music/DT_DAY.XM", "stream")
    self.music:setLooping(true)
    self.music:setVolume(0.4)
    self.music:play()

    load_page()
end

function scene.unload()
    self.intro_sprite:release()
    self.music:release()
    self = nil
end

function scene.update(dt)
    if self.page == "objective" then
        self.obj_menu:update()
    elseif Input.players[1]:pressed("player_jump") then
        self.trigger_advance = true
    end
end

function scene.tick()
    local trigger_advance = self.trigger_advance
    self.trigger_advance = false

    if self.page == "objective" then
        self.obj_menu:tick()
    else
        if self.page_done then
            if trigger_advance then
                self.page = self.page + 1

                if self.page > #TEXT then
                    self.music:stop()
                    self.page = "objective"
                else
                    load_page()
                end
            end
        else
            self.tick_accum = self.tick_accum + 1

            if trigger_advance then
                self.page_display = self.page_text
                self.page_done = true
            elseif self.tick_accum >= 2 then
                self.tick_accum = 0
                local last = string.len(self.page_display) + 1
                if last > string.len(self.page_text) then
                    self.page_done = true
                else
                    self.page_display = string.sub(self.page_text, 1, last)
                end
            end
        end
    end
end

function scene.draw()
    local page = self.page

    if page == "objective" then
        local _, h = self.obj_menu:get_size()
        self.obj_menu:draw(0, math.round((DISPLAY_HEIGHT - h) / 2.0))
        -- Lg.printf(OBJECT_TEXT, 0, math.round((DISPLAY_HEIGHT - 12) / 2.0), DISPLAY_WIDTH, "center")
    else
        ---@cast page integer
        
        Lg.setColor(1, 1, 1)
        self.intro_sprite:drawCel(page, 4, 1)
        Lg.setColor(P8_PAL.white)
        Lg.print(self.page_display, 4, DISPLAY_HEIGHT - 39)
        -- Lg.printf(TEXT[page], 4, DISPLAY_HEIGHT - 39, DISPLAY_WIDTH - 8, "left")
    end
end

return scene