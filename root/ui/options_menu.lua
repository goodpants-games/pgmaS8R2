local Menu = require("ui.menu")
local userpref = require("userpref")
local Input = require("input")

---@class ui.OptionsMenu: ui.Menu
---@field on_back fun(menu:ui.OptionsMenu)
---@overload fun():ui.OptionsMenu
local OptionsMenu = batteries.class {
    name = "ui.OptionsMenu",
    extends = Menu
}

---@param fs boolean?
---@return string
local function fulscr_label(fs)
    if fs == nil then
        fs = love.window.getFullscreen()
    end

    if fs then
        return "FULSCR  ON"
    else
        return "FULSCR OFF"
    end
end

---@param map string?
---@return string
local function keymap_label(map)
    if map == nil then
        map = userpref.input_mode
    end

    if map == "arrow" then
        return "KMAP ARROW"
    elseif map == "wasd" then
        return "KMAP  WASD"
    else
        return "KMAP   ???"
    end
end

function OptionsMenu:new()
    self:super()

    self:add_label("OPTIONS")
        :add_action(fulscr_label(), "fulscr")
        :add_action(keymap_label(), "keymap")
        :add_action("BACK", "back")    
end

---@param signal string
function OptionsMenu:on_signal(signal)
    if signal == "back" then
        self:on_back()
    
    elseif signal == "fulscr" then
        local fs = love.window.getFullscreen()
        if fs then
            love.window.setFullscreen(false)
        else
            love.window.setFullscreen(true, "desktop")
        end

        self.items[2].label = fulscr_label()
    
    elseif signal == "keymap" then
        if userpref.input_mode == "wasd" then
            userpref.input_mode = "arrow"
        else
            userpref.input_mode = "wasd"
        end

        Input.update_config()
        self.items[3].label = keymap_label()
    end
end

return OptionsMenu