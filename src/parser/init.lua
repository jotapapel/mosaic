local json = require "lib.json"

local parseMemberExpression, parseNewCallMemberExpression ---@type Parser<MemberExpression|Term>, Parser<CallExpression|NewExpression|MemberExpression>
local parseExpression, parseStatement ---@type Parser<Expression>, Parser<StatementExpression, boolean>
local path, current, pop, peek ---@type string, Lexeme, LexicalScanner, LexicalScanner

---@type table<string, boolean>
local keywords <const> = {
	["and"] = true, ["or"] = true, ["is"] = true,
	["var"] = true,
	["function"] = true, ["return"] = true,
	["prototype"] = true,
	["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true,
	["while"] = true, ["do"] = true, ["break"] = true,
	["for"] = true, ["to"] = true, ["step"] = true, ["in"] = true,
	["end"] = true,
	["import"] = true, ["from"] = true
}

---@type table<integer, string>
local escapedCharacters <const> = {
	[116] = "\\t", [92] = "\\\\",
	[34] = "\\\"", [98] = "\\b",
	[102] = "\\f", [110] = "\\n",
	[114] = "\\r", [39] = "\\\'" 
}

--- Throw a local error.
---@param message string The error message.
local function throw (message, line)
	io.write(string.format("[%s]", path), " <mosaic> ", line or current.line, ": ", message, ".\n")
	os.exit()
end

--- Source code tokenizer.
---@param source string The raw source.
---@return Lexeme
---@return LexicalScanner
---@return LexicalScanner
local function scan (source)
	source = source:gsub("\\(.)", function (c) return string.format("\\%03d", string.byte(c)) end)
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
						if source:sub(index, index):match("[^%d]") then
							throw("malformed number near '" .. source:sub(fromIndex or lastIndex, toIndex or index) .. "'")
						end
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
						if adjacent:match("%d") then
							typeof, index = "Number", index + 1
							while index <= len and source:sub(index, index):match("%d") do
								index = index + 1
							end
						elseif adjacent == "." and source:sub(index, index + 1) ~= ".." then
							if source:sub(index + 1, index + 1) == "=" then
								typeof, index = "ConcatEqual", index + 2
							else
								typeof, index = "Concat", index + 1
							end
						elseif source:sub(index, index + 1) == ".." then
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
					throw("unknown character found at source")
				end
				return typeof, source:sub(fromIndex or lastIndex, (toIndex or index) - 1), lineIndex, lastIndex
			until true
		end
	end
	return { value = "", line = 0 }, tokenize, function ()
		local typeof, value, line, last = tokenize()
		if last then
			index = last
		end
		return typeof, value or "<eof>", line or lineIndex
	end
end

--- Move on to the next lexeme, store the current one in the 'current' table.
---@return string typeof The lexeme type.
---@return string value The lexeme value.
---@return integer line The line number.
local function consume ()
	local typeof, value, line = pop()
	current.typeof, current.value, current.line = peek()
	return typeof, value or "<eof>", line
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

--- Check the kind of a node generated by a parsing function, throw an error when there's a mismatch.
---@param message? string The error message.
---@param parseFunc function The function to produce the node.
---@param ... string The expected kind.
---@return StatementExpression #The node with the expected kind.
local function catch (message, parseFunc, ...)
	local found, value, node = false, current.value, parseFunc() --[[@as StatementExpression]]
	for _, expected in ipairs({ ... }) do
		found = found or (node.kindof == expected)
	end
	return found and node or throw(message .. " near '" .. value .. "'")
end

---@return Term?
local function parseTerm ()
	local typeof, value = consume()
	-- UnaryExpression
	if typeof == "Minus" or typeof == "Dollar" or typeof == "Pound" or typeof == "Bang" then
		return { kindof = "UnaryExpression", operator = value, argument = parseNewCallMemberExpression() --[[@as Expression]] }
	-- Identifier
	elseif typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	-- StringLiteral
	elseif typeof == "String" then
		value = value:gsub("\\(%d%d%d)", function (d) return escapedCharacters[tonumber(d)] end)
		return { kindof = "StringLiteral", value = value }
	-- NumberLiteral
	elseif typeof == "Number" then
		return { kindof = "NumberLiteral", value = tonumber(value) }
	elseif typeof == "Hexadecimal" then
		return { kindof = "NumberLiteral", value = tonumber(value, 16) }
	-- Boolean
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	-- Undefined
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	-- Ellipsis
	elseif typeof == "Ellipsis" then
		if current.typeof == "Identifier" then
			return { kindof = "UnaryExpression", operator = "...", argument = parseMemberExpression() --[[@as Expression]] }
		end
		return { kindof = "Ellipsis" }
	-- ParenthesizedExpression
	elseif typeof == "LeftParenthesis" then
		local node = parseExpression() --[[@as Expression]]
		expect("')' expected", "RightParenthesis")
		return { kindof = "ParenthesizedExpression", node = node }
	end
	-- Unknown
	throw("unexpected symbol near '" .. value .. "'")
end

---@return MemberExpression|Term
function parseMemberExpression ()
	local record = parseTerm() --[[@as Term]]
	while current.typeof == "Dot" or current.typeof == "LeftBracket"  do
		local property, computed ---@type Expression, boolean
		local typeof, value = consume()
		if typeof == "Dot" then
			property, computed = catch("syntax error", parseTerm, "Identifier"), false
		else
			property, computed = parseExpression(), true
			expect("']' missing", "RightBracket")
		end
		record = { kindof = "MemberExpression", record = record, property = property, computed = computed } --[[@as MemberExpression]]
	end
	return record
end

---@param caller Expression
---@param instance Expression?
---@return CallExpression
local function parseCallExpression (caller, instance)
	local last = current.line
	while suppose "LeftParenthesis" do
		caller = { kindof = "CallExpression", caller = caller, arguments = { instance } } --[[@as CallExpression]]
		while current.typeof ~= "RightParenthesis" do
			caller.arguments[#caller.arguments + 1] = parseExpression()
			if not suppose "Comma" then
				break
			end
		end
		expect("')' expected (to close '(' at line " .. last .. ")", "RightParenthesis")
	end
	return caller
end

---@param prototype Identifier|MemberExpression
---@return NewExpression
local function parseNewExpression (prototype)
	prototype = { kindof = "NewExpression", prototype = prototype, arguments = {} } --[[@as NewExpression]]
	while current.typeof ~= "RightBrace" do
		prototype.arguments[#prototype.arguments + 1] = parseExpression()
		if not suppose "Comma" then
			break
		end
	end
	expect("'}' expected", "RightBrace")
	return prototype
end

---@return CallExpression|NewExpression|MemberExpression
function parseNewCallMemberExpression()
	local member = parseMemberExpression()
	if member.kindof == "Identifier" or member.kindof == "MemberExpression" or member.kindof == "ParenthesizedExpression" then
		if suppose "LeftBrace" then
			return parseNewExpression(member)
		elseif current.typeof == "LeftParenthesis" then
			return parseCallExpression(member)
		elseif suppose "Colon" then
			if member.kindof == "MemberExpression" or member.kindof == "Identifier" then
				local property = catch("<name> expected", parseTerm, "Identifier") --[[@as Expression]]
				local caller = { kindof = "MemberExpression", record = member --[[@as Expression]], property = property, computed = false, instance = true }
				return parseCallExpression(caller, member)
			end
		end
	end
	return member
end

---@return BinaryExpression|CallExpression|NewExpression|MemberExpression
local function parseMultiplicativeExpression ()
	local left = parseNewCallMemberExpression()
	while current.typeof == "Asterisk" or current.typeof == "Slash" or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseExpression() --[[@as Expression]] } --[[@as BinaryExpression]]
	end
	return left
end

---@return BinaryExpression
local function parseAdditiveExpression ()
	local left = parseMultiplicativeExpression()
	while current.typeof == "Plus" or current.typeof == "Minus" or current.typeof == "Concat" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseExpression() --[[@as Expression]] } --[[@as BinaryExpression]]
	end
	return left
end

---@return BinaryExpression
local function parseComparisonExpression ()
	local left = parseAdditiveExpression()
	while current.typeof == "IsEqual" or current.typeof == "Greater" or current.typeof == "Less"
		  or current.typeof == "GreaterEqual" or current.typeof == "LessEqual" or current.typeof == "NotEqual" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseExpression() --[[@as Expression]] } --[[@as BinaryExpression]]
	end
	return left
