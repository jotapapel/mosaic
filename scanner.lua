local keywords = {
	["var"] = true, ["function"] = true, ["prototype"] = true,
	["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
	["while"] = true, ["do"] = true,
	["for"] = true, ["to"] = true, ["step"] = true, ["in"] = true,
	["return"] = true, ["break"] = true, ["end"] = true,
	["and"] = true, ["or"] = true
}

return function (source)
	local index, len, line = 1, source:len(), 1
	local function scan ()
		while index <= len do
			repeat
				local typeof
				local char, startIndex = source:sub(index, index), index
				-- whitespace
				if char:match("%s") then
					index = index + 1
					if char == "\n" then
						line = line + 1
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
				-- decorator
				elseif char == "@" and source:sub(index + 1, index + 1):match("[_%a]") then
					typeof, index = "Decorator", index + 1
					while index <= len and source:sub(index, index):match("[_%w]") do
						index = index + 1
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
				-- hexadecimal numbers
				elseif char == "&" and source:sub(index + 1, index + 1):match("[a-fA-F0-9]") then
					typeof, index = "Number", index + 1
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
				-- special characters
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
					error("<mosaic> unknown character found at source.", 3)
				end
				return typeof, source:sub(startIndex, index - 1), startIndex, line
			until true
		end
	end
	return scan, function ()
		local typeof, value, lastIndex = scan()
		if lastIndex then
			index = lastIndex
		end
		return typeof, value, line
	end
end