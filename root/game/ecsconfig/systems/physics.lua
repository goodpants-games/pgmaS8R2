local Concord = require("concord")
local collision = require("game.collision")
local consts = require("game.consts")

local system = Concord.system({
    pool = {"position", "velocity"}
})

local function get_tile_collision_bounds(cx, cy, tw, th, colv)
    local colx, coly, colw, colh
    if colv == 1 then
        colx = (cx+0.5) * tw
        coly = (cy+0.5) * th
        colw = tw
        colh = th
    elseif colv == 2 then
        colx = (cx+0.5) * tw
        coly = (cy+0.75) * th
        colw = tw
        colh = th / 2
    else
        error("unknown collision type " .. colv)
    end

    return colx, coly, colw, colh
end

---@param ent any
---@param game game.Game
local function move_and_collide(ent, game)
    local pos = assert(ent.position)
    local vel = assert(ent.velocity)
    local collider = assert(ent.collision)
    local actor = ent.actor

    local cxe = collider.w / 2 -- collider x extents
    local cye = collider.h / 2 -- collider y extents

    local tw, th = consts.TILE_WIDTH, consts.TILE_HEIGHT
    local margin = collision.margin

    if actor then
        actor.grounded = false
    end

    local substeps = math.ceil(math.sqrt(vel.x * vel.x + vel.y * vel.y) / 2.0)

    if substeps > 10 then
        print("entity exceeded max substeps!")
        substeps = 10
    end

    local s_vx = vel.x / substeps
    local s_vy = vel.y / substeps

    for sub=1, substeps do
        pos.x = pos.x + s_vx
        pos.y = pos.y + s_vy

        for _=1, 4 do
            local minx = math.floor((pos.x - cxe + margin) / tw)
            local maxx = math.ceil((pos.x + cxe - margin) / th)
            local miny = math.floor((pos.y - cye + margin) / tw)
            local maxy = math.ceil((pos.y + cye - margin) / th)

            -- find collision with largest penetration
            local cx = -1
            local cy = -1
            local col_pn, col_nx, col_ny

            for y=miny, maxy-1 do
                for x=minx, maxx-1 do
                    local v = game.room:get_col(x, y)
                    if v ~= 0 then
                        local colx, coly, colw, colh =
                            get_tile_collision_bounds(x, y, tw, th, v)
                        local pn, nx, ny =
                            collision.rect_rect_intersection(
                                pos.x, pos.y, collider.w, collider.h,
                                colx, coly, colw, colh)

                        if pn
                           and (col_pn == nil or pn > col_pn)
                           and s_vx * nx + s_vy * ny < 0.0
                        then
                            cx = x
                            cy = y
                            col_pn, col_nx, col_ny = pn, nx, ny

                            Debug.draw:color(1, 1, 1)
                            Debug.draw:rect_lines(colx - colw / 2.0,
                                                  coly - colh / 2.0,
                                                  colw, colh)
                        end

                        -- if dist < cell_min_dist then
                        --     cell_value = v
                        --     cx = x
                        --     cy = y
                        --     cell_min_dist = dist
                        -- end
                    end
                end
            end

            if col_pn then
                Debug.draw:color(1, 0, 0)
                Debug.draw:rect_lines(cx * tw, cy * th, tw, th)
                
                local nx, ny = col_nx, col_ny
                pos.x = pos.x + nx * col_pn
                pos.y = pos.y + ny * col_pn

                local pdot = -nx * vel.x + -ny * vel.y
                vel.x = vel.x + nx * pdot
                vel.y = vel.y + ny * pdot

                if actor and ny < -math.sqrt(2) / 2 then
                    actor.grounded = true
                end
            else
                break
            end
        end
    end
end

function system:tick()
    local game = self:getWorld().game --[[@as game.Game]]

    for _, ent in ipairs(self.pool) do
        local pos = ent.position
        local vel = ent.velocity

        vel.y = vel.y + game.gravity

        if ent.collision then
            move_and_collide(ent, game)
            if Debug.enabled then
                Debug.draw:color(0.0, 1.0, 0.0)
                local cw, ch = ent.collision.w, ent.collision.h
                Debug.draw:rect_lines(pos.x - cw / 2.0, pos.y - ch / 2.0,
                                      cw, ch)
            end
        else
            pos.x = pos.x + vel.x
            pos.y = pos.y + vel.y
        end
    end
end

return system