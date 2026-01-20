local Room = require("game.room")
local Sprite = require("sprite")
local Concord = require("concord")
local fontres = require("fontres")
local consts = require("game.consts")
local Json = require("json")

local ecsconfig = require("game.ecsconfig")
local Dialogue = require("game.dialogue")
local Progression = require("game.progression")
local SoundManager = require("game.sndmgr")
local GameUtil = require("game.util")

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

    local function xsort(a, b)
        return a.x < b.x 
    end

    local function ysort(a, b)
        return a.y < b.y
    end

    for _, map1 in ipairs(world.maps) do
        local conn_rt = {}
        local conn_lf = {}
        local conn_tp = {}
        local conn_bt = {}

        for _, map2 in ipairs(world.maps) do
            if map1 == map2 then
                goto continue
            end

            -- check left/right side
            if map2.y + map2.height > map1.y and map2.y < map1.y + map1.height then
                if map1.x + map1.width == map2.x then
                    table.insert(conn_rt, map2)
                elseif map1.x == map2.x + map2.width then
                    table.insert(conn_lf, map2)
                end
            
            -- check top/bottom side
            elseif map2.x + map2.width > map1.x and map2.x < map1.x + map1.width then
                if map1.y + map1.height == map2.y then
                    table.insert(conn_bt, map2)
                elseif map1.y == map2.y + map2.height then
                    table.insert(conn_tp, map2)
                end
            end

            ::continue::
        end

        table.insertion_sort(conn_rt, ysort)
        table.insertion_sort(conn_lf, ysort)
        table.insertion_sort(conn_tp, xsort)
        table.insertion_sort(conn_bt, xsort)

        local connections = {
            r = {},
            l = {},
            u = {},
            d = {}
        }

        for _, map2 in ipairs(conn_rt) do
            table.insert(connections.r, {
                name = map2.fileName,
                end_pos = map2.y + map2.height - map1.y
            })
        end

        for _, map2 in ipairs(conn_lf) do
            table.insert(connections.l, {
                name = map2.fileName,
                end_pos = map2.y + map2.height - map1.y
            })
        end

        for _, map2 in ipairs(conn_tp) do
            table.insert(connections.u, {
                name = map2.fileName,
                end_pos = map2.x + map2.width - map1.x
            })
        end

        for _, map2 in ipairs(conn_bt) do
            table.insert(connections.d, {
                name = map2.fileName,
                end_pos = map2.x + map2.width - map1.x
            })
        end

        output[map1.fileName] = connections
    end

    return output
end

function Game:new()
    self.music = love.audio.newSource("res/music/goto80_slobban.ogg", "stream")
    self.music:setVolume(0.1)
    self.music:setLooping(true)
    self.music:play()

    ---@type love.Source?
    self.wind_music = nil

    -- load tiled world
    self.tiled_world = Json.decode(love.filesystem.read("res/tiled_world.world"))
    self.room_connections = get_world_room_connections(self.tiled_world)

    self.res = ResourceManager()
    self.sound = SoundManager()
    self.dialogue = Dialogue()

    self.ecs_world = Concord.world()
    self.ecs_world.game = self
    self.ecs_world:addSystems(
        ecsconfig.systems.player_controller,
        ecsconfig.systems.behavior,
        ecsconfig.systems.actor,
        ecsconfig.systems.physics,
        ecsconfig.systems.render,
        ecsconfig.systems.dialogue)
    
    self.ecs_world:setKeyGenerator(function(state)
        return tostring(state), state + 1
    end, 1)

    -- px/ticks^2
    self.gravity = consts.GRAVITY

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
    
    local start_room = consts.START_ROOM
    if Debug.enabled then
        local args = love.parsedGameArguments
        for i=1, #args do
            local arg = args[i]
            if arg == "--room" then
                start_room = args[i+1]
                break
            end
        end
    end

    self:_load_room(start_room)

    for _, obj in ipairs(self.room.tiled_obj_layer.objects) do
        if obj.type == "entity" and obj.name == "player" then
            assert(obj.shape == "rectangle", "entity object is not a rect")

            local x = math.round(obj.x + obj.width / 2.0)
            local y = math.round(obj.y + obj.height / 2.0)

            self:new_entity(true)
                :assemble(ecsconfig.asm.entity.player, self, x, y)
        end
    end

    assert(self.player, "start room did not have a player!")
    self.cam.x = self.player.position.x
    self.cam.y = self.player.position.y

    self.frame = 0

    ---@private
    self._restore_queued = false
    ---@type any?
    self.checkpoint_marker = nil
    ---@private
    ---@type game.OrbData[]
    self._collected_orbs = {}

    ---@private
    self._mountain_bg_sprite = self.res:new_sprite("mountain_bg")

    self:save_state()

    -- if not self.player then
    --     self.player =
    --         self:new_entity()
    --         :assemble(ecsconfig.asm.entity.player, self, 12.0, 12.0)
    -- end
