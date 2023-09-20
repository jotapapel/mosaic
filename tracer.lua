local function serialize (value, level, visited)
	level, visited = level or 1, visited or {}
	local typeof = type(value)
	if typeof == "string" then
		return '"' .. tostring(value) .. '"'
	elseif typeof == "number" or typeof == "boolean" then
		return tostring(value)
	elseif typeof == "table" then
		if visited[value] then
			return "(visited)"
		end
		visited[value] = true
		local parts, isarray, indent = {}, false, string.rep("\t", level)
		for i, v in ipairs(value) do
			isarray = true
			parts[i] = serialize(v, level + 1, visited)
		end
		for k, v in pairs(value) do
			if type(k) == "number" and k >= 1 and k <= #value and math.floor(k) == k then
				break
			end
			parts[#parts + 1] = k .. ": " .. serialize(v, level + 1, visited)
		end
		if #parts == 0 then
			return "{}"
		end
		local delimiter = isarray and { open = "[\n", closing = "\n%s]" } or { open = "{\n", closing = "\n%s}" }
		return delimiter.open .. indent .. table.concat(parts, ",\n" .. indent) .. string.format(delimiter.closing, string.rep("\t", level - 1))
	end
	return "nil"
end

return function (value, inline)
	local value = serialize(value)
	print(inline and value:gsub("[\n\t]", { ["\t"] = "", ["\n"] = string.char(32) }) or value)
end