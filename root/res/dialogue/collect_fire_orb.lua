---@diagnostic disable
local color, game = ...
---@cast game game.Game

local consts = require("game.consts")

if color == "red" then
    say "You collected a fire orb!"
elseif color == "blue" then
    say "You collected a secret fire orb!"
end

local count = 0
local max

if color == "red" then
    max = consts.RED_ORB_COUNT    
elseif color == "blue" then
    max = consts.BLUE_ORB_COUNT
end

for _, v in ipairs(game:list_collected_orbs()) do
    if v.kind == color then
        count = count + 1
    end
end

if count == max then
    say "And that was the last one!"

    if color == "red" then
        say "Return back home to complete the game."
    end
else
    say (("%d more orbs left!"):format(max - count))
end