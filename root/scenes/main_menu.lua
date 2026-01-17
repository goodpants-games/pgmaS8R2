local sceneman = require("sceneman")
local scene = sceneman.scene()
local Menu = require("ui.menu")
local OptionsMenu = require("ui.options_menu")
local ControlsMenu = require("ui.controls_menu")

local self

---@param menu ui.Menu
---@param signal string
local function menu_signal(menu, signal)
    if signal == "play" then
        sceneman.switchScene("game")
    
    elseif signal == "options" then
        local opt_menu = OptionsMenu()
        opt_menu.on_back = function()
            table.remove(self.menu_stack)
        end

        table.insert(self.menu_stack, opt_menu)

    elseif signal == "controls" then
        local new_menu = ControlsMenu(DISPLAY_WIDTH - 8)
        new_menu.on_back = function()
            table.remove(self.menu_stack)
        end

        table.insert(self.menu_stack, new_menu)
    
    elseif signal == "quit" then
        love.event.quit()
    end
end

function scene.load()
    Lg.setBackgroundColor(P8_PAL.black)

    self = {}

    self.title_img = Lg.newImage("res/graphics/game_title.png")

    self.menu_stack = {}
    self.menu = Menu()
        :add_action("PLAY", "play")
        :add_action("OPTIONS", "options")
        :add_action("CONTROLS", "controls")
    
    if not LOVEJS then
        self.menu:add_action("QUIT", "quit")
    end
    
    self.menu.on_signal = menu_signal

    table.insert(self.menu_stack, self.menu)
end

function scene.unload()
    self.title_img:release()
    self = nil
end

function scene.update(dt)
    self.menu_stack[#self.menu_stack]:update()
end

function scene.tick()
    self.menu_stack[#self.menu_stack]:tick()
end

function scene.draw()
    Lg.setColor(1, 1, 1)
    Lg.draw(self.title_img)

    local menu = self.menu_stack[#self.menu_stack]
    local menu_width, menu_height = menu:get_size()
    
    menu:draw(math.round((DISPLAY_WIDTH - menu_width) / 2.0),
              math.round((DISPLAY_HEIGHT - menu_height) / 2.0 + DISPLAY_HEIGHT * 1/4))
end

return scene