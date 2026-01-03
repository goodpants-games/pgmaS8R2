local Concord = require("concord")
local collision = require("game.collision")
local consts = require("game.consts")
local bit = require("bit")

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

---@param max_pn number?
---@param pos {x: number, y: number}
---@param collider table
---@param vel {x: number, y: number}
---@param colx number
---@param coly number
---@param colw number
---@param colh number
---@return number? pn, number? nx, number? ny
local function test_collision(max_pn, pos, collider, vel, colx, coly, colw, colh)
    local pn, nx, ny =
        collision.rect_rect_intersection(
            pos.x, pos.y, collider.w, collider.h,
            colx, coly, colw, colh)

    if pn
        and (max_pn == nil or pn > max_pn)
        and vel.x * nx + vel.y * ny < 1e-5
    then
        return pn, nx, ny

        -- Debug.draw:color(1, 1, 1)
        -- Debug.draw:rect_lines(colx - colw / 2.0,
        --                         coly - colh / 2.0,
        --                         colw, colh)
    end
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
        local col_pn, col_nx, col_ny

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
                                colx, coly, colw, colh)
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
            pos.x = pos.x + nx * col_pn
            pos.y = pos.y + ny * col_pn

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

    -- apply gravity and perform movement for non-colliding entities
    for _, ent in ipairs(self.pv_pool) do
        local pos = ent.position
        local vel = ent.velocity
        vel.y = vel.y + game.gravity

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
        col._substeps = math.ceil(math.sqrt(vel.x * vel.x + vel.y * vel.y) / 3.0)
        col._substep_idx = 1
        col._iter = 0
        
        if col._substeps > 10 then
            print("entity exceeded substep limit!")
            col._substeps = 10
        end

        if not col._ix then
            col._ix = {}
        end

        if not col._iy then
            col._iy = {}
        end

        -- begin initialization of first substep
        collision_atom(game, ent, pos, col)
        assert(col._iter == 1 and col._substep_idx == 1)
    end

    local ilist = {}
    local ents_to_proc = table.copy(self.pvc_pool) --[[@as (table[])]]
    repeat
        self:_update_edge_lists()

        -- reset collision pass data
        for _, ent in ipairs(ents_to_proc) do
            table.clear(ent.collision._ix)
            table.clear(ent.collision._iy)
        end

        for _, dat in pairs(self.x_overlaps) do
            if dat[1].velocity then
                table.insert(dat[1].collision._ix, dat[2])
            end

            if dat[2].velocity then
                table.insert(dat[2].collision._ix, dat[1])
            end
        end

        for _, dat in pairs(self.y_overlaps) do
            if dat[1].velocity then
                table.insert(dat[1].collision._iy, dat[2])
            end

            if dat[2].velocity then
                table.insert(dat[2].collision._iy, dat[1])
            end
        end

        local is_done = true
        for i=#ents_to_proc, 1, -1 do
            local ent = ents_to_proc[i]
            local pos = ent.position
            local col = ent.collision

            if not col._col_proc then
                table.remove(ents_to_proc, i)
                goto continue
            end

            table.clear(ilist)
            for _, e in ipairs(col._ix) do
                if table.index_of(col._iy, e) then
                    table.insert(ilist, e)
                end
            end

            -- Debug.draw:color(0, 0, 1)
            -- Debug.draw:text(#ilist, pos.x, pos.y)

            if collision_atom(game, ent, pos, col, ilist) then
                is_done = false 
            else
                ent._col_proc = false
                table.remove(ents_to_proc, i)
            end

            ::continue::
        end
    until is_done

    for _, ent in ipairs(self.pvc_pool) do
        table.clear(ent.collision._ix)
        table.clear(ent.collision._iy)
    end

    -- handle newly removed entities
    for ent, _ in pairs(removed_entities) do
        self.prev_entities[ent] = nil
        self:_entity_removed(ent)
    end
end

return system