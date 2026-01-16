print("Lua version:", _VERSION)

-- this is to make a lua debugger extension work
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()

    -- for some reason, assertion errors points to a lldebugger internal file
    -- so i'm redefining assert so that doesn't happen 
    function assert(a, b)
        return a or error(b or "assertion failed!", 2)
    end

    function love.errorhandler(msg)
        error(msg, 3)
    end
else
    require("error_explorer")
end

if not package.loaded["bit"] then
	local bit32 = package.loaded["bit32"]
	assert(bit32, "lua environment does not have bit/bit32 library!")
	package.loaded["bit"] = bit32
end

if not unpack then
    unpack = table.unpack
end

if setfenv == nil then
    ---@param f integer|fun(any...):...unknown
    ---@param table table
    ---@return function
    function setfenv(f, table)
        if type(f) == "number" then
            f = debug.getinfo(f, "f").func
        end
        ---@cast f function

        local nm = debug.getupvalue(f, 1)
        if nm ~= "_ENV" then
           error("could not set function env") 
        end

        debug.setupvalue(f, 1, table)
        return f
    end
end

-- these imitate the love 12.0 names
---@diagnostic disable-next-line
if love._version_major < 12 then
    love.rawGameArguments = arg
    ---@diagnostic disable-next-line
    love.parsedGameArguments = love.arg.parseGameArguments(arg)
end

DISPLAY_WIDTH = 120
DISPLAY_HEIGHT = 93
GAME_TICK_LENGTH = 1.0 / 60.0
Debug = {
    enabled = false
}

for _, arg in ipairs(love.parsedGameArguments) do
    if arg == "--debug" then
        Debug.enabled = true
        print("enable debug")
    end
end

---@diagnostic disable lowercase-global

---@param err any
---@param level integer?
function softerror(err, level)
    if level == nil then
        level = 1
    end

    err = tostring(err)

    local info = debug.getinfo(level + 1, "Sl")
    local errstr
    print(info.short_src)
    if info and info.short_src and info.currentline then
        errstr = ("%s:%i: %s"):format(info.short_src, info.currentline, err)
    else
        errstr = err
    end

    print("[ERR] " .. errstr .. "\n" .. debug.traceback())

    if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        require("lldebugger").requestBreak()
    end
end

---@generic T
---@param v T
---@param message? any
---@param ... any
---@return T, any ...
function softassert(v, message, ...)
    if not v then
        if message == nil then
            message = "assertion failed!"
        end

        message = tostring(message)
        softerror(message, 2)
    end

    return v, ...
end

local enable_warnings = true

---@param msg1 string
---@param ... string?
function warn(msg1, ...)
    if string.byte(msg1, 1) == 0x40 and select("#", ...) == 0 then
        if msg1 == "@on" then
            enable_warnings = true
        elseif msg1 == "@off" then
            enable_warnings = false
        end
    elseif enable_warnings then
        local msg = table.concat({msg1, ...})
        print("[WRN] " .. msg)
    end
end

function love.conf(t)
    t.version = "11.4"
    t.identity = "pkhead_pgmaS8R2"
    t.window.width = DISPLAY_WIDTH * 5
    t.window.height = DISPLAY_HEIGHT * 5
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = true
    t.window.title = "game"
    
    t.modules.thread = false
    t.modules.video = false
    t.modules.physics = false
end