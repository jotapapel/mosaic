---@param func? integer|function
local function seek (func)
    func = (type(func) == "number") and func + 1 or func
    local index, locals = 1, {}
    repeat
        local name, value = debug.getlocal(func, index)
        if name then
		    locals[name], index = value or "\0", index + 1
	    end
    until not name
    return locals
end

---@param str string The string to interpolate.
---@param env? table Custom environment table to look in.
---@param level? integer Stack level to look in.
---@return string #The interpolated string.
return function (str, env, level)
    level = level or 1
    if not env then
        local locals = seek(level + 1)
        env = setmetatable(locals, { __index = _G })
    end
    local output = str:gsub("$(%b{})", function (expr)
        local value = env[expr:sub(2, -2)]
        return tostring((value == "\0") and nil or value)
    end)
    return output
end