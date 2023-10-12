local scan = require "json.scanner"
---@type Lexeme, NextLexeme, CurrentLexeme
local current, pop, peek
---@type fun(): JSONValue
local decodeValue

--- Throw a local error.
---@param message string The error message.
local function throw (message)
	io.write("<json> ", current.line, ": ", message, ".\n")
	os.exit()
end

--- Move on to the next lexeme, store the current one in the 'current' table.
---@return string typeof The lexeme type.
---@return string value The lexeme value.
local function consume ()
	local typeof, value = pop()
	current.typeof, current.value, current.line = peek()
	return typeof, value
end

--- Expect a specific lexeme from the scanner, throw an error when not found.
---@param expected string|{ [string]: true } The expected type.
---@param message string The error message.
---@return string #The expected lexeme value.
local function expect (expected, message)
	local lookup = (type(expected) == "string") and { [expected] = true } or expected
	local typeof, value = consume()
	if not lookup[typeof] then
		throw(message .. " near '" .. value .. "'")
	end
	return value
end

--- If there is an specific lexeme as the current one, consume it, else, do nothing.
---@param supposed string|{ [string]: true } The supposed lexeme type.
---@return string? #The supposed lexeme value.
local function suppose (supposed)
	local lookup = (type(supposed) == "string") and { [supposed] = true } or supposed
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

local escapedCharacters = { [116] = "\t", [92] = "\\", [34] = "\"", [98] = "\b", [102] = "\f", [110] = "\n", [114] = "\r" }

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
	---@type JSONValue[]
	local tbl = {}
	while current.typeof ~= "RightBracket" do
		tbl[#tbl + 1] = decodeValue()
		suppose("Comma")
	end
	expect("RightBracket", "']' expected")
	return tbl
end

---@return { [string]: JSONValue }
local function decodeObject ()
	if current.typeof ~= "LeftBrace" then
		return decodeArray() --[[@as JSONValue]]
	end
	consume()
	---@type { [string]: JSONValue }
	local tbl = {}
	while current.typeof ~= "RightBrace" do
		local key = expect("String", "<key> expected")
		expect("Colon", "':' missing after ")
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

---@param source string
---@return JSONValue?
return function (source)
	current, pop, peek = {}, scan(source)
	current.typeof, current.value, current.line = peek()
	if current.typeof then
		return decodeValue()
	end
end