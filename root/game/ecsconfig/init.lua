local Concord = require("concord")
require("game.ecsconfig.components")

local ecsconfig = {}
ecsconfig.systems = {}
ecsconfig.asm = require("game.ecsconfig.assemblages")

Concord.utils.loadNamespace("game/ecsconfig/systems", ecsconfig.systems)
Concord.utils.loadNamespace("game/ecsconfig/behaviors", ecsconfig.behaviors)

return ecsconfig