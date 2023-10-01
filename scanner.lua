---@type { [string]: true }
local keywords = {
	["var"] = true, ["function"] = true, ["prototype"] = true,
	["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
	["while"] = true, ["do"] = true,
	["for"] = true, ["to"] = true, ["step"] = true, ["in"] = true,
	["return"] = true, ["break"] = true, ["end"] = true,
	["and"] = true, ["or"] = true
}

---@param source string The raw source.
---@return { typeof: string?, value: string, line: number }
---@return fun(): string?, string, number, number
---@return fun(): string?, string, number
return function (source)
<<<<<<< HEAD
	local index, lineIndex, len = 1, 1, source:len()
=======
	---@type number, number, number
	local index, lineIndex, len = 1, 1, source:len()
	---@return string?, string, number, number
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	local function scan ()
		while index <= len do
			repeat
				---@type string?
				local typeof
				---@type string, number
				local char, startIndex = source:sub(index, index), index
				-- whitespace
				if char:match("%s") then
					index = index + 1
					if char == "\n" then
						lineIndex = lineIndex + 1
					end
					break
				-- comments
				elseif char == "-" then
					index = index + 1
					if source:sub(index, index) == "-" then
						typeof = "Comment"
						while index <= len and source:sub(index, index):match("[^\n]") do
							index = index + 1
						end
					else
						typeof = "Minus"
					end
				-- identifiers
				elseif char:match("[_%a]") then
					typeof = "Identifier"
					while index <= len and source:sub(index, index):match("[_%w]") do
						index = index + 1
					end
					local value = source:sub(startIndex, index - 1)
					if value == "true" or value == "false" then
						typeof = "Boolean"
					elseif value == "undef" then
						typeof = "Undefined"
					elseif keywords[value] then
						typeof = value:gsub("^%l", string.upper)
					end
				-- decorators
				elseif char == "@" and source:sub(index + 1, index + 1):match("[_%a]") then
					typeof, index = "Decorator", index + 1
					while index <= len and source:sub(index, index):match("[_%w]") do
						index = index + 1
					end
				-- decimal numbers
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
				-- hexadecimal numbers
				elseif char == "&" and source:sub(index + 1, index + 1):match("[a-fA-F0-9]") then
					typeof, index = "Hexadecimal", index + 1
					while index <= len and source:sub(index, index):match("[a-fA-F0-9]") do
						index = index + 1
					end
				-- strings
				elseif char:match('"') then
					typeof, index = "String", index + 1
					while index <= len and source:sub(index, index):match('[^"\n]') do
						index = index + 1
					end
					index = index + 1
				-- characters
				elseif char:match("%p") then
					index = index + 1
					if char == "+" then
						typeof = "Plus"
					elseif char == "*" then
						typeof = "Asterisk"
					elseif char == "/" then
						typeof = "Slash"
					elseif char == "^" then
						typeof = "Circumflex"
					elseif char == "%" then
						typeof = "Percent"
					elseif char == ">" then
						typeof = "Greater"
					elseif char == "<" then
						typeof = "Less"
					elseif char == "=" then
						typeof = "Equal"
					elseif char == "(" then
						typeof = "LeftParenthesis"
					elseif char == "{" then
						typeof = "LeftBrace"
					elseif char == "[" then
						typeof = "LeftBracket"
					elseif char == "]" then
						typeof = "RightBracket"
					elseif char == "}" then
						typeof = "RightBrace"
					elseif char == ")" then
						typeof = "RightParenthesis"
					elseif char == "." then
						typeof = "Dot"
					elseif char == "," then
						typeof = "Comma"
					elseif char == ":" then
						typeof = "Colon"
					elseif char == ";" then
						typeof = "Semicolon"
					elseif char == "#" then
						typeof = "Pound"
					elseif char == "$" then
						typeof = "Dollar"
					elseif char == "!" then
						typeof = "Bang"
					end
					if typeof == "Less" or typeof == "Greater" or typeof == "Equal" then
						if typeof == "Less" and source:sub(index, index) == ">" then
							typeof, index = "NotEqual", index + 1
						elseif source:sub(index, index) == "=" then
							typeof, index = "IsEqual", index + 1
						end
					end
				end
				-- unknown character
				if not typeof then
<<<<<<< HEAD
					io.write("<mosaic> ", line, ": unknown character found at source.")
=======
					io.write("<mosaic> ", lineIndex, ": unknown character found at source.")
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
					os.exit()
				end
				return typeof, source:sub(startIndex, index - 1), lineIndex, startIndex
			until true
		end
	end
<<<<<<< HEAD
	return keywords, scan, function ()
=======
	---@return string?, string, number
	return {}, scan, function ()
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
		local typeof, value, line, lastIndex = scan()
		if lastIndex then
			index = lastIndex
		end
		return typeof, value or "<eof>", line or (lineIndex - 1)
	end
end