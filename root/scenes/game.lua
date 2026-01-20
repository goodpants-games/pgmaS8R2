local sceneman = require("sceneman")
local scene = sceneman.scene()
local Game = require("game")
local Input = require("input")
local Menu = require("ui.menu")
local OptionsMenu = require("ui.options_menu")
local ControlsMenu = require("ui.controls_menu")
local game_progression = require("game.progression")
local Recorder = require("game.recorder")

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

    elseif signal == "controls" then
        local new_menu = ControlsMenu(DISPLAY_WIDTH - 8)
        new_menu.on_back = function()
            table.remove(self.menu_stack)
        end

        table.insert(self.menu_stack, new_menu)

    elseif signal == "debug" then
        local new_menu = Menu()
            :add_label("DEBUG")
            :add_action("WARP", "warp")
            :add_action("+1 RORB", "rorb")
            :add_action("+1 BORB", "borb")
            :add_action("BACK", "back")

        new_menu.on_signal = function(_, sig)
            if sig == "warp" then
                io.write("enter room: ")
                local line = io.read("*l")
                self.game:warp_to_room("maps/" .. line .. ".tmx")

            elseif sig == "rorb" then
                self.paused = false
                table.clear(self.menu_stack)

                table.insert(require("game.progression").collected_orbs,
                             { kind = "red", gid = "dummy" })
                self.game.dialogue:start("collect_fire_orb", "red", self.game)

            elseif sig == "borb" then
                self.paused = false
                table.clear(self.menu_stack)

                table.insert(require("game.progression").collected_orbs,
                             { kind = "blue", gid = "dummy" })
                self.game.dialogue:start("collect_fire_orb", "blue", self.game)
            
            elseif sig == "back" then
                table.remove(self.menu_stack)
            end
        end

        table.insert(self.menu_stack, new_menu)
    
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
    game_progression.reset()

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
        :add_action("CONTROLS", "controls")
        :add_action("EXIT", "exit")

    if Debug.enabled then
        self.pause_menu:add_action("DEBUG", "debug")
    end

    self.options_menu = OptionsMenu()

    self.pause_menu.on_signal = pause_menu_signal
    self.pause_menu.query_focused = is_menu_active
    self.options_menu.on_back = options_menu_back
    self.options_menu.query_focused = is_menu_active

    ---@type game.Recorder?
    self.recorder = nil
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
        elseif k == "f4" then
            if self.recorder then
                self.recorder:finish("ignore/capture.txt")
                self.recorder = nil
            else
                self.recorder = Recorder(self.game)
            end
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

        if self.recorder and self.game.frame % 2 == 0 then
            self.recorder:capture()
        end
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

        local yoff = 0
        for i, v in ipairs(self.menu_stack) do
            self.menu_stack[i]:draw(2, 2 + yoff)
            local _, h = self.menu_stack[i]:get_size()
            yoff = yoff + h + 1.0
        end
    end
end

return scene