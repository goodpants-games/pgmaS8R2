local sceneman = require("sceneman")
local Base = require("game.ecsconfig.behaviors.base")
local const = require("game.consts")

---@class game.behavior.Home: game.behavior.Base
local Home = batteries.class {
    name = "game.behavior.Home",
    extends = Base
}

function Home:msg_interact()
    local game = self.game

    local red_count = 0
    for _, v in ipairs(game:list_collected_orbs()) do
        if v.kind == "red" then
            red_count = red_count + 1
        end
    end

    if red_count == const.RED_ORB_COUNT then
        print("game finished")
        sceneman.switchScene("game_end")
    else
        game.dialogue:start("home_unfinished")
    end
end

return Home