local Menu = require("ui.menu")
local userpref = require("userpref")
local Input = require("input")

---@class ui.ControlsMenu: ui.Menu
---@field on_back fun(menu:ui.ControlsMenu)
---@overload fun(width:integer):ui.ControlsMenu
local ControlsMenu = batteries.class {
    name = "ui.ControlsMenu",
    extends = Menu
}

local CONTROLS_TEXT_ARROW =
[[ARROW   MOVE
Z       JUMP
X       FIRE
C       SWITCH
ESC/`   PAUSE]]

local CONTROLS_TEXT_WASD =
[[WASD    MOVE
SPACE   JUMP
;       FIRE
'       SWITCH
ESC/`   PAUSE]]

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

local function control_list_text()
    local text
    if userpref.input_mode == "arrow" then
        text = CONTROLS_TEXT_ARROW
    elseif userpref.input_mode == "wasd" then
        text = CONTROLS_TEXT_WASD
    end

    return text
end

---@param width number
function ControlsMenu:new(width)
    self:super()

    self.centered = true

    self:add_label("CONTROLS")
        :add_action(keymap_label(), "keymap")
        :add_text(control_list_text(), width)
        :add_action("OK", "back")
end

---@param signal string
function ControlsMenu:on_signal(signal)
    if signal == "keymap" then
        if userpref.input_mode == "wasd" then
            userpref.input_mode = "arrow"
        else
            userpref.input_mode = "wasd"
        end

        Input.update_config()
        self.items[2].label = keymap_label()
        self:replace_text_item(3, control_list_text())
        
    elseif signal == "back" then
        self:on_back()
    end
end

return ControlsMenu