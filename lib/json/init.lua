local current, pop, peek ---@type JSONLexeme, JSONLexicalScanner, JSONLexicalScanner
local decodeValue ---@type JSONParser<JSONValue>
local escapedCharacters <const> = { [116] = "\t", [92] = "\\", [34] = "\"", [98] = "\b", [102] = "\f", [110] = "\n", [114] = "\r" }

--- Throw a local error.
---@param message string The error message.
---@param line? integer Custom line index.
local function throw (message, line)
	io.write("<json> ", line or current.line, ": ", message, ".\n")
	os.exit()
end

--- Source code tokenizer.
---@param source string The raw source.
---@return JSONLexeme
---@return JSONLexicalScanner
---@return JSONLexicalScanner
local function scan (source)
	source = source:gsub("\\(.)", function (char) return string.format("\\%03d", string.byte(char)) end)
	local index, lineIndex, len = 1, 1, source:len()
	local function tokenize ()
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
	return { value = "", line = 0 }, tokenize, function ()
		local typeof, value, line, startIndex = tokenize()
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
---@return string #The expected type.
local function expect (message, ...)
	local found, typeof, value = false, consume()
	for _, expected in ipairs({ ... }) do
		found = found or (typeof == expected)
	end
	return found and value or throw(message .. " near '" .. value .. "'")
end

--- Suppose a specific lexeme(s) from the scanner, consume it when found, do nothing otherwise.
---@param ... string The supposed lexeme types.
---@return string? #The supposed lexeme value.
local function suppose (...)
	for _, expected in ipairs({ ... }) do
		if current.typeof == expected then
			local _, value = consume()
			return value
		end
	end
end

---@return JSONValue
local function decodeLiteral ()
	local typeof, value = consume()
	-- Booleans
	if typeof == "Boolean" then
		return ({ ["true"] = true, ["false"] = false })[value]
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
	if current.typeof == "LeftBracket" then
		consume()
		local tbl = {} ---@type JSONValue[]
		while current.typeof ~= "RightBracket" do
			tbl[#tbl + 1] = decodeValue()
			if not suppose "Comma" then
				break
			end
		end
		expect("']' expected", "RightBracket")
		return tbl
	end
	return decodeLiteral()
end

---@return table<string, JSONValue>
local function decodeObject ()
	if current.typeof == "LeftBrace" then
		consume()
		local tbl = {} ---@type table<string, JSONValue>
		while current.typeof ~= "RightBrace" do
			local key = expect("<key> expected", "String") --[[@as string]]
			expect("':' missing after ", "Colon")
			tbl[key] = decodeValue()
			if not suppose "Comma" then
				break
			end
		end
		expect("'}' expected", "RightBrace")
		return tbl
	end
	return decodeArray()
end

---@return JSONValue
function decodeValue ()
	return decodeObject()
end

--- Decode a JSON file.
---@param filename string The file to decode.
---@return JSONValue? #The JSON valu as a Lua table.
local function decode (filename)
	local file <close> = io.open(filename) or error("File not found.")
	local source = file:read("*a")
	current, pop, peek = scan(source)
	current.typeof, current.value, current.line = peek()
	if current.typeof then
		return decodeValue()
	end
end

--- Serialize a value, producing a valid JSON value.
---@param value string|number|boolean|table The value to display.
---@param level? number The indent level.
---@param visited? boolean|table Wether the value has been displayed previously.
---@return string #The human readable string.
local function serialize (value, level, visited)
	level, visited = level or 1, visited or {}
	local typeof = type(value)
	if typeof == "function" or typeof == "userdata" then
		throw("Cannot display value <" .. typeof .. ">.")
	elseif typeof == "string" then
		return "\"" .. tostring(value) .. "\""
	elseif typeof == "number" or typeof == "boolean" then
		return tostring(value)
	elseif typeof == "table" then
		if not visited[value] then
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
			visited[value] = delimiter:sub(1, 2) .. indent .. table.concat(parts, ",\n" .. indent) .. string.format(delimiter:sub(-4), string.rep("\t", level - 1))
		end
		return visited[value]
	end
	return "nil"
end

--- Display the value as a valid JSON string.
---@param value string|number|boolean|table The value to encode.
---@param beautify boolean? Beautify the result.
---@return string #The serialized value.
local function encode (value, beautify)
	value = serialize(value)
	return beautify and value or value:gsub("[\n\t]", { ["\t"] = "", ["\n"] = string.char(32) })
end

--- Simple and straight-forward JSON library.
---@class jsonlib
return {
	decode = decode,
	encode = encode
}

---@class JSONLexeme
---@field typeof? string Lexeme type.
---@field value string Lexeme value.
---@field line integer Lexeme line number.
---@field startIndex? integer

---@alias JSONLexicalScanner fun(): string?, string, integer, integer?
---@alias JSONParser<T> fun(): T?
---@alias JSONValue table<string, JSONValue>|JSONValue[]|boolean|number|string|nil