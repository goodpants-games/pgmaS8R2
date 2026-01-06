local Room = require("game.room")
local Sprite = require("sprite")
local Concord = require("concord")
local fontres = require("fontres")
local consts = require("game.consts")
local Json = require("json")

local ecsconfig = require("game.ecsconfig")

---@class game.ResourceManager: batteries.Class
---@overload fun():game.ResourceManager
local ResourceManager = batteries.class({ name = "game.ResourceManager" })

function ResourceManager:new()
    ---@type {[string]:pklove.SpriteResource|love.Image}
    self.cache = {}
end

function ResourceManager:clear()
    for _, v in pairs(self.cache) do
        v:release()
    end
    table.clear(self.cache)
end

---@param name string
---@return pklove.SpriteResource
function ResourceManager:get_sprite_res(name)
    local path = ("res/sprites/%s.json"):format(name)
    local res = self.cache[path]
    if not res then
        res = Sprite.loadResource(path)
        self.cache[path] = res
    end
    assert(Sprite.isSpriteResource(res), "not a SpriteResource")
    ---@cast res pklove.SpriteResource
    return res
end

---@param path string
---@return love.Image
function ResourceManager:get_image(path)
    local res = self.cache[path]
    if not res then
        res = Lg.newImage(path)
        self.cache[path] = res
    end
    assert(res.typeOf and res:typeOf("Image"), "not an Image")
    ---@cast res love.Image
    return res
end

function ResourceManager:new_sprite(name)
    local res = self:get_sprite_res(name)
    return Sprite.new(res)
end




---@class game.Game: batteries.Class
---@field player any
---@overload fun():game.Game
local Game = batteries.class({ name = "game.Game" })

---@param tmx_path string
local function get_real_map_path(tmx_path)
    local lua_path = tmx_path
        :gsub("%.tmx$", ".lua")
        :gsub("//+", "/")
        :gsub("^/", "")
    
    return "res/" .. lua_path
end

local function get_world_room_connections(world)
    local output = {}

    for _, map1 in ipairs(world.maps) do
        local connections = {}

        for _, map2 in ipairs(world.maps) do
            if map1 == map2 then
                goto continue
            end

            local map2_name = map2.fileName

            if map2.y + map2.height > map1.y and map2.y < map1.y + map1.height then
                if map1.x + map1.width == map2.x then
                    connections.r = map2_name
                elseif map1.x == map2.x + map2.width then
                    connections.l = map2_name
                end
            
            elseif map2.x + map2.width > map1.x and map2.x < map1.x + map1.width then
                if map1.y + map1.height == map2.y then
                    connections.d = map2_name
                elseif map1.y == map2.y + map2.height then
                    connections.u = map2_name
                end
            end

            ::continue::
        end

        output[map1.fileName] = connections
    end

    return output
end

function Game:new()
    -- load tiled world
    self.tiled_world = Json.decode(love.filesystem.read("res/tiled_world.world"))
    self.room_connections = get_world_room_connections(self.tiled_world)

    batteries.pretty.print(self.room_connections)

    self.res = ResourceManager()

    ---@private
    self._ecs_ents = {}

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.behavior,
        ecsconfig.systems.actor,
        ecsconfig.systems.physics,
        ecsconfig.systems.render)

    -- px/ticks^2
    self.gravity = 0.1

    self.cam = {
        x = 0.0,
        y = 0.0
    }

    ---@private
    ---@type {[string]:love.Image}
    self._tiled_tex_cache = {}

    ---@private
    ---@param texturePath string
    self._tiled_load_texture_func = function(texturePath)
        local texture = self._tiled_tex_cache[texturePath]
        if texture == nil then
            texture = Lg.newImage(texturePath)
            self._tiled_tex_cache[texturePath] = texture
        end
        return texture
    end

    self:_load_room("maps/testmap.tmx")

    for _, obj in ipairs(self.room.tiled_obj_layer.objects) do
        if obj.type == "entity" and obj.name == "player" then
            assert(obj.shape == "rectangle", "entity object is not a rect")

            local x = math.round(obj.x + obj.width / 2.0)
            local y = math.round(obj.y + obj.height / 2.0)

            self:new_entity()
                :assemble(ecsconfig.asm.entity.player, self, x, y)
        end
    end

    assert(self.player, "start room did not have a player!")
    self.cam.x = self.player.position.x
    self.cam.y = self.player.position.y

    -- if not self.player then
    --     self.player =
    --         self:new_entity()
    --         :assemble(ecsconfig.asm.entity.player, self, 12.0, 12.0)
    -- end
end

function Game:release()
    self.room:release()
    self.res:clear()

    for _, tex in pairs(self._tiled_tex_cache) do
        tex:release()
    end
end

function Game:new_entity()
    local e = Concord.entity(self.ecs_world)
    table.insert(self._ecs_ents, e)
    return e
end

