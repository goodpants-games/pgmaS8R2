local module = {}

---Perform a binary search on an array.
---If the element was found, it returns true and the index of the element. If
---not, it returns false and the index where the element was expected to be.
---@param t any[]
---@param f fun(v,...):integer
---@param min integer?
---@param max integer?
---@param ... any
---@return boolean s, integer idx
local function binary_search(t, f, min, max, ...)
    min = min or 1
    max = max or #t

    if min > max then
        return false, min
    end

    local center = math.floor((max + min - 2) / 2) + 1
    local eval = f(t[center], ...)
    
    if eval == 0 then
        return true, center
    elseif eval < 0 then
        return binary_search(t, f, center + 1, max, ...) 
    else
        return binary_search(t, f, min, center - 1, ...)
    end
end

module.binary_search = binary_search

return module