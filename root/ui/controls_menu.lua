local Menu = require("ui.menu")
local userpref = require("userpref")

---@class ui.ControlsMenu: ui.Menu
---@field on_back fun(menu:ui.ControlsMenu)
---@overload fun(width:integer):ui.ControlsMenu
local ControlsMenu = batteries.class {
    name = "ui.ControlsMenu",
    extends = Menu
}

local CONTROLS_TEXT_ARROW =
[[ARROW - MOVE
Z     - JUMP
X     - FIRE
C     - SWITCH
ESC/` - PAUSE]]

local CONTROLS_TEXT_WASD =
[[WASD  - MOVE
SPACE - JUMP
;     - FIRE
'     - SWITCH
ESC/` - PAUSE]]

---@param width number
function ControlsMenu:new(width)
    self:super()

    local text
    if userpref.input_mode == "arrow" then
        text = CONTROLS_TEXT_ARROW
    elseif userpref.input_mode == "wasd" then
        text = CONTROLS_TEXT_WASD
    end

    self:add_label("CONTROLS")
        :add_text(text, width)
        :add_action("OK", "back")
end

---@param signal string
function ControlsMenu:on_signal(signal)
    if signal == "back" then
        self:on_back()
    end
end

return ControlsMenu