---@param dt number
function Game:update(dt)
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
    Debug.draw:push()
    Debug.draw:scale(2.0, 2.0)
    Debug.draw:translate(-cam_x, -cam_y)

    self.ecs_world:emit("update", dt)

    Debug.draw:pop()
end

function Game:tick()
    do
        local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
        local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
        Debug.draw:push()
        Debug.draw:scale(2.0, 2.0)
        Debug.draw:translate(-cam_x, -cam_y)
    end

    self.ecs_world:emit("tick")

    if self._room_transition then
        self._room_transition.ticks = self._room_transition.ticks + 1
        if self._room_transition.ticks >= 30 then
            self:_finish_room_transition_phase()
        end
    else
        self:_check_room_transition()
    end

    local cam_x = self.cam.x
    local cam_y = self.cam.y
    local pl_x = self.player.position.x
    local pl_y = self.player.position.y
    local room_width_px = self.room.width * consts.TILE_WIDTH
    local room_height_px = self.room.height * consts.TILE_HEIGHT
    local xbound = 8
    local ybound = 8

    cam_x = math.clamp(cam_x, pl_x - xbound, pl_x + xbound)
    cam_y = math.clamp(cam_y, pl_y - ybound, pl_y + ybound)

    self.cam.x =
        math.clamp(math.round(cam_x),
                   DISPLAY_WIDTH / 2.0,
                   room_width_px - DISPLAY_WIDTH / 2.0)
    self.cam.y =
        math.clamp(math.round(cam_y),
                   DISPLAY_HEIGHT / 2.0,
                   room_height_px - DISPLAY_HEIGHT / 2.0 + 5)

    -- self.cam.x = math.floor(self.player.position.x / 120) * 120 + DISPLAY_WIDTH / 2.0
    -- self.cam.y = math.floor(self.player.position.y / 88) * 88 + DISPLAY_HEIGHT / 2.0

    Debug.draw:pop()
end

function Game:draw()
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)

    Lg.push()
    Lg.translate(-cam_x, -cam_y)

    Debug.draw:push()
    Debug.draw:translate(-cam_x, -cam_y)

    self.room:draw()
    self.ecs_world:emit("draw")

    Lg.pop()
    Debug.draw:pop()

    if self._room_transition then
        local a = self._room_transition.ticks / 20
        a = math.clamp01(a)
        if self._room_transition.phase == 0 then
            a = 1.0 - a
        end

        Lg.setBlendMode("multiply", "premultiplied")
        Lg.setColor(a, a, a)
        Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT)
        Lg.setBlendMode("alpha")
    end

    self:_draw_ui()
end

---@private
function Game:_draw_ui()
    -- local mana_percent = self.player.mana.value / self.player.mana.max
    -- Lg.setColor(1, 0, 0)
    -- Lg.rectangle("fill", 0, 0, math.round(DISPLAY_WIDTH * mana_percent), 1)

    Lg.push()
    Lg.translate(0, math.floor(DISPLAY_HEIGHT) - 5)

    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, 5)
    Lg.setColor(P8_PAL.white)
    Lg.setFont(fontres.quinque)
    Lg.print(("WTR:%i"):format(self.player.mana.value), 0, -1)

    Lg.pop()
end

---@private
function Game:_unload_room()
    for i=#self._ecs_ents, 1, -1 do
        local ent = self._ecs_ents[i]
        if ent ~= self.player then
            ent:destroy()
            table.remove(self._ecs_ents, i)
        end
    end

    self.room:release()
    self.room = nil
end

---@private
---@param name string
function Game:_load_room(name)
    if self.room then
        self:_unload_room()
    end

    self.room_name = name
    self.room = Room(self, get_real_map_path(self.room_name),
                     self._tiled_load_texture_func)
end

---@private
---@param room_name string
---@return table?
function Game:_get_room_world_data(room_name)
    for _, v in ipairs(self.tiled_world.maps) do
        if v.fileName == room_name then
            return v
        end
    end

    return nil
end

