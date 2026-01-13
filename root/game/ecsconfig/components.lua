local Concord = require("concord")
local Sprite = require("sprite")
local consts = require("game.consts")
local GameUtil = require("game.util")

Concord.component("room_persistence")
Concord.component("remove_on_checkpoint")

Concord.component("position", function(cmp, x, y)
    cmp.x = x or 0.0
    cmp.y = y or 0.0
end)

Concord.component("rotation", function(cmp, ang)
    cmp.ang = ang or 0.0
end)

Concord.component("velocity", function(cmp, xv, yv)
    cmp.x = xv or 0.0
    cmp.y = yv or 0.0
end)

Concord.component("damping", function(cmp, xf, yf)
    cmp.x = xf or 0.8
    cmp.y = yf or 1.0
end)

Concord.component("gmult", function(cmp, mult)
    cmp.value = mult or 1.0
end)

Concord.component("mass", function(cmp, v)
    cmp.value = v or 1.0
end)

Concord.component("spring", function(cmp, yv)
    cmp.yv = assert(yv, "spring component must be initialized with a y-vel")
end)

-- collision hitbox
Concord.component("collision", function(cmp, w, h)
    cmp.w = w
    cmp.h = h
    cmp.group = consts.COLGROUP_DEFAULT
    cmp.mask = consts.COLGROUP_ALL
    cmp.floor_only = false
    cmp.monitor_only = false
    cmp.in_water = false
end)

local function touch_monitor_init(cmp)
    cmp.touching = {}
    cmp.touched_tilemap = false

    cmp._prev_touching = {}
    cmp._prev_touched_tilemap = false
end

local touch_monitor = Concord.component("touch_monitor", touch_monitor_init)
function touch_monitor:serialize() return {} end
touch_monitor.deserialize = touch_monitor_init


Concord.component("actor", function(cmp)
    cmp.move_x = 0
    cmp.face_dir = 1

    cmp.jump_trigger = 0
    
    -- px/tick
    cmp.move_speed = GameUtil.accel_damp_at_speed(1.0, 0.8)
    cmp.jump_velocity = 2.0

    cmp.grounded = false
    cmp.touched_wall = false
end)

Concord.component("player_control", function(cmp)
    cmp.move_x = 0.0
    cmp.move_y = 0.0
    cmp.jump_trigger = false
    cmp.drop_trigger = 0
    cmp.selected_tool = 1
    cmp.action_sink = false
    cmp.state = "move"
end)

Concord.component("mana", function(cmp, max, init)
    cmp.value = max
    cmp.max = init or max
end)

Concord.component("health", function(cmp, max, init)
    cmp.value = max
    cmp.max = init or max
end)

local sprite = Concord.component("sprite", function(cmp, obj)
    cmp.obj = obj
    cmp.r = 1
    cmp.g = 1
    cmp.b = 1
    cmp.a = 1
    cmp.sx = 1
    cmp.sy = 1
    cmp.ox = 0
    cmp.oy = 0
    cmp.visible = true
    cmp.z_index = 0
end)

function sprite:serialize()
    local data = Concord.component.serialize(self)

    if self.obj and Sprite.isSprite(self.obj) then
        data.obj_type = "sprite"
        data.obj = table.shallow_copy(self.obj)
    end

    return data
end

function sprite:deserialize(data)
    Concord.component.deserialize(self, data)

    if data.obj_type == "sprite" then
        local spr = Sprite.new(data.obj.res)
        for k, v in pairs(data.obj) do
            spr[k] = v
        end
        self.obj = spr
    end

    self.obj_type = nil
end


local behavior = Concord.component("behavior", function(cmp, behav_name, ...)
    local behav = require("game.ecsconfig.behaviors." .. behav_name)
    cmp.inst = behav(...)
    cmp._behav_name = behav_name
end)

function behavior:serialize()
    return {
        name = self._behav_name,
        data = self.inst:serialize()
    }
end

function behavior:deserialize(data)
    if self._behav_name and self.inst then
        if self._behav_name ~= data.name then
            softerror("deserialize behavior type mismatch!")
        else
            self.inst:deserialize(data.data)
        end
    else
        self._behav_name = data.name
        local behav = require("game.ecsconfig.behaviors." .. data.name)
        self.inst = setmetatable({}, behav)
        self.inst:deserialize(data.data)
    end
end