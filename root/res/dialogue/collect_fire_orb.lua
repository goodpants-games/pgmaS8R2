---@diagnostic disable
local color, game = ...
---@cast game game.Game

local consts = require("game.consts")
local count = 0
local max, required

if color == "red" then
    max, required = consts.RED_ORB_COUNT, consts.REQUIRED_RED_ORBS
elseif color == "blue" then
    max, required = consts.BLUE_ORB_COUNT
end

for _, v in ipairs(game:list_collected_orbs()) do
    if v.kind == color then
        count = count + 1
    end
end

if color == "red" then
    if count == max then
        say "Wow! You found all red fire orbs!"
        say "You may return back home to complete the game."
    elseif count > required then
        say "You found an extra fire orb!"
        say "You may return back home to complete the game."
    elseif count == required then
        say "You found the last necessary fire orb!"
        say "You may return back home to complete the game."
    else
        say "You found a fire orb!"
        say (("%d more orbs left!"):format(required - count))
    end

elseif color == "blue" then
    if count == max then
        say "Wow! You found all of the secret orbs!"
        say "Awesome!"
    else
        say "You found a secret fire orb!"
        say (("%d more orbs left!"):format(max - count))
    end
end