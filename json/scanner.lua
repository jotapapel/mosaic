---@param source string The raw source.
---@return NextLexeme
---@return CurrentLexeme
return function (source)
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
				elseif char:match('"') then
					typeof, index, fromIndex = "String", index + 1, index + 1
					while index <= len and source:sub(index, index):match('[^"\n]') do
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
					io.write("<JSON> ", lineIndex, ": unknown character found at source.\n")
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