end

---@return BinaryExpression
local function parseLogicalExpression ()
	local left = parseComparisonExpression()
	while current.typeof == "And" or current.typeof == "Or" or current.typeof == "Is" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseExpression() --[[@as Expression]] } --[[@as BinaryExpression]]
	end
	return left
end

---@return RecordLiteralExpression|BinaryExpression
local function parseRecordExpression ()
	if suppose "LeftBracket" then
		local elements = {} ---@type RecordElement[]
		while current.typeof ~= "RightBracket" do
			local key ---@type (Identifier|StringLiteral)?
			local value = parseExpression() --[[@as Expression]]
			if value.kindof == "StringLiteral" and suppose("Colon") then
				if not (current.typeof == "Comma" or current.typeof == "RightBracket") then
					key = value
				end
			end
			elements[#elements + 1] = { kindof = "RecordElement", key = key, value = key and parseExpression() or value --[[@as Expression]] }
			if not suppose "Comma" then
				break
			end
		end
		expect("']' expected", "RightBracket")
		return { kindof = "RecordLiteralExpression", elements = elements }
	end
	return parseLogicalExpression()
end

---@return FunctionExpression|RecordLiteralExpression
local function parseFunctionExpression ()
	local line = current.line
	if suppose "Function" then
		local body, parameters = {}, {} ---@type BlockStatement[], Identifier[]
		expect("'(' expected after 'function'", "LeftParenthesis")
		while current.typeof == "Identifier" or current.typeof == "Ellipsis" do
			parameters[#parameters + 1] = catch("<name> expected", parseTerm, "Identifier", "Ellipsis")
			if not suppose "Comma" then
				break
			end
		end
		expect("')' expected", "RightParenthesis")
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement() --[[@as BlockStatement]]
		end
		expect("'end' expected " .. string.format((current.line > line) and "(to close 'function' at line %s)" or "", line), "End")
		return { kindof = "FunctionExpression", parameters = parameters, body = body }
	end
	return parseRecordExpression()
end

---@return Expression?
function parseExpression ()
	return parseFunctionExpression()
end

---@return StatementExpression?, boolean?
function parseStatement ()
	local decorations, exportable ---@type table<string, true>, boolean?
	while true do
		repeat
			local typeof, value, line = peek()
			-- Decorators
			if typeof == "At" then
				decorations = {}
				while suppose "At" do
					local name = expect("<name> expected", "Identifier") --[[@as string]]
					-- ExportDecoration
					if name == "export" then
						exportable = true
					end
					decorations[name] = true
				end
				break
			-- Comment
			elseif typeof == "Comment" then
				local content = {} ---@type string[]
				while current.typeof == "Comment" do
					content[#content + 1] = suppose("Comment")
				end
				return { kindof = "Comment", content = content }
			-- ImportDeclaration
			elseif typeof == "Import" then
				consume()
				local imports = catch("<record> or <name> expected", parseRecordExpression, "RecordLiteralExpression", "Identifier") --[[@as RecordLiteralExpression|Identifier]]
				local names = (imports.kindof == "Identifier") and imports or {}
				if imports.kindof == "RecordLiteralExpression" then
					for _, name in ipairs(imports.elements) do
						names[#names + 1] = (name.value.kindof == "Identifier") and name.value or throw("<name> expected") --[[@as Identifier]]
					end
				end
				expect("'from' expected", "From")
				local location = catch("<string> expected", parseTerm, "StringLiteral")
				return { kindof = "ImportDeclaration", names = names --[=[@as Identifier|Identifier[]]=], location = location }
			-- VariableDeclaration
			elseif typeof == "Var" then
				consume()
				local declarations = {} ---@type AssignmentExpression[]
				while current.typeof == "Identifier" or current.typeof == "LeftBracket" do
					local left = catch("<name> expected", parseExpression, "Identifier", exportable or "RecordLiteralExpression") --[[@as Identifier]]
					local right = suppose("Equal") and ((left.kindof == "RecordLiteralExpression") and catch("'<record> or '...' expected", parseExpression, "RecordLiteralExpression", "Ellipsis", "UnaryExpression") or parseExpression()) --[[@as Expression]]
					declarations[#declarations + 1] = { kindof = "AssignmentExpression", left = left, operator = "=", right = right }
					if not suppose "Comma" then
						break
					end
				end
				return { kindof = "VariableDeclaration", declarations = declarations, decorations = decorations }, exportable
			-- FunctionDeclaration
			elseif typeof == "Function" then
				consume()
				local body, parameters, exports = {}, {}, nil ---@type BlockStatement[], Identifier[], Identifier[]?
				local name = catch("<name> expected", parseMemberExpression, "Identifier", exportable or "MemberExpression") --[[@as Identifier|MemberExpression]]
				expect("'(' expected after <name>", "LeftParenthesis")
				while current.typeof == "Identifier" or current.typeof == "Ellipsis" do
					parameters[#parameters + 1] = catch("<name> expected", parseTerm, "Identifier", "Ellipsis")
					if not suppose "Comma" then
						break
					end
				end
				expect("')' expected", "RightParenthesis")
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'function' at line %s)" or "", line), "End")
				return { kindof = "FunctionDeclaration", name = name --[[@as Identifier|MemberExpression]], parameters = parameters, body = body, decorations = decorations }, exportable
			-- ReturnStatement
			elseif typeof == "Return" then
				consume()
				local arguments = { parseExpression() --[[@as Expression]] } ---@type Expression[]
				while suppose "Comma" do
					arguments[#arguments + 1] = parseExpression()
				end
				return { kindof = "ReturnStatement", arguments = arguments }
			-- PrototypeDeclaration
			elseif typeof == "Prototype" then
				consume()
				local name = catch("<name> expected", parseMemberExpression, "Identifier", exportable or "MemberExpression") --[[@as Expression]]
				local hasConstructor, body = false, {} ---@type boolean, PrototypeStatement[]
				expect("Missing '{' after <name>", "LeftBrace")
				local parent = (current.typeof ~= "RightBrace") and parseExpression() or nil ---@type Expression?
				expect("Missing '}'", "RightBrace")
				while current.typeof ~= "End" do
					local lastLine = current.line
					local statementExpression = catch("syntax error", parseStatement, "Comment", "VariableDeclaration", "VariableAssignment", "FunctionDeclaration") --[[@as Comment|VariableDeclaration|VariableAssignment|FunctionDeclaration]]
					-- catch function and variable names
					if statementExpression.kindof == "FunctionDeclaration" then
						if statementExpression.name.value == "constructor" then
							-- catch 'super' call
							if parent then
								local firstInnerStatement = statementExpression.body[1] --[[@as CallExpression]]
								if not (firstInnerStatement and firstInnerStatement.kindof == "CallExpression" and firstInnerStatement.caller.value == "super") then
									throw("'super' call required inside child prototype constructor", lastLine)
								end
							end
							-- catch abstract prototype
							if decorations and decorations["abstract"] then
								throw("abstract prototypes don't allow constructor implementations", lastLine)
							end
							-- catch multiple constructor implementations
							hasConstructor = hasConstructor and throw("multiple constructor implementations are not allowed", lastLine)
						elseif statementExpression.name.kindof ~= "Identifier" then
							throw("<name> expected", lastLine)
						end
					-- catch @get and @set assignments
					elseif statementExpression.kindof == "VariableAssignment" then
						if (statementExpression.decorations and (statementExpression.decorations["get"] or statementExpression.decorations["set"])) then
							local decoration = statementExpression.decorations["get"] and "@get" or "@set"
							-- catch multiple assignments
							if #statementExpression.assignments > 1 then
								throw("multiple '" .. decoration .. "' assignments are not allowed", lastLine)
							end
							-- catch variable names
							if statementExpression.assignments[1].left.kindof ~= "Identifier" then
								throw("<name> expected", lastLine)
							end
						-- catch wrong decorations
						else
							throw("'@get' or '@set' decoration missing", lastLine)
						end
					end
					body[#body + 1] = statementExpression
				end
				if not hasConstructor and parent then
					table.insert(body, 1, {
						kindof = "FunctionDeclaration",
						name = {
							kindof = "Identifier",
							value = "constructor"
						},
						parameters = {
							{
								kindof = "Ellipsis"
							}
						},
						body = {
							{
								kindof = "CallExpression",
								caller = {
									kindof = "Identifier",
									value = "super"
								},
								arguments = {
									{
										kindof = "Ellipsis"
									}
								}
							}
						}
					})
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'prototype' at line %s)" or "", line), "End")
				return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body, decorations = decorations }, exportable
			-- IfStatement
			elseif typeof == "If" then
				local node = {}
				local latest = node --[[@as IfStatement]]
				repeat
					if suppose("If", "Elseif") then
						latest.kindof, latest.test, latest.consequent = "IfStatement", parseExpression(), {}
						expect("'then' missing", "Then")
					end
					repeat
						local target = latest.consequent or latest --[[@as IfStatement]]
						target[#target + 1] = parseStatement()
						if current.typeof == "Elseif" or suppose("Else") then
							latest.alternate = {}
							latest = latest.alternate
						end
					until current.typeof == "Elseif" or current.typeof == "End"
				until current.typeof == "End"
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'if' at line %s)" or "", line), "End")
				return node
			-- WhileLoop
			elseif typeof == "While" then
				consume()
				local condition = parseExpression() --[[@as Expression]]
				expect("'do' expected", "Do")
				local body = {} ---@type BlockStatement[]
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'while' at line %s)" or "", line), "End")
				return { kindof = "WhileLoop", condition = condition, body = body }
			-- BreakStatement
			elseif typeof == "Break" then
				consume()
				return { kindof = "BreakStatement" }
			-- ForLoop
			elseif typeof == "For" then
				consume()
				local condition ---@type NumericLoopCondition|IterationLoopCondition
				local conditionVariable = catch("<name> expected", parseTerm, "Identifier") --[[@as Identifier]]
				if suppose "Equal" then
					local init = { kindof = "AssignmentExpression", left = conditionVariable, operator = "=", right = parseExpression() --[[@as Expression]] }
					expect("'to' expected", "To")
					condition = { init = init, goal = parseExpression(), step = suppose("Step") and parseExpression() } --[[@as NumericLoopCondition]]
				elseif current.typeof == "Comma" or current.typeof == "In" then
					local variable = { conditionVariable } ---@type Identifier[]
					while suppose "Comma" do
						if current.typeof ~= "Identifier" then
							throw("<name> expected near '" .. current.value .. "'")
						end
						variable[#variable + 1] = catch("<name> expected", parseTerm, "Identifier")
					end
					expect("'in' expected", "In")
					condition = { variable = variable, iterable = parseExpression() } --[[@as IterationLoopCondition]]
				else
					throw("'=' or 'in' expected near '" .. current.value .. "'")
				end
				expect("'do' missing", "Do")
				local body = {} ---@type StatementExpression[]
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'for' at line %s)" or "", line), "End")
				return { kindof = "ForLoop", condition = condition, body = body }
			-- CallExpression, NewExpression, VariableAssignment
			elseif typeof == "Identifier" or typeof == "LeftBracket" then
				local assignments = {} ---@type AssignmentExpression[]
				while current.typeof == "Identifier" or current.typeof == "LeftBracket" do
					local last, left = current.value, parseExpression() --[[@as Expression]]
					local operator, right ---@type string, Expression
					if left.kindof == "CallExpression" or left.kindof == "NewExpression" then
						if #assignments > 0 then
							throw("<assignment> expected near '" .. last .. "'")
						end
						return left
					elseif left.kindof == "RecordLiteralExpression" then
						operator, right = expect("'=' expected", "Equal"), catch("'<record> or '...' expected", parseExpression, "RecordLiteralExpression", "CallExpression", "Ellipsis", "UnaryExpression")
					elseif left.kindof == "MemberExpression" or left.kindof == "Identifier" then
						operator, right = expect("'=' expected", "Equal", "MinusEqual", "PlusEqual", "AsteriskEqual", "SlashEqual", "CircumflexEqual", "PercentEqual", "ConcatEqual"), parseExpression()
					else
						throw("syntax error near '" .. last .. "'")
					end
					assignments[#assignments + 1] = { kindof = "AssignmentExpression", left = left, operator = operator, right = right } --[[@as AssignmentExpression]]
					if not suppose "Comma" then
						break
					end
				end
				return { kindof = "VariableAssignment", assignments = assignments, decorations = decorations }
			end
			-- Unknown
			throw("unexpected symbol near '" .. value .. "'")
		until true
	end
end

--- Generates an AST from a raw source.
---@param location string The filename to parse.
---@param kindof string The AST kind.
---@return AST #The AST table.
return function (location, kindof)
	local file <close> = io.open(location) or error("Source file not found.")
	local source = file:read("*a")
	local ast, exports = { kindof = kindof, body = {} }, {} ---@type AST, table<string, true>
	path, current, pop, peek = location, scan(source)
	current.typeof, current.value, current.line = peek()
	while current.typeof do
		local statement, exportable = parseStatement()
		ast.body[#ast.body + 1] = statement
		if statement and exportable and ast.kindof == "Module" then
			local node = { kindof = "VariableAssignment", assignments = {} } ---@type VariableAssignment
			-- VariableDeclaration
			if statement.kindof == "VariableDeclaration" then
				for _, assignment in ipairs(statement.declarations) do
					local left = { kindof = "MemberExpression", record = { kindof = "Identifier", value = "exports" }, property = { kindof = "Identifier", value = assignment.left.value } --[[@as Identifier]], computed = false }
					if statement.decorations and statement.decorations["default"] then
						left.property.value = "default"
					end
					if exports[left.property.value] then
						throw("<name> must be unique, '" .. left.property.value .. "' already exported")
					end
					node.assignments[#node.assignments + 1], exports[left.property.value] = { kindof = "AssignmentExpression", left = left , operator = "=", right = assignment.left }, true
				end
			-- FunctionDeclaration or PrototypeDeclaration
			elseif statement.kindof == "FunctionDeclaration" or statement.kindof == "PrototypeDeclaration" then
				local left = { kindof = "MemberExpression", record = { kindof = "Identifier", value = "exports" }, property = { kindof = "Identifier", value = statement.name.value } --[[@as Identifier]], computed = false }
				if statement.decorations and statement.decorations["default"] then
					left.property.value = "default"
				end
				if exports[left.property.value] then
					throw("<name> must be unique, '" .. left.property.value .. "' already exported")
				end
				node.assignments[#node.assignments + 1], exports[left.property.value] = { kindof = "AssignmentExpression", left = left , operator = "=", right = statement.name }, true
			end
			ast.body[#ast.body + 1] = node
		end
	end
	return ast
end

---@class Lexeme
---@field typeof? string Lexeme type.
---@field value string Lexeme value.
---@field line integer Lexeme line number.
---@field startIndex? integer

---@alias LexicalScanner fun(): string?, string, integer, integer?
---@alias Parser<P, Q> fun(): P?, Q?
---@alias AST { kindof: "Program"|"Module", body: StatementExpression[], exports: table<string, boolean> }
