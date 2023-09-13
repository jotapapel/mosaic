local keywords = {
	["var"] = true, ["function"] = true, ["prototype"] = true,
	["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
	["while"] = true, ["do"] = true,
	["for"] = true, ["to"] = true, ["step"] = true, ["in"] = true,
	["return"] = true, ["break"] = true, ["end"] = true,
	["true"] = true, ["false"] = true,
	["undef"] = true
}

return function (source)
	local index, len = 1, source:len()
	local function scan ()
		while index <= len do
			repeat
				local char, startIndex = source:sub(index, index), index
				if char:match("%s") then
					index = index + 1
					break
				elseif char == "-" then
					index = index + 1
					if source:sub(index, index) == "-" then
						while index <= len and source:sub(index, index):match("[^\n]") do
							index = index + 1
						end
						return "Comment", source:sub(startIndex, index - 1), startIndex
					end
					return "Minus", source:sub(startIndex, index - 1), startIndex
				elseif char:match("[_%a]") then
					while index <= len and source:sub(index, index):match("[_%w]") do
						index = index + 1
					end
					return "Identifier", source:sub(startIndex, index - 1), startIndex
				elseif char:match("%d") then
					while index <= len and source:sub(index, index):match("%d") do
						index = index + 1
					end
					if source:sub(index, index) == "." then
						index = index + 1
						while index <= len and source:sub(index, index):match("%d") do
							index = index + 1
						end
					end
					return "Number", source:sub(startIndex, index - 1), startIndex
				elseif char == "&" and source:sub(index + 1, index + 1):match("[a-fA-F0-9]") then
					index = index + 1
					while index <= len and source:sub(index, index):match("[a-fA-F0-9]") do
						index = index + 1
					end
					return "Number", source:sub(startIndex, index - 1), startIndex
				elseif char:match('"') then
					index = index + 1
					while index <= len and source:sub(index, index):match('[^"\n]') do
						index = index + 1
					end
					index = index + 1
					return "String", source:sub(startIndex, index - 1), startIndex
				elseif char:match("%p") then
					index = index + 1
					local typeof
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
							index = index + 1
							typeof = "NotEqual"
						elseif source:sub(index, index) == "=" then
							index = index + 1
							typeof = "IsEqual"
						end
					end
					return typeof, source:sub(startIndex, index - 1), startIndex
				end
				error("<mosaic> unknown character found at source.", 3)
            until true
        end
	end
	return scan, function ()
		local typeof, value, lastIndex = scan()
		if lastIndex then
			index = lastIndex - 1
		end
		return typeof, value
	end
end