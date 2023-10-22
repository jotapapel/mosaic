local current, pop, peek ---@type Lexeme, NextLexeme, CurrentLexeme
local decodeValue ---@type fun(): JSONValue
local escapedCharacters <const> = { [116] = "\t", [92] = "\\", [34] = "\"", [98] = "\b", [102] = "\f", [110] = "\n", [114] = "\r" }

--- Throw a local error.
---@param message string The error message.
---@param line? integer Custom line index.
local function throw (message, line)
	io.write("<json> ", line or current.line, ": ", message, ".\n")
	os.exit()
end

---@param source string The raw source.
---@return NextLexeme
---@return CurrentLexeme
local function scanner (source)
	source = source:gsub("\\(.)", function (char) return string.format("\\%03d", string.byte(char)) end)
	local index, lineIndex, len = 1, 1, source:len()
	local function scan ()
		while index <= len do
			repeat
				local typeof, fromIndex, toIndex ---@type string?, integer?, integer?
				local char, lastIndex = source:sub(index, index), index
				-- whitespace
				if char:match("%s") then
					index = index + 1
					if char == "\n" then
						lineIndex = lineIndex + 1
					end
					break
				-- booleans
				elseif char:match("%l") then
					while index <= len and source:sub(index, index):match("%l") do
						index = index + 1
					end
					local value = source:sub(lastIndex, index - 1)
					if value == "true" or value == "false" then
						typeof = "Boolean"
					elseif value == "null" then
						typeof = "Null"
					end
				-- numbers
				elseif char:match("%d") then
					typeof = "Number"
					while index <= len and source:sub(index, index):match("%d") do
						index = index + 1
					end
					if source:sub(index, index) == "." then
						index = index + 1
						while index <= len and source:sub(index, index):match("%d") do
							index = index + 1
						end
					end
				-- strings
				elseif char:match("\"") then
					typeof, index, fromIndex = "String", index + 1, index + 1
					while index <= len and source:sub(index, index):match("[^\"\n]") do
						index = index + 1
					end
					index, toIndex = index + 1, index
				-- characters
				elseif char:match("%p") then
					index = index + 1
					if char == "{" then
						typeof = "LeftBrace"
					elseif char == "[" then
						typeof = "LeftBracket"
					elseif char == "]" then
						typeof = "RightBracket"
					elseif char == "}" then
						typeof = "RightBrace"
					elseif char == ")" then
						typeof = "RightParenthesis"
					elseif char == "," then
						typeof = "Comma"
					elseif char == ":" then
						typeof = "Colon"
					end
				end
				-- unknown character
				if not typeof then
					throw("unknown character found at source", lineIndex)
				end
				return typeof, source:sub(fromIndex or lastIndex, (toIndex or index) - 1), lineIndex, lastIndex
			until true
		end
	end
	return scan, function ()
		local typeof, value, line, startIndex = scan()
		index = startIndex or index
		return typeof, value or "<eof>", line or lineIndex
	end
end

--- Move on to the next lexeme, store the current one in the 'current' table.
---@return string typeof The lexeme type.
---@return string value The lexeme value.
local function consume ()
	local typeof, value = pop()
	current.typeof, current.value, current.line = peek()
	return typeof, value
end

--- Expect a specific lexeme(s) from the scanner, throw an error when not found.
---@param message string The error message.
---@param ... string The expected types.
local function expect (message, ...)
	local lookup = {}
	for _, expected in ipairs({...}) do lookup[expected] = true end
	local typeof, value = consume()
	if not lookup[typeof] then
		throw(message .. " near '" .. value .. "'")
	end
end

--- Suppose a specific lexeme(s) from the scanner, consume it when found, do nothing otherwise.
---@param ... string The supposed lexeme types.
---@return string? #The supposed lexeme value.
local function suppose (...)
	local lookup = {}
	for _, expected in ipairs({...}) do lookup[expected] = true end
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

---@return string|number|boolean|nil
local function decodeLiteral ()
	local typeof, value = consume()
	-- Booleans
	if typeof == "Boolean" then
		return (value == "true") and true or false
	-- Numbers
	elseif typeof == "Number" then
		return tonumber(value)
	-- Null
	elseif typeof == "Null" then
		return nil
	-- Strings
	elseif typeof == "String" then
		value = value:gsub("\\(%d%d%d)([0-9A-F]*)", function (d, x)
			local byte = tonumber(d)
			return (#x > 0) and utf8.char(tonumber(x, 16)) or escapedCharacters[byte]
		end)
		return value
	end
	-- Unknown
	throw("Unknown symbol found near '" .. value .. "'")
end

---@return JSONValue[]
local function decodeArray ()
	if current.typeof ~= "LeftBracket" then
		return decodeLiteral() --[[@as JSONValue]]
	end
	consume()
	local tbl = {} ---@type JSONValue[]
	while current.typeof ~= "RightBracket" do
		tbl[#tbl + 1] = decodeValue()
		suppose("Comma")
	end
	expect("']' expected", "RightBracket")
	return tbl
end

---@return { [string]: JSONValue }
local function decodeObject ()
	if current.typeof ~= "LeftBrace" then
		return decodeArray() --[[@as JSONValue]]
	end
	consume()
	local tbl = {} ---@type { [string]: JSONValue }
	while current.typeof ~= "RightBrace" do
		local key = expect("<key> expected", "String") --[[@as string]]
		expect("':' missing after ", "Colon")
		local value = decodeValue()
		suppose("Comma")
		tbl[key] = value
	end
	expect("RightBrace", "'}' expected")
	return tbl
end

---@return JSONValue
function decodeValue ()
	return decodeObject()
end

---@param filename string
---@return JSONValue?
local function decode (filename)
	local file <close> = io.open(filename) or error("File not found.")
	local source = file:read("*a")
	current, pop, peek = { value = "", line = 0 }, scan(source)
	current.typeof, current.value, current.line = peek()
	if current.typeof then
		return decodeValue()
	end
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