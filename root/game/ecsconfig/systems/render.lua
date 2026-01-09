local Concord = require("concord")
local Sprite = require("sprite")

local system = Concord.system({
    sprite_pool = {"position", "sprite"}
})

function system:init()
    self._render_list = {}

    function self.sprite_pool.onAdded(_, ent)
        table.insert(self._render_list, ent)
    end

    function self.sprite_pool.onRemoved(_, ent)
        table.remove_value(self._render_list, ent)
    end
end

local function z_index_sort_less(a, b)
    return a.sprite.z_index < b.sprite.z_index
end

function system:tick()
    table.insertion_sort(self._render_list, z_index_sort_less)

    for _, ent in ipairs(self._render_list) do
        local sprite = ent.sprite
        local drawable = sprite.obj

        if Sprite.isSprite(drawable) then
            ---@cast drawable pklove.Sprite
            drawable:update(GAME_TICK_LENGTH)
        end
    end
end

function system:draw()
    for _, ent in ipairs(self._render_list) do
        local sprite = ent.sprite
        if not sprite.visible then
            goto continue
        end
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
        elseif type(drawable) == "function" then
            ---@cast drawable function
            Lg.push()
            Lg.translate(draw_x, draw_y)
            Lg.rotate(rotv)
            drawable(ent, sprite)
            Lg.pop()
        elseif Sprite.isSprite(drawable) then
            ---@cast drawable pklove.Sprite
            drawable:draw(draw_x, draw_y, rotv, sprite.sx, sprite.sy)
        elseif drawable.typeOf and drawable:typeOf("Texture") then
            ---@cast drawable love.Texture
            Lg.draw(drawable, draw_x, draw_y, rotv, sprite.sx, sprite.sy,
                    math.round(drawable:getWidth() / 2.0),
                    math.round(drawable:getHeight() / 2.0))
        else
            softerror("sprite component's drawable object is not a sprite, texture, or function!")
        end
        
        ::continue::
    end
end

return system