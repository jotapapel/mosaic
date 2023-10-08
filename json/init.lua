local scan = require "frontend.scanner"

---@type Lexeme, NextLexeme, CurrentLexeme
local current, pop, peek
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
---@param expected string|table<string, true> The expected type.
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
---@param supposed string|table<string, true> The supposed lexeme type.
---@return string? #The supposed lexeme value.
local function suppose (supposed)
	local lookup = (type(supposed) == "string") and { [supposed] = true } or supposed
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

---@alias JSONValue string|table<string|number, any>
---@return string|boolean
local function decodeLiteral ()
	local typeof, value = consume()
	if typeof == "String" then
		return value:sub(2, -2)
	elseif typeof == "Boolean" then
		return (value == "true") and true or false
	end
	return value
end

---@return JSONValue?
local function decodeArray ()
	if current.typeof ~= "LeftBracket" then
		return decodeLiteral()
	end
	consume()
	local tbl, index = {}, 1
	while current.typeof ~= "RightBracket" do
		tbl[index], index = decodeValue(), index + 1
		suppose("Comma")
	end
	expect("RightBracket", "']' expected")
	return tbl
end

---@return JSONValue?
local function decodeObject ()
	if current.typeof ~= "LeftBrace" then
		return decodeArray()
	end
	consume()
	local tbl = {}
	while current.typeof ~= "RightBrace" do
		local key = expect("String", "<name> expected")
		expect("Colon", "':' missing after ")
		local value = decodeValue()
		suppose("Comma")
		tbl[key:sub(2, -2)] = value
	end
	expect("RightBrace", "'}' expected")
	return tbl
end

function decodeValue ()
	return decodeObject()
end

---@class JSON
---@field decode fun(source: string): JSONValue?
return {
	decode = function (source)
		current, pop, peek = scan(source)
		current.typeof, current.value, current.line = peek()
		if current.typeof then
			return decodeValue()
		end
	end
}