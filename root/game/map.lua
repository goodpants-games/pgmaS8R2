---@class game.Map: batteries.Class
---@overload fun(world:table, start_room_name:string):game.Map
local Map = batteries.class {
    name = "game.Map"
}

---@class game._MapRoom
---@field name string
---@field x number
---@field y number
---@field width number
---@field height number
---@field visited boolean
---@field inner_visited boolean[]
---@field screens boolean[]

local const = require("game.consts")
local Input = require("input")

local MAP_SCREEN_WIDTH = 15 * 8
local MAP_SCREEN_HEIGHT = 11 * 8
local MAP_GRID_SIZE = 16
local MAP_SCREEN_SUBDIV = 2

---@param game game.Game
---@param start_room_name string
function Map:new(game, start_room_name)
    local start_room

    self.game = game
    local world = game.tiled_world
    
    for _, map in ipairs(world.maps) do
        assert(map.width % MAP_SCREEN_WIDTH == 0)
        assert(map.height % MAP_SCREEN_HEIGHT == 0)

        if map.fileName == start_room_name then
            start_room = map
        end
    end

    assert(start_room, "start room was not found")

    ---@type game._MapRoom[]
    self.rooms = {}

    for _, map in ipairs(world.maps) do
        local map_x = (map.x - start_room.x) / MAP_SCREEN_WIDTH
        local map_y = (map.y - start_room.y) / MAP_SCREEN_HEIGHT
        local map_w = map.width / MAP_SCREEN_WIDTH
        local map_h = map.height / MAP_SCREEN_HEIGHT

        assert(map_x % 1 == 0)
        assert(map_y % 1 == 0)
        assert(map_w % 1 == 0)
        assert(map_h % 1 == 0)

        local inner_visited = {}
        local screens = {}
        for i=1, map_w * map_h * MAP_SCREEN_SUBDIV * MAP_SCREEN_SUBDIV do
            inner_visited[i] = false
            screens[i] = true
        end

        table.insert(self.rooms, {
            name = map.fileName,
            x = map_x,
            y = map_y,
            width = map.width / MAP_SCREEN_WIDTH,
            height = map.height / MAP_SCREEN_HEIGHT,
            visited = false,
            inner_visited = inner_visited,
            screens = screens
        })
    end

    self.cam_x = 0.0
    self.cam_y = 0.0
end

function Map:release()
    
end

---@private
---@param name string
---@return game._MapRoom? room
---@return integer? index
function Map:_get_room_by_name(name)
    for i, room in ipairs(self.rooms) do
        if room.name == name then
            return room, i
        end
    end
end

function Map:reset()
    local room = self:_get_room_by_name(self.game.room_name)
    if not room then
        softerror(("could not find room %s"):format(self.game.room_name))
        room = assert(self:_get_room_by_name(const.START_ROOM))
    end

    self.cam_x = (room.x + room.width / 2.0) * MAP_GRID_SIZE
    self.cam_y = (room.y + room.height / 2.0) * MAP_GRID_SIZE
end

---@param dt number
function Map:update(dt)

end

function Map:tick()
    local move_x, move_y = Input.players[1]:get("move")
    self.cam_x = self.cam_x + move_x
    self.cam_y = self.cam_y + move_y
end

---@param room game._MapRoom
---@param ox number
---@param oy number
local function draw_room(room, ox, oy)
    local grid_size = MAP_GRID_SIZE / MAP_SCREEN_SUBDIV
    local rw = room.width * MAP_SCREEN_SUBDIV
    local rh = room.height * MAP_SCREEN_SUBDIV

    local i = 1
    for y=1, rh do
        for x=1, rw do
            if room.inner_visited[i] and room.screens[i] then
                local draw_x = ox + (x - 1) * grid_size
                local draw_y = oy + (y - 1) * grid_size

                Lg.setColor(P8_PAL.red)
                Lg.rectangle("fill", draw_x, draw_y, grid_size, grid_size)

                local adj_l = x > 1
                local adj_r = x < rw
                local adj_t = y > 1
                local adj_b = y < rh
                local adj_tl = adj_l and adj_t
                local adj_tr = adj_t and adj_r
                local adj_bl = adj_l and adj_b
                local adj_br = adj_b and adj_r

                if adj_l then
                    adj_l = room.screens[(y-1) * rw + (x-2) + 1]
                end

                if adj_r then
                    adj_r = room.screens[(y-1) * rw + (x) + 1]
                end

                if adj_t then
                    adj_t = room.screens[(y-2) * rw + (x-1) + 1]
                end

                if adj_b then
                    adj_b = room.screens[(y) * rw + (x-1) + 1]
                end

                if adj_tl then
                    adj_tl = room.screens[(y-2) * rw + (x-2) + 1]
                end

                if adj_tr then
                    adj_tr = room.screens[(y-2) * rw + (x) + 1]
                end

                if adj_bl then
                    adj_bl = room.screens[(y) * rw + (x-2) + 1]
                end

                if adj_br then
                    adj_br = room.screens[(y) * rw + (x) + 1]
                end

                Lg.setColor(P8_PAL.white)
                if not adj_l then
                    Lg.rectangle("fill", draw_x, draw_y, 1, grid_size)
                end

                if not adj_t then
                    Lg.rectangle("fill", draw_x, draw_y, grid_size, 1)
                end

                if not adj_r then
                    Lg.rectangle("fill",
                                 draw_x + grid_size - 1, draw_y,
                                 1, grid_size)
                end

                if not adj_b then
                    Lg.rectangle("fill", draw_x, draw_y + grid_size - 1,
                                 grid_size, 1)
                end

                if not adj_tl then
                    Lg.rectangle("fill", draw_x, draw_y, 1, 1)
                end

                if not adj_tr then
                    Lg.rectangle("fill", draw_x + grid_size - 1, draw_y, 1, 1)
                end

                if not adj_bl then
                    Lg.rectangle("fill", draw_x, draw_y + grid_size - 1, 1, 1)
                end

                if not adj_br then
                    Lg.rectangle("fill", draw_x + grid_size - 1, draw_y + grid_size - 1, 1, 1)
                end
            end

            i = i + 1
        end
    end
