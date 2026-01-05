local scene = require("sceneman").scene()
local fontres = require("fontres")
local Sprite = require("sprite")
local Game = require("game")
local tiled = require("tiled")

local self

function scene.load()
    Lg.setBackgroundColor(P8_PAL.black)
    self = {}
    self.game = Game()
end

function scene.unload()
    self.game:release()
    self = nil
end

function scene.update(dt)
    self.game:update(dt)
end

---@diagnostic disable-next-line: inject-field
function scene.tick()
    self.game:tick()
end

function scene.draw()
    self.game:draw()
end

return scene