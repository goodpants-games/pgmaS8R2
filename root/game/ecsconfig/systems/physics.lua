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
    self.edge_list_x = {}
    self.edge_list_y = {}
    self.x_overlaps = {}
    self.y_overlaps = {}

    self.ent_ids = {}
    self.next_ent_id = 1

    function self.pc_pool.onAdded(_, ent)
        self:_entity_added(ent)
    end

    function self.pc_pool.onRemoved(_, ent)
        self:_entity_removed(ent)
    end
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

function system:_entity_new_substep(ent)
    local pos = ent.position
    local vel = ent.velocity
    local collider = ent.collision
    local proc = self.ent_proc[ent]

    if proc._substep_idx > proc._substeps then
        proc._mvx = 0
        proc._mvy = 0
        return false
    end

    -- begin substep
    local s_vx = vel.x / proc._substeps
    local s_vy = vel.y / proc._substeps

    pos.x = pos.x + s_vx
    pos.y = pos.y + s_vy

    proc._mvx = s_vx
    proc._mvy = s_vy

    proc._substep_idx = proc._substep_idx + 1
    proc._iter = 1
    proc._had_collision = false
    return true
end

function system:tick()
    local game = self:getWorld().game --[[@as game.Game]]
    self.ent_proc = {}

    -- apply gravity, damping, and perform movement for non-colliding entities
    for _, ent in ipairs(self.pv_pool) do
        local pos = ent.position
        local vel = ent.velocity
        local damping = ent.damping
        local gmult = ent.gmult

        local gmult_v = 1.0
        if gmult then
            gmult_v = gmult.value
        end

        vel.y = vel.y + game.gravity * gmult_v
        
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

        local extra = {}

        extra._col_proc = true
        extra._substeps = math.ceil(math.sqrt(vel.x * vel.x + vel.y * vel.y) / 1.0)
        extra._substep_idx = 1
        extra._iter = 0
        
        if extra._substeps > 10 then
            print("entity exceeded substep limit!")
            extra._substeps = 10
        end

        self.ent_proc[ent] = extra

        -- if not col._ix then
        --     col._ix = {}
        -- end

        -- if not col._iy then
        --     col._iy = {}
        -- end

        -- begin initialization of first substep
        self:_entity_new_substep(ent)
        -- assert(col._iter == 1 and col._substep_idx == 1)
    end

    -- local ilist = {}
    local ents_to_proc = table.copy(self.pvc_pool) --[[@as (table[])]]
    local col_queue = PriorityQueue("max")
    local moved = {}

    local tsz = consts.TILE_SIZE
    local margin = collision.margin

    -- clear touch monitors
    for _, ent in ipairs(self.pc_pool) do
        local touch_monitor = ent.touch_monitor
        if touch_monitor then
            table.clear(touch_monitor.touching)
            touch_monitor.touched_tilemap = false
        end
    end

    repeat
        local is_done = true

        for i=#ents_to_proc, 1, -1 do
            local ent = ents_to_proc[i]
            if self:_entity_new_substep(ent) then
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

                    if     bit.band(col1.mask, col2.group) ~= 0
                       or  bit.band(col2.mask, col1.group) ~= 0
                    then
                        local tm1, tm2 = e1.touch_monitor, e2.touch_monitor

                        if tm1 and not table.index_of(tm1.touching, e2) then
                            table.insert(tm1.touching, e2)
                        end

                        if tm2 and not table.index_of(tm2.touching, e1) then
                            table.insert(tm2.touching, e1)
                        end

                        if not (col1.monitor_only or col2.monitor_only) then
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

                local minx = math.floor((pos.x - cxe + margin) / tsz)
                local maxx = math.ceil((pos.x + cxe - margin) / tsz)
                local miny = math.floor((pos.y - cye + margin) / tsz)
                local maxy = math.ceil((pos.y + cye - margin) / tsz)

                for y=miny, maxy-1 do
                    for x=minx, maxx-1 do
                        local v = game.room:get_col(x, y)
                        if v ~= 0 and v ~= 2 then
                            local colx, coly, colw, colh =
                                get_tile_collision_bounds(x, y, tsz, tsz, v)
                            
                            local pn, nx, ny =
                                test_collision(pos, collider, vel,
                                               colx, coly, colw, colh, 0, 0)
                            if pn then
                                if ent.touch_monitor then
                                    ent.touch_monitor.touched_tilemap = true
                                end
                                
                                if not collider.monitor_only then
                                    col_queue:enqueue({
                                        ent, nil, pn, nx, ny
                                    }, math.abs(pn) + 1000)
                                end
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
                local proc = self.ent_proc[e1]

                local o_pos, o_vel, o_actor, o_proc
                if e2 then
                    o_pos = e2.position
                    o_vel = e2.velocity
                    o_actor = e2.actor
                    o_proc = self.ent_proc[e2]
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

                local mvx1, mvy1 = proc._mvx, proc._mvy
                local mvx2, mvy2
                if o_proc then
                    mvx2, mvy2 = o_proc._mvx, o_proc._mvy
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

                    if o_proc then
                        o_proc._mvx = o_proc._mvx - nx * mdir
                        o_proc._mvy = o_proc._mvy - ny * mdir
                    end
                else
                    pos.x = pos.x + nx * pn
                    pos.y = pos.y + ny * pn

                    proc._mvx = proc._mvx + nx * math.min(1000, o_mdir)
                    proc._mvy = proc._mvy + ny * math.min(1000, o_mdir)
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

                if ny < -FLOOR_ANGLE then
                    if actor then
                        actor.grounded = true
                    end

                    if e2 and e2.spring then
                        print("spring A")
                        vel.y = -e2.spring.yv
                    end
                end

                if ny > FLOOR_ANGLE then
                    if o_actor then
                        o_actor.grounded = true
                    end

                    if e1.spring and o_vel then
                        print("spring B")
                        o_vel.y = -e1.spring.yv
                    end
                end

                ::continue::
            end
        end
    until is_done

    -- dispatch touch_began/touch_ended events to entity behaviors
    for _, ent in ipairs(self.pc_pool) do
        local touch_monitor = ent.touch_monitor
        local behavior = ent.behavior
        if touch_monitor and behavior and behavior.inst then
            local binst = behavior.inst
            local tilemap_touch_changed = touch_monitor._prev_touched_tilemap ~= touch_monitor.touched_tilemap

            if binst.touch_began then
                for _, now_touched in ipairs(touch_monitor.touching) do
                    if not touch_monitor._prev_touching[now_touched] then
                        print("entity Touch began")
                        binst:touch_began(now_touched)
                    end
                end

                if tilemap_touch_changed and touch_monitor.touched_tilemap then
                    print("tilemap Touch began")
                    binst:touch_began(nil)
                end
            end

            if binst.touch_ended then
                for then_touched, _ in pairs(touch_monitor._prev_touching) do
                    if not table.index_of(touch_monitor.touching, then_touched) then
                        print("entity Touch ended")
                        binst:touch_ended(then_touched)
                    end
                end

                if tilemap_touch_changed and not touch_monitor.touched_tilemap then
                    print("tilemap Touch ended")
                    binst:touch_ended(nil)
                end
            end

            touch_monitor._prev_touched_tilemap = touch_monitor.touched_tilemap
            table.clear(touch_monitor._prev_touching)
            for _, e in ipairs(touch_monitor.touching) do
                touch_monitor._prev_touching[e] = true
            end
        end
    end

    -- set in water status
    for _, ent in ipairs(self.pc_pool) do
        local position = ent.position
        local velocity = ent.velocity
        local col = ent.collision
        local tx = math.floor(position.x / consts.TILE_SIZE)
        local ty = math.floor(position.y / consts.TILE_SIZE)

        local col_type = game.room:get_col(tx, ty)
        col.in_water = col_type and col_type == 2
    end

    -- water buoyancy
    for _, ent in ipairs(self.pvc_pool) do
        local vel = ent.velocity
        local col = ent.collision

        if col.in_water then
            local mass = 1.0
            local mass_c = ent.mass
            if mass_c then
                mass = mass_c.value
            end

            vel.y = vel.y * 0.8
            vel.y = vel.y - game.gravity - 0.06 / mass
        end
    end
end

return system