end

function Game:release()
    self:_commit_orbs()

    self.music:stop()
    self.music:release()
    if self.wind_music then
        self.wind_music:stop()
        self.wind_music:release()
    end

    self._mountain_bg_sprite:release()
    
    self.room:release()
    self.res:clear()
    self.sound:release()

    for _, tex in pairs(self._tiled_tex_cache) do
        tex:release()
    end
end

---@param persistent boolean? This entity will not be destroyed when the room is reloaded.
---@return unknown
function Game:new_entity(persistent)
    local e = Concord.entity(self.ecs_world)
    if persistent then
        e:give("room_persistence")
    end

    e:give("key")

    return e
end

---@param dt number
function Game:update(dt)
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
    Debug.draw:push()
    Debug.draw:translate(-cam_x, -cam_y)

    if self.dialogue:is_active() then
        self.dialogue:update()
    else
        self.ecs_world:emit("update", dt)
    end

    Debug.draw:pop()
end

function Game:tick()
    if self._restore_queued then
        self._restore_queued = false
        self:restore_state()
    end

    if self.dialogue:is_active() then
        self.dialogue:tick()
        return
    end

    do
        local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
        local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)
        Debug.draw:push()
        Debug.draw:translate(-cam_x, -cam_y)
    end

    self.ecs_world:emit("tick")

    -- debug fly
    if Debug.enabled and love.keyboard.isDown("lshift") then
        local player = self.player
        local player_vel = player.velocity
        player_vel.x = 0.0
        player_vel.y = -self.gravity

        if love.keyboard.isDown("right") then
            player_vel.x = player_vel.x + 2
        end

        if love.keyboard.isDown("left") then
            player_vel.x = player_vel.x - 2
        end

        if love.keyboard.isDown("up") then
            player_vel.y = player_vel.y - 2
        end

        if love.keyboard.isDown("down") then
            player_vel.y = player_vel.y + 2
        end
    end

    self.sound:update()

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
    local room_width_px = self.room.width * consts.TILE_SIZE
    local room_height_px = self.room.height * consts.TILE_SIZE
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
    self.frame = self.frame + 1
end

function Game:draw()
    local cam_x = math.round(self.cam.x - DISPLAY_WIDTH / 2.0)
    local cam_y = math.round(self.cam.y - DISPLAY_HEIGHT / 2.0)

    if self.room.sky_bg then
        local draw_x = math.round(DISPLAY_WIDTH / 2)
        local draw_y = math.round(DISPLAY_HEIGHT / 2)
        Lg.setColor(1, 1, 1)

        local mtn_y = math.round(draw_y - cam_y / 10.0 + 10.0)

        self._mountain_bg_sprite:drawCel(4, draw_x, draw_y)
        self._mountain_bg_sprite:drawCel(3, draw_x, math.round(draw_y - cam_y / 40.0))
        self._mountain_bg_sprite:drawCel(2, draw_x, mtn_y + 0.5)

        Lg.setColor(P8_PAL.dark_purple)
        Lg.rectangle("fill", 0, math.round(mtn_y + DISPLAY_HEIGHT / 2.0),
                     DISPLAY_WIDTH, DISPLAY_HEIGHT)
    end

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
    self.dialogue:draw()
