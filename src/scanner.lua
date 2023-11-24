---@type { [string]: true }
local keywords <const> = {
	["and"] = true, ["or"] = true, ["is"] = true,
	["var"] = true,
	["function"] = true, ["return"] = true,
	["prototype"] = true,
	["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
	["while"] = true, ["do"] = true, ["break"] = true,
	["for"] = true, ["to"] = true, ["step"] = true, ["in"] = true,
	["end"] = true,
	["import"] = true, ["from"] = true, ["export"] = true
}

---@param source string The raw source.
---@return NextLexeme
---@return CurrentLexeme
return function (source)
	source = source:gsub("\\(.)", function (c) return string.format("\\%03d", string.byte(c)) end)
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
				-- comments
				elseif char == "-" then
					typeof, index = "Minus", index + 1
					if source:sub(index, index) == "-" then
						typeof, index = "Comment", index + 1
						while index <= len and source:sub(index, index):match("[^\n]") do
							index = index + 1
						end
						fromIndex = lastIndex + 2
					elseif source:sub(index, index) == "=" then
						typeof, index = "MinusEqual", index + 1
					end
				-- identifiers
				elseif char:match("[_%a]") then
					typeof = "Identifier"
					while index <= len and source:sub(index, index):match("[_%w]") do
						index = index + 1
					end
					local value = source:sub(lastIndex, index - 1)
					if value == "true" or value == "false" then
						typeof = "Boolean"
					elseif value == "undef" then
						typeof = "Undefined"
					elseif keywords[value] then
						typeof = value:gsub("^%l", string.upper)
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
				elseif char == "&" and source:sub(index + 1, index + 1):match("[a-fA-F0-9]") then
					typeof, index, fromIndex = "Hexadecimal", index + 1, index + 1
					while index <= len and source:sub(index, index):match("[a-fA-F0-9]") do
						index = index + 1
					end
				-- strings
				elseif char:match('"') then
					typeof, index, fromIndex = "String", index + 1, index + 1
					while index <= len and source:sub(index, index):match('[^"\n]') do
						index = index + 1
					end
					index, toIndex = index + 1, index
				elseif char:match("'") then
					typeof, index, fromIndex = "String", index + 1, index + 1
					while index <= len and source:sub(index, index):match("[^'\n]") do
						index = index + 1
					end
					index, toIndex = index + 1, index
				-- characters
				elseif char:match("%p") then
					index = index + 1
					local adjacent = source:sub(index, index)
					if char == "+" then
						typeof = "Plus"
						if adjacent == "=" then
							typeof, index = "PlusEqual", index + 1
						end
					elseif char == "*" then
						typeof = "Asterisk"
						if adjacent == "=" then
							typeof, index = "AsteriskEqual", index + 1
						end
					elseif char == "/" then
						typeof = "Slash"
						if adjacent == "=" then
							typeof, index = "SlashEqual", index + 1
						end
					elseif char == "^" then
						typeof = "Circumflex"
						if adjacent == "=" then
							typeof, index = "CircumflexEqual", index + 1
						end
					elseif char == "%" then
						typeof = "Percent"
						if adjacent == "=" then
							typeof, index = "PercentEqual", index + 1
						end
					elseif char == ">" then
						typeof = "Greater"
						if adjacent == "=" then
							typeof, index = "GreaterEqual", index + 1
						end
					elseif char == "<" then
						typeof = "Less"
						if adjacent == ">" then
							typeof, index = "NotEqual", index + 1
						elseif adjacent == "=" then
							typeof, index = "LessEqual", index + 1
						end
					elseif char == "=" then
						typeof = "Equal"
						if adjacent == "=" then
							typeof, index = "IsEqual", index + 1
						end
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
						if source:sub(index, index + 1) == ".." then
							typeof, index = "Ellipsis", index + 2
						end
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
					elseif char == "@" then
						typeof = "At"
					end
				end
				-- unknown characters
				if not typeof then
					io.write("<mosaic> ", lineIndex, ": unknown character found at source.\n")
					os.exit()
				end
				return typeof, source:sub(fromIndex or lastIndex, (toIndex or index) - 1), lineIndex, lastIndex
			until true
		end
	end
	return scan, function ()
		local typeof, value, line, startIndex = scan()
		if startIndex then
			index = startIndex
		end
		return typeof, value or "<eof>", line or lineIndex
	end
end