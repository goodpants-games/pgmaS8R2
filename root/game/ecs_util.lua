local ecs_util = {}

local MESSAGE_PREFIX = "msg_"

---Returns true if the entity has a handler for a certain message name.
---@param ent any
---@param msg_name string
---@return boolean
function ecs_util.has_handler(ent, msg_name)
    msg_name = MESSAGE_PREFIX .. msg_name
    if ent.behavior then
        return not not ent.behavior.inst[msg_name]
    else
        return false
    end
end

---Sends a message to the entity's behavior component, if applicable. This will
---call the function named "msg_[name]" in the given entity's behavior
---component. Returns a boolean which is true if the handler exists, followed by
---the return values of the message handler.
---@param ent any
---@param msg_name string
---@param ... any
---@return boolean, ...
function ecs_util.send_message(ent, msg_name, ...)
    msg_name = MESSAGE_PREFIX .. msg_name
    if ent.behavior then
        local inst = ent.behavior.inst
        if inst[msg_name] then
            return true, inst[msg_name](inst, ...)
        end
    end
    return false
end

return ecs_util