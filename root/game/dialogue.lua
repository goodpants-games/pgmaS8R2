local Input = require("input")
local fontres = require("fontres")

---@class game.Dialogue: batteries.Class
---@overload fun():game.Dialogue
local Dialogue = batteries.class {
    name = "game.Dialogue",
}

function Dialogue:new()
    self._func_cache = {}

    local base_env = table.shallow_copy(_G) --[[@as table]]
    function base_env.say(text)
        _, self._lines = self._font:getWrap(text, DISPLAY_WIDTH)
        self._line_start = 1
        self._lines_remaining = math.max(0, #self._lines)
        coroutine.yield("advance")
    end

    base_env.page_size = "auto"

    ---@private
    self._base_env = base_env

    ---@private
    self._font = fontres.quinque

    ---@private
    ---@type thread?
    self._coro = nil

    ---@private
    ---@type table?
    self._func_env = nil

    ---@private
    ---@type string[]?
    self._lines = nil

    ---@private
    self._line_start = 1
    ---@private
    self._lines_remaining = 0

    ---@private
    ---@type nil|"advance"
    self._wait_reason = nil

    ---@private
    self._action_advance = false
end

---@param name string
function Dialogue:preload(name)
    if self._func_cache[name] == nil then
        self:_load_file(name)
    end
end

---@param name string
---@param ... any
function Dialogue:start(name, ...)
    print("trigger dialogue")

    local chunk = self._func_cache[name] or self:_load_file(name)
    if not chunk then
        return
    end

    self._action_advance = false

    self._coro = coroutine.create(chunk)
    self:_step_dialogue(...)
end

function Dialogue:tick()    
    if not self:is_active() then
        return
    end

    local action_advance = self._action_advance
    self._action_advance = false

    if self._wait_reason == "advance" and action_advance then
        local line_count = self:_get_page_size()
        self._lines_remaining = self._lines_remaining - line_count
        self._line_start = self._line_start + line_count

        if self._lines_remaining <= 0 then
            self:_step_dialogue()
        end
    end
end

function Dialogue:update()
    if Input.players[1]:pressed("player_action1") or Input.players[1]:pressed("player_jump") then
        self._action_advance = true
    end
end

function Dialogue:draw()
    if not self:is_active() then
        return
    end

    local line_count = self:_get_page_size()

    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", 0, 0, DISPLAY_WIDTH, line_count * 6)

    Lg.setColor(P8_PAL.white)
    Lg.setFont(self._font)
    for i = self._line_start, math.min(self._line_start + line_count - 1, #self._lines) do
        local line = self._lines[i]
        Lg.print(line, 0, self._font:getHeight() * (i - self._line_start))
    end
end

function Dialogue:is_active()
    return not not self._coro
end

---@private
function Dialogue:_get_page_size()
    local sz = self._func_env.page_size
    if sz == "auto" then
        return #self._lines
    else
        return sz
    end
end

---@private
---@param name string
---@return function?
function Dialogue:_load_file(name)
    local path = ("res/dialogue/%s.lua"):format(name)
    local s, chunk, err = pcall(love.filesystem.load, path)
    if not s or not chunk then
        local emsg = err or chunk
        softerror(("could not load dialogue '%s': %s"):format(name, emsg))
        self._func_cache[name] = false ---@diagnostic disable-line
        return nil
    else
        self._func_env = table.shallow_copy(self._base_env)
        setfenv(chunk, self._func_env)
        self._func_cache[name] = chunk
        return chunk
    end
end

---@param ... any
---@private
function Dialogue:_step_dialogue(...)
    local s, reason = coroutine.resume(self._coro, ...)
    if not s then
        local err = reason
        print(err .. "\n" .. debug.traceback(self._coro))
    end

    if coroutine.status(self._coro) == "dead" then
        self._coro = nil
        self._text = nil
        self._wait_reason = nil
        return
    end

    self._wait_reason = reason
end

return Dialogue

