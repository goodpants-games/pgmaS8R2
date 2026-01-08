local Concord = require("concord")
local consts = require("game.consts")

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

Concord.component("touch_monitor", function(cmp)
    cmp.touching = {}
end)

Concord.component("actor", function(cmp)
    cmp.move_x = 0
    cmp.face_dir = 1

    cmp.jump_trigger = 0
    
    -- px/tick
    cmp.move_speed = 0.28
    cmp.jump_velocity = 2.0

    cmp.grounded = false
end)

Concord.component("player_control", function(cmp)
    cmp.move_x = 0.0
    cmp.jump_trigger = false
    cmp.up_drop_trigger = 0
    cmp.side_drop_trigger = 0
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

Concord.component("sprite", function(cmp, obj)
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
end)

Concord.component("behavior", function(cmp, behav_name, ...)
    local behav = require("game.ecsconfig.behaviors." .. behav_name)
    cmp.inst = behav(...)
end)