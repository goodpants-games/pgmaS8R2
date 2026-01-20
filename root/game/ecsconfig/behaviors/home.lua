local sceneman = require("sceneman")
local Base = require("game.ecsconfig.behaviors.base")
local GameUtil = require("game.util")
local const = require("game.consts")

---@class game.behavior.Home: game.behavior.Base
local Home = batteries.class {
    name = "game.behavior.Home",
    extends = Base
}

function Home:msg_interact()
    local game = self.game

    local red_count = GameUtil.count_orbs(game:list_collected_orbs())

    if red_count >= const.REQUIRED_RED_ORBS then
        print("game finished")
        sceneman.switchScene("game_end")
    else
        game.dialogue:start("home_unfinished")
    end
end

return Home