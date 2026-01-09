local scene = require("sceneman").scene()
local fontres = require("fontres")
local Game = require("game")
local Input = require("input")

local PAUSE_OPTIONS = {"resume", "respawn", "options", "exit"}
local RAINBOW = {
    P8_PAL.yellow, P8_PAL.white
}

local self

---@param opt_idx integer
local function select_pause_option(opt_idx)
    if opt_idx == 1 then
        -- resume
        self.paused = false
    
    elseif opt_idx == 2 then
        -- respawn
        self.game:respawn()
        self.paused = false
    
    elseif opt_idx == 3 then
        softerror("options menu unimplemented")
    
    elseif opt_idx == 4 then
        softerror("'exit' unimplemented")
    end
end

function scene.load()
    Lg.setBackgroundColor(P8_PAL.black)
    self = {}
    self.game = Game()
    self.paused = false
    self.selected_pause_option = 1
    self.frame_num = 0
end

function scene.unload()
    self.game:release()
    self = nil
end

function scene.update(dt)
    if Input.players[1]:pressed("pause") then
        self.paused = not self.paused
        self.selected_pause_option = 1
        self.frame_num = 0
    end

    if not self.paused then
        self.game:update(dt)
    else
        if Input.players[1]:pressed("down") then
            self.selected_pause_option = self.selected_pause_option + 1
            self.frame_num = 0
        elseif Input.players[1]:pressed("up") then
            self.selected_pause_option = self.selected_pause_option - 1
            self.frame_num = 0
        end

        self.selected_pause_option = math.wrap(self.selected_pause_option,
                                               1, #PAUSE_OPTIONS + 1)

        if Input.players[1]:pressed("player_jump") then
            select_pause_option(self.selected_pause_option)
        end
    end
end

---@diagnostic disable-next-line: inject-field
function scene.tick()
    if not self.paused then
        self.game:tick()
    else
        self.frame_num = self.frame_num + 1
    end
end

function scene.draw()
    self.game:draw()

    if self.paused then
        Lg.setColor(P8_PAL.black)
        Lg.rectangle("fill", 1, 1, 46, 6 * (#PAUSE_OPTIONS + 1) + 1)

        Lg.setColor(P8_PAL.white)
        Lg.setFont(fontres.quinque)
        Lg.print("paused", 2, 1)
        for i, str in ipairs(PAUSE_OPTIONS) do
            local text_x = 5
            local text_y = 7 + (i-1) * 6
            if i == self.selected_pause_option then
                local ri = math.floor(self.frame_num / 8)
                Lg.setColor(RAINBOW[ri % #RAINBOW + 1])
                Lg.rectangle("fill", 2, 10 + (i-1) * 6, 2, 2)
                Lg.print(str, text_x, text_y)
                -- for c=1, str:len() do
                --     Lg.print(str:sub(c, c), text_x + (c-1) * 6, text_y)
                -- end
            else
                Lg.setColor(P8_PAL.white)
                Lg.print(str, text_x, text_y)
            end

        end
        -- Lg.print("paused\n>resume\n respawn\n exit", 2, 1)
    end
end

return scene