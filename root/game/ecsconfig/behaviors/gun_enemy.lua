local BaseEnemy = require("game.ecsconfig.behaviors.base_enemy")
local const = require("game.consts")
local bit = require("bit")
local Concord = require("concord")

---@class game.behavior.GunEnemy: game.behavior.BaseEnemy
---@overload fun(props:table):game.behavior.GunEnemy
local GunEnemy = batteries.class {
    name = "game.behavior.GunEnemy",
    extends = BaseEnemy
}

---@param kind nil|"floor"|"ceiling"
---@param props table
function GunEnemy:new(kind, props)
    props = props or {}
    kind = kind or "floor"

    self:super(props)

    self.shoot_cooldown_length = 50
    self.shoot_cooldown = self.shoot_cooldown_length
    self.kind = kind
end

function GunEnemy:init(ent, game, soft_init)
    BaseEnemy.init(self, ent, game, soft_init)
    if soft_init then return end
end

---@param dx number
---@param dy number
function GunEnemy:_shoot(dx, dy)
    local dist = math.sqrt(dx * dx + dy * dy)
    dx = dx / dist
    dy = dy / dist

    local ent = self.entity
    local game = self.game
    local pos = ent.position

    local bullet =
        game:new_entity()
            :give("position", pos.x, pos.y)
            :give("velocity", 2.0 * dx, 2.0 * dy)
            :give("gmult", 0.0)
            :give("collision", 2, 2)
            :give("touch_monitor")
            :give("sprite", game.res:get_image("res/graphics/game/bullet.png"))
            :give("behavior", "enemy_bullet", ent)

    bullet.collision.monitor_only = true
    bullet.collision.mask = bit.bor(const.COLGROUP_DEFAULT, const.COLGROUP_ACTOR)

    return bullet
end

function GunEnemy:tick()
    BaseEnemy.tick(self)
    local ent = self.entity
    
    if self.dead then
        ent.sprite.oy = 0
        ent.sprite.sy = 1
        
        local spr = ent.sprite.obj --[[@as pklove.Sprite]]
        if spr.curAnim ~= "dead" then
            spr:play("dead")
        end
        return
    end
    
    local game = self.game
    local pos = ent.position

    self.shoot_cooldown = self.shoot_cooldown - 1
    if self.shoot_cooldown == 0 then
        self.shoot_cooldown = self.shoot_cooldown_length

        local screen_dx = pos.x - game.cam.x
        local screen_dy = pos.y - game.cam.y
        local screen_dist = math.sqrt(screen_dx * screen_dx + screen_dy * screen_dy)
        if screen_dist < 100 then
            game.sound:play_no_overlap("enemy_shoot")
        end

        ent.sprite.obj:play("fire")

        local count = 8
        for i=1, count do
            local ang = (math.pi * 2.0) * (i / count)
            local dx, dy = math.cos(ang), math.sin(ang)

            if self.kind == "floor" and dy > 0.1 and ent.actor.grounded then
                goto continue
            end

            if self.kind == "ceiling" and dy < -0.1 then
                goto continue
            end

            self:_shoot(dx, dy)
            ::continue::
        end
    end
end

return GunEnemy