end

---@private
function Game:_draw_ui()
    -- local mana_percent = self.player.mana.value / self.player.mana.max
    -- Lg.setColor(1, 0, 0)
    -- Lg.rectangle("fill", 0, 0, math.round(DISPLAY_WIDTH * mana_percent), 1)

    Lg.push()
    Lg.translate(0, math.floor(DISPLAY_HEIGHT) - 5)

    local water_img = self.res:get_image("res/graphics/ui/water_5x5.png")
    local rorb_img = self.res:get_image("res/graphics/ui/red_orb_5x5.png")
    local borb_img = self.res:get_image("res/graphics/ui/blue_orb_5x5.png")

    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, 5)
    Lg.setFont(fontres.quinque)

    Lg.setColor(1, 1, 1)
    Lg.draw(water_img, 0, 0)
    Lg.setColor(P8_PAL.white)
    Lg.print(tostring(self.player.mana.value), 6*1, -1)

    local tool = self.player.player_control.selected_tool
    Lg.setColor(P8_PAL.blue)
    Lg.setFont(fontres.quinque)
    if tool == 1 then
        Lg.print("P", 6*5, -1)
    elseif tool == 2 then
        Lg.print("G", 6*5, -1)
    end

    local orb_list = self:list_collected_orbs()
    local red_count, blue_count = GameUtil.count_orbs(orb_list)

    Lg.setColor(1, 1, 1)
    Lg.draw(rorb_img, 6*16, 0)
    Lg.setColor(P8_PAL.white)
    Lg.print(tostring(red_count), 6*17, -1)

    Lg.setColor(1, 1, 1)
    Lg.draw(borb_img, 6*18, 0)
    Lg.setColor(P8_PAL.white)
    Lg.print(tostring(blue_count), 6*19, -1)

    Lg.pop()
end

function Game:save_state()
    self._save_state = {
        player = self.player:get("key").value,
        world = self.ecs_world:serialize(),
        orbs = table.shallow_copy(self._collected_orbs)
    }

    if self._room_transition then
        self._save_state.room_transition = table.shallow_copy(self._room_transition)
    end

    if self.checkpoint_marker then
        self._save_state.checkpoint_marker = self.checkpoint_marker:get("key").value
    end

    -- batteries.pretty.print(self._save_state, { depth = 5 })
end

function Game:restore_state()
    if not self._save_state then
        warn("no state to restore")
        return
    end

    local data = self._save_state

    if data.orbs then
        self._collected_orbs = table.shallow_copy(data.orbs)
    end

    self.ecs_world:deserialize(data.world, true)
    self.player = self.ecs_world:getEntityByKey(data.player)

    if data.room_transition then
        self._room_transition = table.shallow_copy(data.room_transition)
    end

    if data.checkpoint_marker then
        self.checkpoint_marker = self.ecs_world:getEntityByKey(data.checkpoint_marker)
    end
end

function Game:queue_restore()
    self._restore_queued = true
end

---@param t game.OrbData[]?
---@return game.OrbData[]
function Game:list_collected_orbs(t)
    if t then
        table.clear(t)
    else
        t = {}
    end

    for _, v in ipairs(Progression.collected_orbs) do
        table.insert(t, v)
    end
    for _, v in ipairs(self._collected_orbs) do
        table.insert(t, v)
    end

    return t
end

---@param gid string
function Game:is_orb_collected(gid)
    for _, v in ipairs(self._collected_orbs) do
        if v.gid == gid then return true end
    end

    for _, v in ipairs(Progression.collected_orbs) do
        if v.gid == gid then return true end
    end
    
    return false
end

