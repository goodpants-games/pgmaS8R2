local Concord = require("concord")
local collision = require("game.collision")
local consts = require("game.consts")
local bit = require("bit")

local system = Concord.system({
    pv_pool = {"position", "velocity"},
    p_pool = {"position"},
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

local function sort_edge_list(list)
    for i=2, #list do
        local j = i
        while list[j].pos < list[j-1].pos do
            list[j], list[j-1] = list[j-1], list[j]
            j=j-1
            if j == 1 then break end
        end
    end
end

function system:init()
    self.prev_entities = {}

    self.edge_list_x = {}
    self.edge_list_y = {}
end

function system:_entity_added(ent)
    print("new entity!")

    table.insert(self.edge_list_x, { ent = ent, pos = 0.0, side = 0 })
    table.insert(self.edge_list_x, { ent = ent, pos = 0.0, side = 1 })
    table.insert(self.edge_list_y, { ent = ent, pos = 0.0, side = 0 })
    table.insert(self.edge_list_y, { ent = ent, pos = 0.0, side = 1 })
end

function system:_entity_removed(ent)
    print("he was Destroyed!")

    local xedge = self.edge_list_x
    local yedge = self.edge_list_y

    for i=#xedge, 1, -1 do
        if xedge[i].ent == ent then
            table.remove(xedge, i)
        end
    end

    for i=#yedge, 1, -1 do
        if yedge[i].ent == ent then
            table.remove(yedge, i)
        end
    end
end

function system:_update_edge_lists()
    local xedges = self.edge_list_x
    local yedges = self.edge_list_y

    -- update edge positions
    for _, edge in ipairs(xedges) do
        local ent = edge.ent
        local pos = ent.position
        local col = ent.collision

        if edge.side == 0 then
            edge.pos = pos.x - col.w / 2.0    
        else
            edge.pos = pos.x + col.w / 2.0
        end
    end

    for _, edge in ipairs(yedges) do
        local ent = edge.ent
        local pos = ent.position
        local col = ent.collision

        if edge.side == 0 then
            edge.pos = pos.y - col.h / 2.0    
        else
            edge.pos = pos.y + col.h / 2.0
        end
    end

    sort_edge_list(xedges)
    sort_edge_list(yedges)
end

---@param ent any
---@param edges {ent: any, pos: number, side: integer}[]
---@param out {[any]:boolean}
local function prune(ent, edges, out)
    table.clear(out)

    for i=1, #edges do
        if edges[i].ent == ent then
            assert(edges[i].side == 0)

            local j = i+1
            while edges[j].ent ~= ent or edges[j].side ~= 1 do
                out[edges[j].ent] = true
                j=j+1
            end
            break
        end
    end
end

---@param ent any
function system:_move_and_collide(ent)
    local game = self:getWorld().game --[[@as game.Game]]

    local xedges = self.edge_list_x
    local yedges = self.edge_list_y

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

    local substeps = math.ceil(math.sqrt(vel.x * vel.x + vel.y * vel.y) / 1.0)

    -- print(substeps)
    if substeps > 10 then
        print("entity exceeded max substeps!")
        substeps = 10
    end

    local broadphase_x = {}
    local broadphase_y = {}

    local col_pn, col_nx, col_ny
    local function test_collision(colx, coly, colw, colh)
        local pn, nx, ny =
            collision.rect_rect_intersection(
                pos.x, pos.y, collider.w, collider.h,
                colx, coly, colw, colh)

        if pn
            and (col_pn == nil or pn > col_pn)
            and vel.x * nx + vel.y * ny < 1e-5
        then
            col_pn, col_nx, col_ny = pn, nx, ny

            -- Debug.draw:color(1, 1, 1)
            -- Debug.draw:rect_lines(colx - colw / 2.0,
            --                         coly - colh / 2.0,
            --                         colw, colh)
            return true
        end
        return false
    end

    for sub=1, substeps do
        local s_vx = vel.x / substeps
        local s_vy = vel.y / substeps

        pos.x = pos.x + s_vx
        pos.y = pos.y + s_vy
        self:_update_edge_lists()

        local had_collision = false

        for iter=1, 4 do
            -- find collision with largest penetration
            local cx = -1
            local cy = -1
            col_pn, col_nx, col_ny = nil, nil, nil

            -- first, scan tiles
            if bit.band(collider.mask, 1) ~= 0 then
                local minx = math.floor((pos.x - cxe + margin) / tw)
                local maxx = math.ceil((pos.x + cxe - margin) / th)
                local miny = math.floor((pos.y - cye + margin) / tw)
                local maxy = math.ceil((pos.y + cye - margin) / th)

                for y=miny, maxy-1 do
                    for x=minx, maxx-1 do
                        local v = game.room:get_col(x, y)
                        if v ~= 0 then
                            local colx, coly, colw, colh =
                                get_tile_collision_bounds(x, y, tw, th, v)
                            if test_collision(colx, coly, colw, colh) then
                                cx = x
                                cy = y
                            end
                        end
                    end
                end
            end

            -- scan for entity collisions
            prune(ent, xedges, broadphase_x)
            prune(ent, yedges, broadphase_y)
            for other_ent, _ in pairs(broadphase_x) do
                if broadphase_y[other_ent] then
                    local other_pos = other_ent.position
                    local other_col = other_ent.collision

                    if bit.band(collider.mask, other_col.group) ~= 0 then
                        local colx = other_pos.x
                        local coly = other_pos.y
                        local colw = other_col.w
                        local colh = other_col.h

                        test_collision(colx, coly, colw, colh)
                        Debug.draw:color(1, 0, 0)
                        Debug.draw:point(pos.x, pos.y)
                    end
                end
            end

            if col_pn then
                had_collision = true

                Debug.draw:color(1, 0, 0)
                Debug.draw:rect_lines(cx * tw, cy * th, tw, th)
                
                local nx, ny = col_nx, col_ny
                pos.x = pos.x + nx * col_pn
                pos.y = pos.y + ny * col_pn
                self:_update_edge_lists()

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

        if had_collision
           and math.abs(vel.x) < 1e-4
           and math.abs(vel.y) < 1e-4
        then
            break
        end
    end
end

function system:tick()
    if love.keyboard.isDown("y") then
        print("Start")
        for i, v in ipairs(self.edge_list_x) do
            print(v.ent, v.pos, v.side)
        end
        print("Stop")
    end

    local game = self:getWorld().game --[[@as game.Game]]

    local removed_entities = {}
    for k, _ in pairs(self.prev_entities) do
        removed_entities[k] = true
    end

    -- handle newly added entities
    for _, ent in ipairs(self.p_pool) do
        removed_entities[ent] = nil
        if not self.prev_entities[ent] then
            self.prev_entities[ent] = true
            self:_entity_added(ent)
        end
    end

    -- perform kinematics and collision resolution
    for _, ent in ipairs(self.pv_pool) do
        local pos = ent.position
        local vel = ent.velocity

        vel.y = vel.y + game.gravity

        if ent.collision then
            self:_move_and_collide(ent)
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

    -- handle newly removed entities
    for ent, _ in pairs(removed_entities) do
        self.prev_entities[ent] = nil
        self:_entity_removed(ent)
    end
end

return system