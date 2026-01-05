require("postconf")

local Input = require("input")
local sceneman = require("sceneman")
local fontres = require("fontres")

local display_canvas = Lg.newCanvas(DISPLAY_WIDTH, DISPLAY_HEIGHT, { dpiscale = 1.0 })

local display_ox = 0.0
local display_oy = 0.0
local display_scale = 1.0

local font = Lg.newFont("res/fonts/monogram.ttf", 16, "mono", 1.0)

local WindowedAnalyzer = batteries.class()
function WindowedAnalyzer:new()
    ---@private
    self._time_passed = 0.0
    ---@private
    self._dt_accum = 0.0
    ---@private
    self._dt_max = 0.0
    ---@private
    self._samples = 0

    self.dt_max = 0.0
    self.dt_avg = 0.0
end

---@param elapsed number
function WindowedAnalyzer:add_sample(elapsed)
    self._dt_accum = self._dt_accum + elapsed
    if elapsed > self._dt_max then
        self._dt_max = elapsed
    end

    self._samples = self._samples + 1.0
end

---@param dt number
function WindowedAnalyzer:update(dt)
    self._time_passed = self._time_passed + dt
    if self._time_passed > 0.5 then
        self._time_passed = self._time_passed % 0.5

        self.dt_max = self._dt_max
        self.dt_avg = self._dt_accum / self._samples

        self._dt_accum = 0.0
        self._dt_max = 0.0
        self._samples = 0
    end
end

local anl_update = WindowedAnalyzer()
local anl_draw = WindowedAnalyzer()
local anl_total = WindowedAnalyzer()
local anl_mem = WindowedAnalyzer()

local palette_map ---@type love.Image

local palette_reduction_shader = Lg.newShader([[
uniform Image PaletteMap;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 output_color = Texel(tex, texture_coords) * color;
    vec2 palette_uv = vec2(
        output_color.r,
        (output_color.g / 8.0) + floor(output_color.b * 8.0) / 8.0
    );

    vec3 palettized_rgb = Texel(PaletteMap, palette_uv).rgb;
    return vec4(palettized_rgb, output_color.a);
}
]])

function love.load(args)
    love.keyboard.setTextInput(false)
    -- love.mouse.setVisible(false)

    local preproc = false
    local preproc_force = false

    for _, arg in ipairs(args) do
        if arg == "--debug" then
            Debug.enabled = true
            print("enable debug")
        
        elseif arg == "--preproc" then
            preproc = true
        
        elseif arg == "--preproc-force" then
            preproc_force = true
        end
    end

    if not IS_PACKAGED and preproc then
        ---@diagnostic disable-next-line
        assert(jit, "please run preprocessor with LuaJIT!")

        if preproc_force or not love.filesystem.getInfo("res/pico8_palette_map.png") then
            print("GENERATE PALETTE MAP!")
            require("palette_map_gen")
        end
    end

    palette_map = Lg.newImage("res/pico8_palette_map.png")

    Lg.setFont(fontres.monogram)

    sceneman.switchScene("default")
end

local _paused_sources
function love.visible(visible)
    if visible then
        if _paused_sources then
            love.audio.play(_paused_sources)
        end
    else
        _paused_sources = love.audio.pause()
    end
end

function love.keypressed(key)
    sceneman.dispatch("keypressed", key)

    if key == "f1" then
        Debug.enabled = not Debug.enabled
    end
end

function love.textinput(...)
    sceneman.dispatch("textinput", ...)
end

local function update_display_fit()
    display_scale = math.min(Lg.getHeight() / DISPLAY_HEIGHT, Lg.getWidth() / DISPLAY_WIDTH)
    display_scale = math.max(1, display_scale)
    -- display_scale = math.floor(display_scale)
    display_ox = (Lg.getWidth() - DISPLAY_WIDTH * display_scale) / 2
    display_oy = (Lg.getHeight() - DISPLAY_HEIGHT * display_scale) / 2
    display_ox = math.floor(display_ox)
    display_oy = math.floor(display_oy)
    -- print(display_ox, display_oy, display_scale)
end

local dt_accum = 0.0

function love.update(dt)
    local start = love.timer.getTime()

    batteries.manual_gc(1e-1)
    anl_mem:add_sample(collectgarbage("count"))

    Debug.draw.enabled = Debug.enabled

    update_display_fit()
    MOUSE_X = (love.mouse.getX() - display_ox) / display_scale
    MOUSE_Y = (love.mouse.getY() - display_oy) / display_scale
    
    Input.update()
    sceneman.update(dt)

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002
    local tick_len = GAME_TICK_LENGTH

    if math.abs(dt - tick_len) < DT_SNAP_EPSILON then -- 60 fps?
        dt_to_accum = tick_len
    elseif math.abs(dt - tick_len * 0.5) < DT_SNAP_EPSILON then -- 120 fps?
        dt_to_accum = tick_len * 0.5
    end

    local iter = 1
    dt_accum = dt_accum + dt_to_accum
    while dt_accum >= tick_len do
        if iter > 8 then
            print("too many ticks in one frame!")
            dt_accum = dt_accum % tick_len
            break
        end
        
        sceneman.dispatch("tick")

        dt_accum = dt_accum - tick_len
        iter=iter+1
        GAME_FRAME = GAME_FRAME + 1
    end

    sceneman.dispatch("post_tick")

    anl_update:update(dt)
    anl_draw:update(dt)
    anl_total:update(dt)
    anl_mem:update(dt)

    anl_update:add_sample(love.timer.getTime() - start)
    anl_total:add_sample(dt)
end

function love.draw()
    local draw_ts = love.timer.getTime()

    Lg.setCanvas(display_canvas)
    local bg_r, bg_g, bg_b, bg_a = Lg.getBackgroundColor()
    Lg.clear(bg_r, bg_g, bg_b, bg_a)

    sceneman.draw()
    Debug.draw:flush()
    
    -- draw display onto window
    Lg.setCanvas()
    Lg.clear(0, 0, 0, 1)
    Lg.setColor(1, 1, 1)
    Lg.origin()
    Lg.setShader(palette_reduction_shader)
    if palette_reduction_shader:hasUniform("PaletteMap") then
        palette_reduction_shader:send("PaletteMap", palette_map)
    end
    Lg.draw(display_canvas, display_ox, display_oy, 0, display_scale, display_scale)
    Lg.setShader()

    local draw_frametime = love.timer.getTime() - draw_ts
    anl_draw:add_sample(draw_frametime)

    -- debug text
    if Debug.enabled then
        Lg.push("all")
        Lg.setColor(1, 1, 1)
        Lg.setFont(font)
        Lg.print(("mem: %.2f MiB / %.2f MiB"):format(anl_mem.dt_avg / 1000, anl_mem.dt_max / 1000), 1, 1)
        Lg.print(("update: %.1f ms / %.1f ms"):format(anl_update.dt_avg * 1000, anl_update.dt_max * 1000), 1, 11)
        Lg.print(("draw: %.1f ms / %.1f ms"):format(anl_draw.dt_avg * 1000, anl_draw.dt_max * 1000), 1, 21)
        Lg.print(("frame: %.1f ms / %.1f ms"):format(anl_total.dt_avg * 1000, anl_total.dt_max * 1000), 1, 31)
        Lg.pop()
    end
end

---@diagnostic disable
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
        assert(love.event)
        assert(love.window)

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

        if not LOVEJS or love.window.isVisible() then
            -- Call update and draw
            if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                if love.draw then love.draw() end

                love.graphics.present()
            end
        end

		if not LOVEJS and love.timer then love.timer.sleep(0.001) end
	end
end