---@param gid string
---@param kind "red"|"blue"
function Game:collect_orb(gid, kind)
    if not (kind == "red" or kind == "blue") then
        softerror("invalid orb kind", 2)
        return
    end
    
    if not softassert(not self:is_orb_collected(gid), "orb already collected") then
        return
    end

    table.insert(self._collected_orbs, { gid = gid, kind = kind })
end

---@param room_name string
function Game:warp_to_room(room_name)
    self:_load_room(room_name)

    for _, obj in ipairs(self.room.tiled_obj_layer.objects) do
        if obj.type == "entity" and obj.name == "player" then
            assert(obj.shape == "rectangle", "entity object is not a rect")

            local x = math.round(obj.x + obj.width / 2.0)
            local y = math.round(obj.y + obj.height / 2.0)

            self.player.position.x = x
            self.player.position.y = y
        end
    end

    self.cam.x = self.player.position.x
    self.cam.y = self.player.position.y
end

---@private
function Game:_commit_orbs()
    local count = 0
    for _, gid in ipairs(self._collected_orbs) do
        table.insert(Progression.collected_orbs, gid)
        count = count + 1
    end

    if count > 0 then
        print(("commited %i orbs"):format(count))
    end
end

---@private
function Game:_unload_room()
    for _, ent in ipairs(self.ecs_world:query({"!room_persistence"})) do
        ent:destroy()
    end

    self.checkpoint_marker = nil

    self:_commit_orbs()

    self.room:release()
    self.room = nil
end

---@private
---@param name string
function Game:_load_room(name)
    if self.room then
        self:_unload_room()
    end

    self._collected_orbs = {}

    self.room_name = name
    self.room = Room(self, get_real_map_path(self.room_name),
                     self._tiled_load_texture_func)

    if self.room.sky_bg then
        self.music:stop()
        self.wind_music = love.audio.newSource("res/music/wind.ogg", "stream")
        self.wind_music:setVolume(0.1)
        self.wind_music:setLooping(true)
        self.wind_music:play()
    elseif self.wind_music then
        self.wind_music:stop()
        self.wind_music:release()
        self.wind_music = nil

        self.music:play()
    end
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

---@param connections {name: string, end_pos: number}[]
---@param pos number
---@return string
local function evaluate_connection(connections, pos)
    for _, cn in ipairs(connections) do
        if pos < cn.end_pos then
            return cn.name
        end
    end

    softerror("invalid connection")
    return connections[#connections].name
end

---@private
function Game:_check_room_transition()
    local player = self.player
    if not player.player_control or not player.player_control.enabled then
        return
    end
    
    local pl_pos = player.position
    local pl_vel = player.velocity

    local room_width_px = self.room.width * consts.TILE_SIZE
    local room_height_px = self.room.height * consts.TILE_SIZE

    local did_switch = false
    local old_room = self.room_name

    local new_room ---@type string?
    local trans_dir ---@type string?

    local p_move = 0.0

    if pl_pos.x > room_width_px then
        new_room = evaluate_connection(self.room_connections[old_room].r,
                                       pl_pos.y)
        trans_dir = "r"
        p_move = 1.0
    elseif pl_pos.x < 0 then
        new_room = evaluate_connection(self.room_connections[old_room].l,
                                       pl_pos.y)
        trans_dir = "l"
        p_move = -1.0
    elseif pl_pos.y > room_height_px then
        new_room = evaluate_connection(self.room_connections[old_room].d,
                                       pl_pos.x)
        trans_dir = "d"
    elseif pl_pos.y < 0 then
        new_room = evaluate_connection(self.room_connections[old_room].u,
                                       pl_pos.x)
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

    if did_switch then
        self.cam.x = pl_pos.x
        self.cam.y = pl_pos.y
    end
end

---@private
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
            
            pl_pos.x = self.room.width * consts.TILE_SIZE - 1
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
            pl_pos.y = self.room.height * consts.TILE_SIZE - 1
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

        self:save_state()
    
    elseif data.phase == 1 then
        self._room_transition = nil
    end
end

return Game