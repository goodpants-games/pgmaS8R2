local sceneman = require("sceneman")
local scene = sceneman.scene()
local Game = require("game")
local Input = require("input")
local Menu = require("ui.menu")
local OptionsMenu = require("ui.options_menu")
local userpref = require("userpref")

local PAUSE_OPTIONS = {"resume", "respawn", "options", "exit"}
local RAINBOW = {
    P8_PAL.yellow, P8_PAL.white
}

local self

---@param menu ui.Menu
local function is_menu_active(menu)
    return self.menu_stack[#self.menu_stack] == menu
end

local function exit_confirm_signal(menu, signal)
    if signal == "y" then
        sceneman.switchScene("main_menu")
    
    elseif signal == "n" then
        table.remove(self.menu_stack)
    end
end

---@param menu ui.Menu
---@param signal string
local function pause_menu_signal(menu, signal)
    if signal == "resume" then
        -- resume
        table.clear(self.menu_stack)
        self.paused = false
    
    elseif signal == "respawn" then
        -- respawn
        self.game:restore_state()
        self.paused = false
    
    elseif signal == "options" then
        self.options_menu.active_item = 1
        table.insert(self.menu_stack, self.options_menu)
    
    elseif signal == "exit" then
        local m = Menu()
            :add_label("exit?")
            :add_action("YES", "y")
            :add_action("NO", "n")
        
        m.query_focused = is_menu_active
        m.on_signal = exit_confirm_signal

        table.insert(self.menu_stack, m)
    end
end

local function options_menu_back()
    table.remove(self.menu_stack)
end

function scene.load()
    Lg.setBackgroundColor(P8_PAL.black)
    self = {}
    self.game = Game()
    self.paused = false

    ---@type ui.Menu[]
    self.menu_stack = {}

    self.pause_menu = Menu()
        :add_label("PAUSED")
        :add_action("RESUME", "resume")
        :add_action("RESPAWN", "respawn")
        :add_action("OPTIONS", "options")
        :add_action("EXIT", "exit")

    self.options_menu = OptionsMenu()

    self.pause_menu.on_signal = pause_menu_signal
    self.pause_menu.query_focused = is_menu_active
    self.options_menu.on_back = options_menu_back
    self.options_menu.query_focused = is_menu_active
end

function scene.unload()
    self.game:release()
    self = nil
end

function scene.keypressed(k)
    if Debug.enabled then
        if k == "f2" then
            self.game:save_state()
        elseif k == "f3" then
            self.game:restore_state()
        end
    end
end

function scene.update(dt)
    if Input.players[1]:pressed("pause") then
        self.paused = not self.paused

        if self.paused then
            table.clear(self.menu_stack)
            self.pause_menu.active_item = 1
            table.insert(self.menu_stack, self.pause_menu)
        end
    end

    if not self.paused then
        self.game:update(dt)
    else
        self.menu_stack[#self.menu_stack]:update()
    end
end

---@diagnostic disable-next-line: inject-field
function scene.tick()
    if not self.paused then
        self.game:tick()
    else
        self.menu_stack[#self.menu_stack]:tick()
    end
end

function scene.draw()
    self.game:draw()

    if self.paused then
        Lg.setBlendMode("multiply", "premultiplied")
        Lg.setColor(0.5, 0.5, 0.5)
        Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
        Lg.setBlendMode("alpha")

        local xoff = 0
        for i, v in ipairs(self.menu_stack) do
            self.menu_stack[i]:draw(2 + xoff, 2)
            local w = self.menu_stack[i]:get_size()
            xoff = xoff + w + 1.0
        end
    end
end

return scene