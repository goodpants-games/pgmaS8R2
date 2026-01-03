local scene = require("sceneman").scene()
local fontres = require("fontres")
local Sprite = require("sprite")
local Game = require("game")
local tiled = require("tiled")

local self

function scene.load()
    self = {}
    self.game = Game()

    self.player = self.game:new_entity()
        :give("position", 12.0, 12.0)
        :give("velocity")
        :give("sprite", self.game.res:new_sprite("player"))
        :give("collision", 6.0, 8.0)
        :give("actor")
        :give("player_control")
    
    self.player.sprite.ox = -1
    self.player.sprite.oy = -1

    local test_ent = self.game:new_entity()
        :give("position", 12.0 + 8.0 * (1), 12.0)
        :give("velocity")
        :give("sprite", self.game.res:new_sprite("player"))
        :give("collision", 6.0, 8.0)
        :give("actor")
        :give("player_control")
    
    test_ent.sprite.ox = -1
    test_ent.sprite.oy = -1
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
    self.game.cam.x = math.floor(self.player.position.x / 120) * 120 + DISPLAY_WIDTH / 2.0
    self.game.cam.y = math.floor(self.player.position.y / 88) * 88 + DISPLAY_HEIGHT / 2.0
    -- self.game.cam.x = self.player.position.x
    -- self.game.cam.y = self.player.position.y
end

function scene.draw()
    self.game:draw()
end

return scene