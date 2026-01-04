local Concord = require("concord")
local collision = require("game.collision")
local consts = require("game.consts")
local bit = require("bit")
local PriorityQueue = require("ds.priority_queue")

local FLOOR_ANGLE = math.sqrt(2) / 2

local system = Concord.system({
    pv_pool = {"position", "velocity"},
    pvc_pool = {"position", "velocity", "collision"},
    pc_pool = {"position", "collision"},
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

---unordered unsigned tuple pair
---@param x integer
---@param y integer
---@return integer
local function upair2u(x, y)
    if y < x then
        x, y = y, x
    end

    if x >= y then
        return (x * x) + x + y
    else
        return (y * y) + x
    end
end

local function remove_from_overlap_list(list, ent)
    local to_remove = {}
    for k, v in pairs(list) do
        if v[1] == ent or v[2] == ent then
            table.insert(to_remove, k)
        end
    end

    for _, k in ipairs(to_remove) do
        list[k] = nil
    end
end

function system:init()
    self.prev_entities = {}

    self.edge_list_x = {}
    self.edge_list_y = {}
    self.x_overlaps = {}
    self.y_overlaps = {}

    self.ent_ids = {}
    self.next_ent_id = 1
end

function system:_entity_added(ent)
    print("new entity!")

    table.insert(self.edge_list_x, { ent = ent, pos = 0.0, left = true })
    table.insert(self.edge_list_x, { ent = ent, pos = 0.0, left = false })
    table.insert(self.edge_list_y, { ent = ent, pos = 0.0, left = true })
    table.insert(self.edge_list_y, { ent = ent, pos = 0.0, left = false })

    self.ent_ids[ent] = self.next_ent_id
    self.next_ent_id = self.next_ent_id + 1
end

function system:_entity_removed(ent)
    print("he was Destroyed!")

    self.ent_ids[ent] = nil

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

    remove_from_overlap_list(self.x_overlaps, ent)
    remove_from_overlap_list(self.y_overlaps, ent)
end

function system:_sort_edge_list(list, out)
    local ids = self.ent_ids

    for i=2, #list do
        local j = i - 1
        while list[j].pos > list[j+1].pos do
            list[j], list[j+1] = list[j+1], list[j]

            local edge1 = list[j]
            local edge2 = list[j+1]

            -- R-L -> L-R
            local k = upair2u(ids[edge1.ent], ids[edge2.ent])
            if edge1.left and not edge2.left then
                -- print("new overlap", ids[edge1.ent], ids[edge2.ent])
                local t = out[k]
                if t then
                    t[1] = edge1.ent
                    t[2] = edge2.ent
                else
                    out[k] = {edge1.ent, edge2.ent}
                end
            
            -- L-R > R-L
            elseif not edge1.left and edge2.left then
                -- print("remove overlap", ids[edge1.ent], ids[edge2.ent])
                out[k] = nil
            end

            j=j-1
            if j == 0 then break end
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

        if edge.left then
            edge.pos = pos.x - col.w / 2.0
        else
            edge.pos = pos.x + col.w / 2.0
        end
    end

    for _, edge in ipairs(yedges) do
        local ent = edge.ent
        local pos = ent.position
        local col = ent.collision

        if edge.left then
            edge.pos = pos.y - col.h / 2.0    
        else
            edge.pos = pos.y + col.h / 2.0
        end
    end

    self:_sort_edge_list(xedges, self.x_overlaps)
    self:_sort_edge_list(yedges, self.y_overlaps)
end

---@param pos {x: number, y: number}
---@param collider table
---@param vel {x: number, y: number}
---@param colx number
---@param coly number
---@param colw number
---@param colh number
---@param colvx number
---@param colvy number
---@return number? pn, number? nx, number? ny
local function test_collision(pos, collider, vel, colx, coly, colw, colh, colvx, colvy)
    local pn, nx, ny =
        collision.rect_rect_intersection(
            pos.x, pos.y, collider.w, collider.h,
            colx, coly, colw, colh)

    if pn and (vel.x - colvx) * nx + (vel.y - colvy) * ny < 1e-5 then
        return pn, nx, ny
        -- Debug.draw:color(1, 1, 1)
        -- Debug.draw:rect_lines(colx - colw / 2.0,
        --                         coly - colh / 2.0,
        --                         colw, colh)
    end
end

local function entity_new_substep(ent)
    local pos = ent.position
    local vel = ent.velocity
    local collider = ent.collision

    if collider._substep_idx > collider._substeps then
        collider._mvx = 0
        collider._mvy = 0
        return false
    end

    -- begin substep
    local s_vx = vel.x / collider._substeps
    local s_vy = vel.y / collider._substeps

    pos.x = pos.x + s_vx
    pos.y = pos.y + s_vy

    collider._mvx = s_vx
    collider._mvy = s_vy

    collider._substep_idx = collider._substep_idx + 1
    collider._iter = 1
    collider._had_collision = false
    return true
end

---@param game game.Game
---@param ent table
---@param pos {x: number, y: number}
---@param collider table
---@param intersecting table[]?
---@return boolean
local function collision_atom(game, ent, pos, collider, intersecting)
    if collider._substep_idx > collider._substeps then
        return false
    end

    local vel = ent.velocity

    -- begin substep
    if collider._iter == 0 then
        local s_vx = vel.x / collider._substeps
        local s_vy = vel.y / collider._substeps

        pos.x = pos.x + s_vx
        pos.y = pos.y + s_vy

        collider._iter = 1
        collider._had_collision = false
        return true
    end

    if collider._iter <= 4 then
        assert(intersecting, "intersecting is nil")

        -- begin iteration within substep
        local cxe = collider.w / 2 -- collider x extents
        local cye = collider.h / 2 -- collider y extents

        local tw, th = consts.TILE_WIDTH, consts.TILE_HEIGHT
        local margin = collision.margin

        -- find collision with largest penetration
        local cx = -1
        local cy = -1
        local col_pn, col_nx, col_ny, col_ent

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
                        
                        local pn, nx, ny =
                            test_collision(
                                col_pn, pos, collider, vel,
                                colx, coly, colw, colh, 0, 0)
                        if pn then
                            col_pn, col_nx, col_ny = pn, nx, ny
                        end
                    end
                end
            end
        end

        -- scan for entity collisions
        for _, other_ent in ipairs(intersecting) do
            local other_pos = other_ent.position
            local other_col = other_ent.collision

            if bit.band(collider.mask, other_col.group) ~= 0 then
                local colx = other_pos.x
                local coly = other_pos.y
                local colw = other_col.w
                local colh = other_col.h
                
                local pn, nx, ny = test_collision(
                    col_pn, pos, collider, vel,
                    colx, coly, colw, colh)
                if pn then
                    col_pn, col_nx, col_ny = pn, nx, ny
                    col_ent = other_ent
                    Debug.draw:color(1, 0, 0)
                    Debug.draw:point(pos.x, pos.y)
                end

            end
        end

        if col_pn then
            collider._had_collision = true

            Debug.draw:color(1, 0, 0)
            Debug.draw:rect_lines(cx * tw, cy * th, tw, th)
            
            local nx, ny = col_nx, col_ny
            if col_ent and col_ent.velocity then
                local other_pos = col_ent.position
                
                other_pos.x = other_pos.x - nx * col_pn / 2.0
                other_pos.y = other_pos.y - ny * col_pn / 2.0
                pos.x = pos.x + nx * col_pn / 2.0
                pos.y = pos.y + ny * col_pn / 2.0
            else
                pos.x = pos.x + nx * col_pn
                pos.y = pos.y + ny * col_pn
            end

            local pdot = -nx * vel.x + -ny * vel.y
            vel.x = vel.x + nx * pdot
            vel.y = vel.y + ny * pdot

            local actor = ent.actor
            if actor and ny < -math.sqrt(2) / 2 then
                actor.grounded = true
            end
        else
            goto post_substep
        end

        collider._iter = collider._iter + 1
        return true
    end

    ::post_substep::
    if collider._had_collision
        and math.abs(vel.x) < 1e-4
        and math.abs(vel.y) < 1e-4
    then
        return false
    end

    collider._iter = 0
    collider._substep_idx = collider._substep_idx + 1

    return collider._substep_idx <= collider._substeps
end

function system:tick()
    local game = self:getWorld().game --[[@as game.Game]]

    local removed_entities = {}
    for k, _ in pairs(self.prev_entities) do
        removed_entities[k] = true
    end

    -- handle newly added entities
    for _, ent in ipairs(self.pc_pool) do
        removed_entities[ent] = nil
        if not self.prev_entities[ent] then
            self.prev_entities[ent] = true
            self:_entity_added(ent)
        end
    end

    -- apply gravity, damping, and perform movement for non-colliding entities
    for _, ent in ipairs(self.pv_pool) do
        local pos = ent.position
        local vel = ent.velocity
        local damping = ent.damping

        vel.y = vel.y + game.gravity
        if damping then
            vel.x = vel.x * damping.x
            vel.y = vel.y * damping.y
        end

        if not ent.collision then
            pos.x = pos.x + vel.x
            pos.y = pos.y + vel.y
        end
    end

    -- begin collision
    for _, ent in ipairs(self.pvc_pool) do
        local pos = ent.position
        local vel = ent.velocity
        local col = ent.collision

        if ent.actor then
            ent.actor.grounded = false
        end

        col._col_proc = true
        col._substeps = math.ceil(math.sqrt(vel.x * vel.x + vel.y * vel.y) / 1.0)
        col._substep_idx = 1
        col._iter = 0
        
        if col._substeps > 10 then
            print("entity exceeded substep limit!")
            col._substeps = 10
        end

        -- if not col._ix then
        --     col._ix = {}
        -- end

        -- if not col._iy then
        --     col._iy = {}
        -- end

        -- begin initialization of first substep
        entity_new_substep(ent)
        -- assert(col._iter == 1 and col._substep_idx == 1)
    end

    -- local ilist = {}
    local ents_to_proc = table.copy(self.pvc_pool) --[[@as (table[])]]
    local col_queue = PriorityQueue("max")
    local moved = {}

    local tw, th = consts.TILE_WIDTH, consts.TILE_HEIGHT
    local margin = collision.margin

    repeat
        local is_done = true

        for i=#ents_to_proc, 1, -1 do
            local ent = ents_to_proc[i]
            if entity_new_substep(ent) then
                is_done = false
            else
                table.remove(ents_to_proc, i)
            end
        end

        for _=1, 8 do
            self:_update_edge_lists()

            -- reset collision pass data
            -- for _, ent in ipairs(ents_to_proc) do
            --     table.clear(ent.collision._ix)
            --     table.clear(ent.collision._iy)
            -- end

            col_queue:clear()
            table.clear(moved)

            -- collect entity/entity collisions
            for k, dat in pairs(self.x_overlaps) do
                if self.y_overlaps[k] then
                    local e1, e2 = dat[1], dat[2]
                    if not e1.velocity then
                        e1, e2 = e2, e1

                        -- collisions between static objects are not meaningful
                        -- so don't bother
                        if not e1.velocity then
                            goto continue
                        end
                    end

                    local pos1, pos2 = e1.position, e2.position
                    local col1, col2 = e1.collision, e2.collision
                    local vel1, vel2 = e1.velocity, e2.velocity

                    if    bit.band(col1.mask, col2.group) ~= 0
                       or bit.band(col2.mask, col1.group) ~= 0
                    then
                        local cx2 = pos2.x
                        local cy2 = pos2.y
                        local cw2 = col2.w
                        local ch2 = col2.h

                        local v2x, v2y = 0, 0
                        if vel2 then
                            v2x, v2y = vel2.x, vel2.y
                        end
                        
                        local pn, nx, ny = test_collision(
                            pos1, col1, vel1,
                            cx2, cy2, cw2, ch2, v2x, v2y)
                        if pn then
                            local ent1_is_floor = ny < -FLOOR_ANGLE
                            local ent2_is_floor = ny > FLOOR_ANGLE
                            if not ent1_is_floor and col2.floor_only then
                                goto continue
                            end

                            if not ent2_is_floor and col1.floor_only then
                                goto continue
                            end

                            col_queue:enqueue({
                                e1, e2, pn, nx, ny
                            }, math.abs(pn))
                        end
                    end
                end

                ::continue::
            end

            -- collect entity/tile collisions
            for _, ent in ipairs(self.pvc_pool) do
                local pos = ent.position
                local collider = ent.collision
                local vel = ent.velocity

                local cxe = collider.w / 2 -- collider x extents
                local cye = collider.h / 2 -- collider y extents

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
                            
                            local pn, nx, ny =
                                test_collision(pos, collider, vel,
                                               colx, coly, colw, colh, 0, 0)
                            if pn then
                                col_queue:enqueue({
                                    ent, nil, pn, nx, ny
                                }, math.abs(pn) + 1000)
                            end
                        end
                    end
                end
            end

            if col_queue:is_empty() then
                break
            end

            for item in col_queue:iter() do
                local e1, e2, pn, nx, ny = item[1], item[2], item[3], item[4], item[5]
                if moved[e1] or (e2 and moved[e2]) then
                    goto continue
                end

                moved[e1] = true
                if e2 and e2.velocity then
                    moved[e2] = true
                end

                local pos = e1.position
                local vel = e1.velocity
                local actor = e1.actor
                local col = e1.collision

                local o_pos, o_vel, o_col, o_actor
                if e2 then
                    o_pos = e2.position
                    o_vel = e2.velocity
                    o_col = e2.collision
                    o_actor = e2.actor
                end

                local mass = 0
                if e1.mass then
                    mass = e1.mass.value
                end

                local o_mass = 0
                if not o_vel then
                    o_mass = math.huge
                elseif e2.mass then
                    o_mass = e2.mass.value
                end

                local mvx1, mvy1 = col._mvx, col._mvy
                local mvx2, mvy2
                if o_col then
                    mvx2, mvy2 = o_col._mvx, o_col._mvy
                end

                local mdir = (mvx1 * -nx + mvy1 * -ny) * mass + mass
                local o_mdir
                if mvx2 then
                    o_mdir = (mvx2 * nx + mvy2 * ny) * o_mass + o_mass
                else
                    o_mdir = math.huge
                end

                if mdir == o_mdir then
                    o_pos.x = o_pos.x - nx * pn / 2.0
                    o_pos.y = o_pos.y - ny * pn / 2.0
                    pos.x = pos.x + nx * pn / 2.0
                    pos.y = pos.y + ny * pn / 2.0
                elseif mdir > o_mdir then
                    o_pos.x = o_pos.x - nx * pn
                    o_pos.y = o_pos.y - ny * pn

                    if o_col then
                        o_col._mvx = o_col._mvx - nx * mdir
                        o_col._mvy = o_col._mvy - ny * mdir
                    end
                else
                    pos.x = pos.x + nx * pn
                    pos.y = pos.y + ny * pn

                    col._mvx = col._mvx + nx * math.min(1000, o_mdir)
                    col._mvy = col._mvy + ny * math.min(1000, o_mdir)
                end

                if o_vel then
                    local pdot = nx * vel.x + ny * vel.y
                    local o_pdot = nx * o_vel.x + ny * o_vel.y

                    local mto1 = ((o_pdot * o_mass - pdot * mass) / mass)
                    local mto2 = ((pdot * mass - o_pdot * o_mass) / o_mass)

                    if mto1 < 0.0 then mto1 = 0.0 end
                    if mto2 > 0.0 then mto2 = 0.0 end

                    vel.x = vel.x + nx * mto1
                    vel.y = vel.y + ny * mto1
                    o_vel.x = o_vel.x + nx * mto2
                    o_vel.y = o_vel.y + ny * mto2
                else
                    local pdot = -nx * vel.x + -ny * vel.y
                    vel.x = vel.x + nx * pdot
                    vel.y = vel.y + ny * pdot
                end

                    -- local pdot = nx * other_vel.x + ny * other_vel.y
                    -- other_vel.x = other_vel.x + -nx * pdot
                    -- other_vel.y = other_vel.y + -ny * pdot
                -- else
                --     pos.x = pos.x + nx * pn
                --     pos.y = pos.y + ny * pn

                --     local pdot = -nx * vel.x + -ny * vel.y
                --     vel.x = vel.x + nx * pdot
                --     vel.y = vel.y + ny * pdot
                -- end

                if actor and ny < -FLOOR_ANGLE then
                    actor.grounded = true
                end

                if o_actor and ny > FLOOR_ANGLE then
                    o_actor.grounded = true
                end

                ::continue::
            end
        end

        -- print(entity_col_queue:len() + tile_col_queue:len())

        -- local is_done = true
        -- for i=#ents_to_proc, 1, -1 do
        --     local ent = ents_to_proc[i]
        --     local pos = ent.position
        --     local col = ent.collision

        --     if not col._col_proc then
        --         table.remove(ents_to_proc, i)
        --         goto continue
        --     end

        --     table.clear(ilist)
        --     for _, e in ipairs(col._ix) do
        --         if table.index_of(col._iy, e) then
        --             table.insert(ilist, e)
        --         end
        --     end

        --     -- Debug.draw:color(0, 0, 1)
        --     -- Debug.draw:text(#ilist, pos.x, pos.y)

        --     if collision_atom(game, ent, pos, col, ilist) then
        --         is_done = false 
        --     else
        --         ent._col_proc = false
        --         table.remove(ents_to_proc, i)
        --     end

        --     ::continue::
        -- end
    until is_done

    -- for _, ent in ipairs(self.pvc_pool) do
    --     table.clear(ent.collision._ix)
    --     table.clear(ent.collision._iy)
    -- end

    -- handle newly removed entities
    for ent, _ in pairs(removed_entities) do
        self.prev_entities[ent] = nil
        self:_entity_removed(ent)
    end
end

return system