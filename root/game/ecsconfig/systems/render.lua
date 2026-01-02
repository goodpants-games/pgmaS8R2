local Concord = require("concord")
local Sprite = require("sprite")

local system = Concord.system({
    sprite_pool = {"position", "sprite"}
})

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

        if Sprite.isSprite(drawable) then
            ---@cast drawable pklove.Sprite
            drawable:draw(draw_x, draw_y, rotv, sprite.sx, sprite.sy)
        else
            ---@cast drawable love.Image
            Lg.draw(drawable, draw_x, draw_y, rotv, sprite.sx, sprite.sy)
        end
    end
end

return system