---@private
function Game:_check_room_transition()
    local player = self.player
    local pl_pos = player.position
    local pl_vel = player.velocity

    local room_width_px = self.room.width * consts.TILE_WIDTH
    local room_height_px = self.room.height * consts.TILE_HEIGHT

    local did_switch = false
    local old_room = self.room_name

    local new_room ---@type string?
    local trans_dir ---@type string?

    local p_move = 0.0

    if pl_pos.x > room_width_px then
        new_room = self.room_connections[old_room].r
        trans_dir = "r"
        p_move = 1.0
    elseif pl_pos.x < 0 then
        new_room = self.room_connections[old_room].l
        trans_dir = "l"
        p_move = -1.0
    elseif pl_pos.y > room_height_px then
        new_room = self.room_connections[old_room].d
        trans_dir = "d"
    elseif pl_pos.y < 0 then
        new_room = self.room_connections[old_room].u
        trans_dir = "u"
    end

    if new_room then
        assert(trans_dir)
        self._room_transition = {
            phase = 0,
            ticks = 0,
            new_room = new_room,
            dir = trans_dir,
            px = pl_pos.x,
            py = pl_pos.y,
            pmv = p_move,
            pdir = self.player.actor.face_dir,
        }
    end

    -- if pl_pos.x > room_width_px then
    --     new_room = self.room_connections[old_room].r
    --     if new_room then
    --         self:_load_room(new_room)
    --         did_switch = true

    --         self._level_transition = {
    --             new_room = new_room,
    --         }

    --         local old_room_data = assert(self:_get_room_world_data(old_room))
    --         local new_room_data = assert(self:_get_room_world_data(new_room))
    --         pl_pos.x = 1
    --         pl_pos.y = pl_pos.y - new_room_data.y + old_room_data.y
    --     end
    
    -- elseif pl_pos.x < 0 then
    --     local new_room = self.room_connections[old_room].l
    --     if new_room then
    --         self:_load_room(new_room)
    --         did_switch = true
            
    --         local old_room_data = assert(self:_get_room_world_data(old_room))
    --         local new_room_data = assert(self:_get_room_world_data(new_room))
    --         pl_pos.x = self.room.width * consts.TILE_WIDTH - 1
    --         pl_pos.y = pl_pos.y - new_room_data.y + old_room_data.y
    --     end
    
    -- elseif pl_pos.y > room_height_px then
    --     local new_room = self.room_connections[old_room].d
    --     if new_room then
    --         self:_load_room(new_room)
    --         did_switch = true

    --         local old_room_data = assert(self:_get_room_world_data(old_room))
    --         local new_room_data = assert(self:_get_room_world_data(new_room))
    --         pl_pos.x = pl_pos.x - new_room_data.x + old_room_data.x
    --         pl_pos.y = 1
    --     end

    -- elseif pl_pos.y < 0 then
    --     local new_room = self.room_connections[old_room].u
    --     if new_room then
    --         self:_load_room(new_room)
    --         did_switch = true

    --         local old_room_data = assert(self:_get_room_world_data(old_room))
    --         local new_room_data = assert(self:_get_room_world_data(new_room))
    --         pl_pos.x = pl_pos.x - new_room_data.x + old_room_data.x
    --         pl_pos.y = self.room.height * consts.TILE_HEIGHT - 1

    --         pl_vel.y = -2.0
    --     end
    -- end

    if did_switch then
        self.cam.x = pl_pos.x
        self.cam.y = pl_pos.y
    end
end

function Game:_finish_room_transition_phase()
    local data = self._room_transition

    if data.phase == 0 then
        local old_room = self.room_name
        local new_room = data.new_room
        local pl_pos = self.player.position
        local pl_vel = self.player.velocity
        local px = data.px
        local py = data.py
        local pmv = data.pmv

        if data.dir == "r" then
            self:_load_room(new_room)
            local old_room_data = assert(self:_get_room_world_data(old_room))
            local new_room_data = assert(self:_get_room_world_data(new_room))
            pl_pos.x = 1.0
            pl_pos.y = py - new_room_data.y + old_room_data.y
            pl_vel.x = 0.0
            pl_vel.y = 0.0
            pmv = 1.0
        
        elseif data.dir == "l" then
            self:_load_room(new_room)
            local old_room_data = assert(self:_get_room_world_data(old_room))
            local new_room_data = assert(self:_get_room_world_data(new_room))
            
            pl_pos.x = self.room.width * consts.TILE_WIDTH - 1
            pl_pos.y = py - new_room_data.y + old_room_data.y
            pl_vel.x = 0.0
            pl_vel.y = 0.0
            pmv = -1.0
        
        elseif data.dir == "d" then
            self:_load_room(new_room)
            local old_room_data = assert(self:_get_room_world_data(old_room))
            local new_room_data = assert(self:_get_room_world_data(new_room))

            pl_pos.x = px - new_room_data.x + old_room_data.x
            pl_pos.y = -6.0
            pl_vel.x = 0.0
            pl_vel.y = 0.0
            pmv = 0.0

        elseif data.dir == "u" then
            self:_load_room(new_room)
            local old_room_data = assert(self:_get_room_world_data(old_room))
            local new_room_data = assert(self:_get_room_world_data(new_room))

            pl_pos.x = px - new_room_data.x + old_room_data.x
            pl_pos.y = self.room.height * consts.TILE_HEIGHT - 1
            pl_vel.x = 0.0
            pl_vel.y = -2.0
            pmv = data.pdir
        end

        self.cam.x = pl_pos.x
        self.cam.y = pl_pos.y

        self._room_transition = {
            phase = 1,
            ticks = 0,
            pmv = pmv
        }
    
    elseif data.phase == 1 then
        self._room_transition = nil
    end
end

return Game