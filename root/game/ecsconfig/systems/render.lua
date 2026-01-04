local Concord = require("concord")
local Sprite = require("sprite")

local system = Concord.system({
    sprite_pool = {"position", "sprite"}
})

function system:tick()
    for _, ent in ipairs(self.sprite_pool) do
        local sprite = ent.sprite
        local drawable = sprite.obj

        if Sprite.isSprite(drawable) then
            ---@cast drawable pklove.Sprite
            drawable:update(GAME_TICK_LENGTH)
        end
    end
end

function system:draw()
    for _, ent in ipairs(self.sprite_pool) do
        local sprite = ent.sprite
        local position = ent.position --[[@as {x:number, y:number}]]
        local rotation = ent.rotation

        local rotv = 0.0
        if rotation then
            rotv = rotation.ang
        end

        local drawable = sprite.obj
        local draw_x = math.round(position.x + sprite.ox)
        local draw_y = math.round(position.y + sprite.oy)

        Lg.setColor(sprite.r, sprite.g, sprite.b, sprite.a)

        if not drawable then
            local collision = assert(ent.collision, "expected collision component")
            Lg.rectangle("fill",
                         draw_x - collision.w / 2.0,
                         draw_y - collision.h / 2.0,
                         collision.w, collision.h)
        elseif Sprite.isSprite(drawable) then
            ---@cast drawable pklove.Sprite
            drawable:draw(draw_x, draw_y, rotv, sprite.sx, sprite.sy)
        else
            ---@cast drawable love.Image
            Lg.draw(drawable, draw_x, draw_y, rotv, sprite.sx, sprite.sy,
                    math.round(drawable:getWidth() / 2.0),
                    math.round(drawable:getHeight() / 2.0))
        end
    end
end

return system