---@class ui.Menu: batteries.Class
---@field on_signal nil|fun(menu:ui.Menu, signal:string, ...)
---@field query_focused nil|fun(menu:ui.Menu):boolean
---@overload fun():ui.Menu
local Menu = batteries.class {
    name = "ui.Menu"
}

local Input = require("input")
local fontres = require("fontres")

local function default_query_focused() return true end

function Menu:new()
    self.font = fontres.quinque
    self.items = {}
    self.active_item = 1
    self.max_width = 0
    self.frame_num = 0

    self.query_focused = default_query_focused
end

---@param label string
function Menu:add_label(label)
    self.max_width = math.max(self.max_width, self.font:getWidth(label))
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

    local max_width, lines = self.font:getWrap(text, wrap_width)
    self.max_width = math.max(self.max_width, max_width)
    table.insert(self.items, {
        type = "text",
        lines = lines,
        align = align
    })

    return self
end

---@param label string
---@param signal string?
function Menu:add_action(label, signal)
    signal = signal or label

    self.max_width = math.max(self.max_width, self.font:getWidth(label))
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

    return self.max_width + 4, height
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
    
    elseif Input.players[1]:pressed("up") then
        local start = self.active_item
        repeat
            self.active_item = (self.active_item - 2) % #self.items + 1
        until self.active_item == start or
              self.items[self.active_item].type == "action"
        
        self.frame_num = 0
    end

    if Input.players[1]:pressed("player_jump") then
        local item = self.items[self.active_item]

        if item.type == "action" then
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
            ix = x + 1

            if is_focused then
                Lg.setColor(P8_PAL.blue)
            else
                Lg.setColor(P8_PAL.dark_gray)
            end

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
                Lg.printf(line, ix, item_y, self.max_width, item.align)
                item_y = item_y + line_height
            end
        
        else
            ix = x + 4
            local ci = math.floor(self.frame_num / 8)
            local draw_cursor = false

            if not is_focused then
                Lg.setColor(P8_PAL.dark_gray)
                draw_cursor = i == self.active_item
            elseif i == self.active_item and ci % 2 == 0 then
                Lg.setColor(P8_PAL.yellow)
                draw_cursor = true
            else
                Lg.setColor(P8_PAL.white)
            end

            if draw_cursor then
                Lg.rectangle("fill", x + 1, item_y + math.round(line_height / 2), 2, 2)
            end
    
            Lg.print(item.label, ix, item_y)
            item_y = item_y + line_height
        end
    end
end

return Menu