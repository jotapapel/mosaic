local parse = require "json.parser"

---@param filename string
local function decode (filename)
	local file <close> = io.open(filename) or error("File not found.")
	local source = file:read("*a")
	return parse(source)
end

---@param value string|number|boolean|table The value to display.
---@param level? number The indent level.
---@param visited? boolean|table Wether the value has been displayed previously.
---@return string #The human readable string.
local function serialize (value, level, visited)
	level, visited = level or 1, visited or {}
	local typeof = type(value)
	if typeof == "function" or typeof == "userdata" then
		error("Cannot display value <" .. typeof .. ">.", 3)
	elseif typeof == "string" then
		return "\"" .. tostring(value) .. "\""
	elseif typeof == "number" or typeof == "boolean" then
		return tostring(value)
	elseif typeof == "table" then
		if visited[value] then
			return "\"(visited)\""
		end
		visited[value] = true
		local parts, delimiter, indent = {}, "{\n%s}", string.rep("\t", level)
		for i, v in ipairs(value) do
			delimiter, parts[i] = "[\n%s]", serialize(v, level + 1, visited)
		end
		for k, v in pairs(value) do
			if type(k) == "number" and k >= 1 and k <= #value and math.floor(k) == k then
				break
			end
			parts[#parts + 1] = "\"" .. k .. "\": " .. serialize(v, level + 1, visited)
		end
		if #parts == 0 then
			return "{}"
		end
		return delimiter:sub(1, 2) .. indent .. table.concat(parts, ",\n" .. indent) .. string.format(delimiter:sub(-4), string.rep("\t", level - 1))
	end
	return "nil"
end

--- Display the value as a valid JSON string.
---@param value string|number|boolean|table The value to trace.
---@param beautify boolean? Beautify the result.
---@return string #The serialized value.
local function encode (value, beautify)
	value = serialize(value)
	return beautify and value or value:gsub("[\n\t]", { ["\t"] = "", ["\n"] = string.char(32) })
end

---@class jsonlib
return {
	decode = decode,
	encode = encode
}