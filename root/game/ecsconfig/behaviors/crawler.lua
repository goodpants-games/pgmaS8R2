local BaseEnemy = require("game.ecsconfig.behaviors.base_enemy")

---@class game.behavior.CrawlerEnemy: game.behavior.BaseEnemy
---@overload fun(props:table):game.behavior.CrawlerEnemy
local CrawlerEnemy = batteries.class {
    name = "game.behavior.CrawlerEnemy",
    extends = BaseEnemy
}

local GameUtil = require("game.util")
local consts = require("game.consts")

---@param props table
function CrawlerEnemy:new(props)
    props = props or {}
    self:super(props)

    self._turn_debounce = 0.0

    print(self.max_dist)
end

function CrawlerEnemy:init(ent, game, soft_init)
    BaseEnemy.init(self, ent, game, soft_init)
    if soft_init then return end

    if ent.actor then
        ent.actor.move_x = 1
    end

    if ent.sprite then
        ent.sprite.obj:play("walk")
    end
end

function CrawlerEnemy:tick()
    local ent = self.entity
    BaseEnemy.tick(self)

    local csprite = ent.sprite
    local sprite = csprite.obj --[[@as pklove.Sprite]]

    if self.dead then
        if sprite.curAnim ~= "dead" then
            sprite:play("dead")
        end
        return
    end
    
    local actor = ent.actor
    csprite.sx = actor.face_dir

    if self._turn_debounce == 0 then
        local dx = ent.position.x - self.home
        if actor and (actor.touched_wall or dx * actor.move_x > self.max_dist) then
            actor.move_x = -actor.move_x
            self._turn_debounce = 4
        end
    else
        self._turn_debounce = self._turn_debounce - 1
    end
end

return CrawlerEnemy