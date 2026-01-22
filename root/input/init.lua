local Input = {}
local baton = require("input.baton")
local UserPref = require("userpref")

local base_controls = {
    pause = {'key:escape', 'key:`', 'button:start'},

    left = {'axis:leftx-', 'button:dpleft'},
    right = {'axis:leftx+', 'button:dpright'},
    up = {'axis:lefty-', 'button:dpup'},
    down = {'axis:lefty+', 'button:dpdown'},

    player_jump = {'button:a'},
    player_action1 = {'button:b'},
    player_action2 = {'button:x'},
    player_lb = {"button:leftshoulder"},
    player_rb = {"button:rightshoulder"},

    ui_confirm = {'button:a'},
}

local function get_new_baton_config()
    local input_mode = UserPref.input_mode

    local controls = table.deep_copy(base_controls) --[[@as table]]
    local tinsert = table.insert

    tinsert(controls.left, "key:left")
    tinsert(controls.right, "key:right")
    tinsert(controls.up, "key:up")
    tinsert(controls.down, "key:down")

    if input_mode == "wasd" then
        tinsert(controls.left, "key:a")
        tinsert(controls.right, "key:d")
        tinsert(controls.up, "key:w")
        tinsert(controls.down, "key:s")
        tinsert(controls.player_jump, "key:space")
        tinsert(controls.player_action1, "key:;")
        tinsert(controls.player_action2, "key:'")

        tinsert(controls.ui_confirm, "key:space")
        tinsert(controls.ui_confirm, "key:return")
    elseif input_mode == "arrow" then
        tinsert(controls.player_jump, "key:z")
        tinsert(controls.player_action1, "key:x")
        tinsert(controls.player_action2, "key:c")
        tinsert(controls.player_lb, "key:a")
        tinsert(controls.player_rb, "key:s")

        tinsert(controls.ui_confirm, "key:z")
    else
        error("invalid input mode " .. input_mode)
    end

    return controls
end

Input.players = {}
Input.players[1] = baton.new {
    controls = get_new_baton_config(),
    pairs = {
        move = {'left', 'right', 'up', 'down'}
    },
    joystick = love.joystick.getJoysticks()[1],
}

function Input.update_config()
    local new_config = get_new_baton_config()
    local active_config = Input.players[1].config.controls

    for k, sources in pairs(active_config) do
        table.clear(sources)
        for i,v in pairs(new_config[k]) do
            sources[i] = v
        end
    end
    -- .controls = 
end

function Input.update()
    for _, p in pairs(Input.players) do
        p:update()
    end
end

return Input