end

function Map:draw()
    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)

    local ox = math.round(DISPLAY_WIDTH / 2.0)
    local oy = math.round(DISPLAY_HEIGHT / 2.0)

    Lg.push()
    Lg.translate(-math.round(self.cam_x), -math.round(self.cam_y))

    for _, room in ipairs(self.rooms) do
        if room.visited then
            local draw_x = room.x * MAP_GRID_SIZE + ox
            local draw_y = room.y * MAP_GRID_SIZE + oy

            draw_room(room, draw_x, draw_y)

            -- Lg.setColor(P8_PAL.red)
            -- Lg.rectangle("fill", draw_x, draw_y, draw_w, draw_h)

            -- Lg.setColor(P8_PAL.white)
            -- Lg.setLineWidth(1.0)
            -- Lg.rectangle("line", draw_x + 0.5, draw_y + 0.5, draw_w - 1.0, draw_h - 1.0)
        end
    end

    Lg.pop()
end

---@param room game._MapRoom
function Map:_fill_collision_data(room)
    print("fill collision data")

    local game_room = self.game.room
    local cell_w = MAP_SCREEN_WIDTH / MAP_SCREEN_SUBDIV / 8.0
    local cell_h = MAP_SCREEN_HEIGHT / MAP_SCREEN_SUBDIV / 8.0

    local i = 1
    for r=1, room.height * MAP_SCREEN_SUBDIV do
        local start_y = math.floor((r-1) * cell_h)
        local end_y = math.floor(start_y + cell_h)

        for c=1, room.width * MAP_SCREEN_SUBDIV do
            local start_x = math.floor((c-1) * cell_w) + 2
            local end_x = math.floor(start_x + cell_w) - 2

            assert(room.screens[i] ~= nil)

            local scr_available = false
            for y=start_y, end_y do
                assert(y >= 0 and y < game_room.height)
                for x=start_x, end_x do
                    assert(x >= 0 and x < game_room.width)
                    if game_room:get_col(x, y) ~= 1 then
                        scr_available = true
                        goto break_cell_scan
                    end
                end
            end
            ::break_cell_scan::

            room.screens[i] = scr_available
            i = i + 1
        end
    end
end

---@param visit_all boolean?
function Map:visit_tick(visit_all)
    local room_name = self.game.room_name
    local view_x, view_y = self.game.cam.x, self.game.cam.y
    local view_w, view_h = DISPLAY_WIDTH * (2/3), DISPLAY_HEIGHT * (2/3)

    local room = self:_get_room_by_name(room_name)
    if not room then
        return
    end

    if not room.visited then
        self:_fill_collision_data(room)
    end

    room.visited = true

    if visit_all then
        for i=1, #room.inner_visited do
            room.inner_visited[i] = true
        end
    end

    local view_l = math.floor((view_x - view_w / 2.0) / (MAP_SCREEN_WIDTH / MAP_SCREEN_SUBDIV))
    local view_t = math.floor((view_y - view_h / 2.0) / (MAP_SCREEN_HEIGHT / MAP_SCREEN_SUBDIV))
    local view_r = math.floor((view_x + view_w / 2.0) / (MAP_SCREEN_WIDTH / MAP_SCREEN_SUBDIV))
    local view_b = math.floor((view_y + view_h / 2.0) / (MAP_SCREEN_HEIGHT / MAP_SCREEN_SUBDIV))

    local w = room.width * MAP_SCREEN_SUBDIV
    local h = room.height * MAP_SCREEN_SUBDIV

    for y=view_t, view_b do
        for x=view_l, view_r do
            if x >= 0 and x < w and y >= 0 and y < h then
                local i = y * w + x + 1
                room.inner_visited[i] = true
            end
        end
    end

end

return Map