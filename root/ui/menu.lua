---@class ui.Menu: batteries.Class
---@field on_signal nil|fun(menu:ui.Menu, signal:string, ...)
---@field query_focused nil|fun(menu:ui.Menu):boolean
---@overload fun():ui.Menu
local Menu = batteries.class {
    name = "ui.Menu"
}

local Input = require("input")
local fontres = require("fontres")

local snd_ui_select = love.audio.newSource("res/sfx/menu_select.wav", "static")
local snd_ui_push = love.audio.newSource("res/sfx/menu_push.wav", "static")

-- why is it positional by default? it should be an opt-in. wtf. whatever.
-- god openal sucks. like why is it called setRelative instead of, like,
-- setPositional ???
snd_ui_select:setRelative(true)
snd_ui_push:setRelative(true)

local function default_query_focused() return true end

function Menu:new()
    self.font = fontres.quinque
    self.items = {}
    self.active_item = 1
    self.ct_width = 0
    self.frame_num = 0
    self.min_width = 0
    self.centered = false

    self.query_focused = default_query_focused
end

---@param label string
function Menu:add_label(label)
    self.ct_width = math.max(self.ct_width, self.font:getWidth(label))
    table.insert(self.items, {
        type = "label",
        label = label
    })

    return self
end

---@param text string
---@param wrap_width number?
---@param align "center"|"left"|"justify"|nil
function Menu:add_text(text, wrap_width, align)
    wrap_width = wrap_width or math.huge
    align = align or "left"

    local ct_width, lines = self.font:getWrap(text, wrap_width)
    self.ct_width = math.max(self.ct_width, ct_width)
    table.insert(self.items, {
        type = "text",
        lines = lines,
        wrap_width = wrap_width,
        align = align
    })

    return self
end

function Menu:replace_text_item(idx, text)
    local item = self.items[idx]
    
    local wrap_width = item.wrap_width
    local ct_width, lines = self.font:getWrap(text, wrap_width)
    self.ct_width = math.max(self.ct_width, ct_width)

    item.lines = lines
end

---@param label string
---@param signal string?
function Menu:add_action(label, signal)
    signal = signal or label

    self.ct_width = math.max(self.ct_width, self.font:getWidth(label))
    table.insert(self.items, {
        type = "action",
        label = label,
        signal = signal
    })

    return self
end

---@return number w, number h
function Menu:get_size()
    local line_height = self.font:getHeight()
    local height = 1
    for _, item in ipairs(self.items) do
        if item.type == "text" then
            height = height + #item.lines * line_height
        else
            height = height + line_height
        end
    end

    return math.max(self.min_width, self.ct_width + 4), height
end

function Menu:update()
    local start = self.active_item
    while self.items[self.active_item].type ~= "action" do
        self.active_item = self.active_item % #self.items + 1

        if self.active_item == start then
            break
        end
    end

    if not self:query_focused() then return end

    if Input.players[1]:pressed("down") then
        local start = self.active_item
        repeat
            self.active_item = self.active_item % #self.items + 1
        until self.active_item == start or
              self.items[self.active_item].type == "action"

        self.frame_num = 0

        snd_ui_select:seek(0)
        snd_ui_select:play()
    
    elseif Input.players[1]:pressed("up") then
        local start = self.active_item
        repeat
            self.active_item = (self.active_item - 2) % #self.items + 1
        until self.active_item == start or
              self.items[self.active_item].type == "action"
        
        self.frame_num = 0

        snd_ui_select:seek(0)
        snd_ui_select:play()
    end

    if Input.players[1]:pressed("ui_confirm") then
        local item = self.items[self.active_item]

        if item.type == "action" then
            snd_ui_push:seek(0)
            snd_ui_push:play()
            if self.on_signal then self:on_signal(item.signal) end
        end
    end
end

function Menu:tick()
    self.frame_num = self.frame_num + 1
end

---@param x number
---@param y number
function Menu:draw(x, y)
    local line_height = self.font:getHeight()
    local width, height = self:get_size()

    Lg.setColor(P8_PAL.black)
    Lg.rectangle("fill", x, y, width, height)
    Lg.setFont(self.font)

    local is_focused = self:query_focused()
    local item_y = y

    for i, item in ipairs(self.items) do
        local ix

        if item.type == "label" then

            if is_focused then
                Lg.setColor(P8_PAL.blue)
            else
                Lg.setColor(P8_PAL.dark_gray)
            end

            ix = math.round(x + (width - self.font:getWidth(item.label)) / 2.0)
            
            Lg.print(item.label, ix, item_y)
            item_y = item_y + line_height

        elseif item.type == "text" then
            ix = x + 1

            if is_focused then
                Lg.setColor(P8_PAL.white)
            else
                Lg.setColor(P8_PAL.dark_gray)
            end

            for _, line in ipairs(item.lines) do
                Lg.printf(line, ix, item_y, width - 2, item.align)
                item_y = item_y + line_height
            end
        
        else
            local ci = math.floor(self.frame_num / 15)
            local draw_cursor = false

            if self.centered then
                ix = x + math.round((width - self.font:getWidth(item.label)) / 2.0) + 1
            else
                ix = x + 4
            end

            if not is_focused then
                Lg.setColor(P8_PAL.dark_gray)
                draw_cursor = i == self.active_item
            elseif i == self.active_item then
                Lg.setColor(P8_PAL.yellow)
                draw_cursor = ci % 2 == 0
            else
                Lg.setColor(P8_PAL.white)
            end

            if draw_cursor then
                Lg.rectangle("fill", ix - 3, item_y + math.round(line_height / 2), 2, 2)
            end
    
            Lg.print(item.label, ix, item_y)
            item_y = item_y + line_height
        end
    end
end

return Menu