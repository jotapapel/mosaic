local scan = require "scanner"
local trace = require "tracer"

<<<<<<< HEAD
local current, keywords, pop, peek
local parseStatement, parseExpression

=======
---@type { typeof?: string, value: string, line: number }
local current
---@type fun(): string?, string, number, number
local pop
---@type fun(): string?, string, number
local peek
---@type fun(): Expression?
local parseExpression
---@type fun(): Expression|Statement
local parseStatement

--- Throw a local error.
---@param message string The error message.
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function throw (message)
	io.write("<mosaic> ", current.line, ": ", message, ".\n")
	os.exit()
end

--- Move on to the next lexeme, store the current one in the 'current' table.
---@return string typeof The lexeme type.
---@return string value The lexeme value.
local function consume ()
	local typeof, value = pop()
	current.typeof, current.value, current.line = peek()
<<<<<<< HEAD
	return typeof, value or "<eof>"
end

=======
	return typeof, value
end

--- Expect a specific lexeme from the scanner, throw an error when not found.
---@param expected string|table<string, true> The expected type.
---@param message string The error message.
---@return string #The expected lexeme value.
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function expect (expected, message)
	local lookup = (type(expected) == "string") and { [expected] = true } or expected
	local typeof, value = consume()
	if not lookup[typeof] then
		throw(message .. " near '" .. value .. "'")
	end
	return value
end

<<<<<<< HEAD
=======
--- If there is an specific lexeme as the current one, consume it, else, do nothing.
---@param supposed string|table<string, true> The supposed lexeme type.
---@return string? #The supposed lexeme value.
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function suppose (supposed)
	local lookup = (type(supposed) == "string") and { [supposed] = true } or supposed
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

<<<<<<< HEAD
-- Term = UnaryExpression | Identifier | StringLiteral | NumberLiteral | BooleanLiteral | Undefined
local function parseTerm ()
	local typeof, value = consume()
	-- UnaryExpression { kindof: "UnaryExpression", operator: "-" | "$" | "#" | "!", argument: Expression }
	if typeof == "Minus" or typeof == "Dollar" or typeof == "Pound" or typeof == "Bang" then
		return { kindof = "UnaryExpression", operator = value, value = parseExpression() }
	-- Identifier { kindof: "Identifier", value: string }
	elseif typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	-- StringLiteral { kindof: "StringLiteral", value: string }
	elseif typeof == "String" then
		return { kindof = "StringLiteral", value = value:sub(2, -2) }
	-- NumberLiteral { kindof: "NumberLiteral", value: number }
	elseif typeof == "Number" then
		return { kindof = "NumberLiteral", value = tonumber(value) }
	elseif typeof == "Hexadecimal" then
		return { kindof = "NumberLiteral", value = tonumber(value:sub(2), 16) }
	-- BooleanLiteral { kindof: "BooleanLiteral", value: "true" | "false" }
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	-- Undefined { kindof: "Undefined" }
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	-- expression inside parenthesis
	elseif typeof == "LeftParenthesis" then
		value = parseExpression()
		expect("RightParenthesis", "')' expected near " .. current.value .. ".")
		return value
	end
end

-- MemberExpression { kindof: "MemberExpression", identifier: Identifier, property: Expression }
local function parseMemberExpression ()
	local node = parseTerm()
=======
---@return (Term|Expression)?
local function parseTerm ()
	local typeof, value = current.typeof, current.value
	---@alias UnaryExpression { kindof: "UnaryExpression", operator: "-" | "$" | "#" | "!", argument: Expression }
	if typeof == "Minus" or typeof == "Dollar" or typeof == "Pound" or typeof == "Bang" then
		consume()
		return { kindof = "UnaryExpression", operator = value, value = parseExpression() }
	---@alias Identifier { kindof: "Identifier", value: string }
	elseif typeof == "Identifier" then
		consume()
		return { kindof = "Identifier", value = value }
	---@alias StringLiteral { kindof: "StringLiteral", value: string }
	elseif typeof == "String" then
		consume()
		return { kindof = "StringLiteral", value = value:sub(2, -2) }
	---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
	elseif typeof == "Number" then
		consume()
		return { kindof = "NumberLiteral", value = tonumber(value) }
	elseif typeof == "Hexadecimal" then
		consume()
		return { kindof = "NumberLiteral", value = tonumber(value:sub(2), 16) }
	---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true" | "false" }
	elseif typeof == "Boolean" then
		consume()
		return { kindof = "BooleanLiteral", value = value }
	---@alias Undefined { kindof: "Undefined" }
	elseif typeof == "Undefined" then
		consume()
		return { kindof = "Undefined" }
	-- expression inside parenthesis
	elseif typeof == "LeftParenthesis" then
		---@type Expression
		local expression = parseExpression()
		expect("RightParenthesis", "')' expected near " .. current.value .. ".")
		return expression
	end
	-- unknown symbol
	throw("unexpected symbol near '" .. value .. "'")
end

---@return MemberExpression
local function parseMemberExpression ()
	local record = parseTerm()
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	while current.typeof == "Dot" or current.typeof == "LeftBracket" do
		---@type Expression, boolean
		local property, computed
		local typeof, value = consume()
		if typeof == "Dot" then
			property, computed = parseTerm(), false
			if not property or property.kindof ~= "Identifier" then
				throw("syntax error near '" .. value .. (property and property.value or "") .. "'")
			end
		else
			value, property, computed = current.value, parseExpression(), true
<<<<<<< HEAD
			if not property then 
				throw("unexpected symbol near '" .. value .. "'")
			end
			expect("RightBracket", "']' missing") 
		end
		node = { kindof = "MemberExpression", record = node, property = property, computed = computed }
=======
			expect("RightBracket", "']' missing")
		end
		record = { kindof = "MemberExpression", record = record, property = property, computed = computed }
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	end
	return node
end

<<<<<<< HEAD
--- CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
local function parseCallExpression (caller)
	local caller = parseMemberExpression()
	while current.typeof == "LeftParenthesis" do
		consume()
		caller = { kindof = "CallExpression", caller = caller, arguments = {} }
=======
---@param caller (CallExpression|MemberExpression)?
---@return MemberExpression|CallExpression
local function parseCallExpression (caller)
	caller = parseMemberExpression()
	while current.typeof == "LeftParenthesis" do
		caller = { kindof = "CallExpression", caller = caller, arguments = {} }
		consume()
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
		repeat
			table.insert(caller.arguments, parseExpression())
			if current.typeof ~= "RightParenthesis" then
				expect("Comma", "')' expected")
			end
		until current.typeof == "RightParenthesis"
		expect("RightParenthesis", "')' expected")
<<<<<<< HEAD
		if current.typeof ~= "LeftParenthesis" then
			break
		end
=======
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	end
	return caller
end

<<<<<<< HEAD
-- Operator = "and" | "or" | "==" | ">" | "<" | ">=" | "<=" | "<>" | "+" | "-" | "*" | "/" | "^" | "%"
-- BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: Operator, right: Expression }
local function parseMultiplicativeExpression ()
=======
---@return BinaryExpression|CallExpression|MemberExpression
local function parseMultiplicativeExpression ()
	---@type BinaryExpression|CallExpression|MemberExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	local left = parseCallExpression()
	while current.typeof == "Asterisk" or current.typeof == "Slash" 
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseCallExpression() }
	end
	return left
end

<<<<<<< HEAD
=======
---@return BinaryExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function parseAdditiveExpression ()
	local left = parseMultiplicativeExpression()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseMultiplicativeExpression() }
	end
	return left
end

<<<<<<< HEAD
=======
---@return BinaryExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function parseComparisonExpression ()
	local left = parseAdditiveExpression()
	while current.typeof == "IsEqual" or current.typeof == "Greater" or current.typeof == "Less"
		  or current.typeof == "GreaterEqual" or current.typeof == "LessEqual" or current.typeof == "NotEqual" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseAdditiveExpression() }
	end
	return left
end

<<<<<<< HEAD
=======
---@return BinaryExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function parseLogicalExpression ()
	local left = parseComparisonExpression()
	while current.typeof == "And" or current.typeof == "Or" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseComparisonExpression() }
	end
	return left
end

<<<<<<< HEAD
-- RecordElement { kindof: "RecordElement", key?: Identifier, value: Expression }
-- RecordLiteralExpression { kindof: "RecordLiteral", properties: RecordElement[] }
=======
---@return RecordLiteralExpression|BinaryExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function parseRecordExpression ()
	if current.typeof ~= "LeftBracket" then
		return parseLogicalExpression()
	end
	consume()
	---@type RecordElement[]
	local properties = {}
	while current.typeof ~= "RightBracket" do
		local key
		if current.typeof == "Identifier" then
			key = parseTerm()
			expect({ ["Comma"] = true, ["Colon"] = true }, "']' expected")
<<<<<<< HEAD
		end
		table.insert(properties, { kindof = "RecordMember", key = key, value = parseExpression() })
		if current.typeof ~= "RightBracket" then
			expect("Comma", "']' expected")
=======
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
		end
		properties[#properties + 1] = { kindof = "RecordElement", key = key, value = parseExpression() }
		suppose("Comma")
	end
	expect("RightBracket", "']' expected")
	return { kindof = "RecordLiteralExpression", properties = properties }
end

<<<<<<< HEAD
-- AssignmentExpression { kindof: "AssignmentExpression", left: Identifier | RecordMember, operator: string, right: Expression }
=======
---@return AssignmentExpression|RecordLiteralExpression|BinaryExpression
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
local function parseAssignmentExpression ()
	local left = parseRecordExpression()
	if suppose("Equal") then
		return { kindof = "AssignmentExpression", left = left, operator = "=", right = parseExpression() }
<<<<<<< HEAD
=======
	end
	return left
end

---@return Expression?
function parseExpression ()
	return parseAssignmentExpression()
end

---@return Statement|Expression
function parseStatement ()
	local typeof, value, line = peek()
	-- Comment
	if typeof == "Comment" then
		consume()
		return { kindof = "Comment", content = value:sub(3) }
	-- VariableDeclaration
	elseif typeof == "Var" then
		consume()
		---@type VariableDeclarator[]
		local declarations = {}
		if current.typeof == "Identifier" then
			while current.typeof == "Identifier" do
				local identifier = parseTerm()
				local init = suppose("Equal") and parseExpression()
				declarations[#declarations + 1] = { kindof = "VariableDeclarator", identifier = identifier, init = init }
				suppose("Comma")
			end
		else
			throw("<name> expected near '" .. current.value .. "'")
		end
		return { kindof = "VariableDeclaration", declarations = declarations }
	-- FunctionDeclaration
	elseif typeof == "Function" then
		consume()
		---@type BlockStatement[]
		local body = {}
		---@type MemberExpression | Identifier
		local name = parseMemberExpression()
		---@type Identifier[]
		local parameters = {}
		expect("LeftParenthesis", "missing '(' after <name>")
		while current.typeof ~= "RightParenthesis" do
			parameters[#parameters + 1] = parseTerm()
			suppose("Comma")
		end
		expect("RightParenthesis", "')' expected")
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement()
		end
		local err = (current.line > line) and string.format("(to close 'function' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return { kindof = "FunctionDeclaration", name = name, parameters = parameters, body = body }
	-- ReturnStatement
	elseif typeof == "Return" then
		consume()
		return { kindof = "ReturnStatement", argument = parseExpression() }
	-- PrototypeDeclaration
	elseif typeof == "Prototype" then
		consume()
		---@type BlockStatement[]
		local body = {}
		local name = parseMemberExpression()
		expect("LeftBrace", "Missing '{' after <name>")
		local parent = parseExpression()
		expect("RightBrace", "Missing '}'")
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement()
		end
		local err = (current.line > line) and string.format("(to close 'prototype' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body }
	-- IfStatement
	elseif typeof == "If" then
		---@type { kindof: "IfStatement", test?: Expression, consequent: Statement[], alternate?: Statement[] }
		local node = { kindof = "IfStatement", consequent = {} }
		---@type Statement[]
		local consequent
		while current.typeof ~= "End" do
			if suppose({ ["If"] = true, ["Elseif"] = true }) then
				node.test, consequent = parseExpression(), node.consequent
				expect("Then", "'then' expected")
			elseif suppose("Else") then
				consequent = node.consequent or node.alternate or node
			end
			repeat
				consequent[#consequent + 1] = parseStatement()
				if current.typeof == "Elseif" or current.typeof == "Else" then
					node.alternate = (current.typeof == "Elseif") and { kindof = "IfStatement", consequent = {} } or {}
					node = node.alternate
					break
				end
			until current.typeof == "Elseif" or current.typeof == "Else" or current.typeof == "End"
		end
		local err = (current.line > line) and string.format("(to close 'if' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return node
	-- WhileLoop
	elseif typeof == "While" then
		consume()
		local condition = parseExpression()
		expect("Do", "'do' expected")
		---@type Statement[]
		local body = {}
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement()
		end
		local err = (current.line > line) and string.format("(to close 'while' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return { kindof = "WhileLoop", condition = condition, body = body }
	-- BreakStatement
	elseif typeof == "Break" then
		consume()
		return { kindof = "BreakStatement" }
	-- ForLoop
	elseif typeof == "For" then
		consume()
		---@type Expression, Expression
		local goal, step
		---@type Identifier[], Expression
		local variable, iterable
		---@type Expression?
		local init = parseExpression()
		if init and init.kindof == "AssignmentExpression" then
			expect("To", "'to' expected")
			goal, step = parseExpression(), suppose("Step") and parseExpression()
		elseif init and init.kindof == "Identifier" then
			variable, init = { init }, nil
			suppose("Comma")
			while current.typeof == "Identifier" do
				table.insert(variable, parseTerm())
				suppose("Comma")
			end
			expect("In", "'in' expected")
			iterable = parseExpression()
		end
		expect("Do", "'do' missing")
		---@type Statement[]
		local body = {}
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement()
		end
		local err = (current.line > line) and string.format("(to close 'for' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return { kindof = "ForLoop", init = init, variable = variable, goal = goal, step = step, iterable = iterable }
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
	end
	return parseExpression()
end

<<<<<<< HEAD
function parseExpression()
	return parseAssignmentExpression()
end

-- Statement = Comment | VariableDeclaration | FunctionDeclaration
-- BlockStatement = Statement | AssignmentExpression | CallExpression
function parseStatement (kindof)
	local typeof, value, line = peek()
	-- Comment { kindof: "Comment", content: string }
	if typeof == "Comment" then
		consume()
		return { kindof = "Comment", content = value:sub(3) }
	elseif keywords[value] then
		consume()
		-- VariableDeclarator { kindof: "VariableDeclarator", identifier: Identifier, init?: Expression }
		-- VariableDeclaration { kindof: "VariableDeclaration", declarations: VariableDeclarator[] }
		if typeof == "Var" then
			local declarations = {}
			while current.typeof == "Identifier" do
				local identifier = expect("Identifier", "<name> expected")
				local init = suppose("Equal") and parseExpression()
				table.insert(declarations, { kindof = "VariableDeclarator", identifier = identifier, init = init })
				suppose("Comma")
			end
			return { kindof = "VariableDeclaration", declarations = declarations }
		-- FunctionDeclaration { kindof: "FunctionDeclaration", name: Identifier | RecordMember, parameters: Identifier[], body: BlockStatement[] }
		elseif typeof == "Function" then
			local body = {}
			local name = parseMemberExpression()
			local parameters = {}
			expect("LeftParenthesis", "missing '(' after <name>")
			if current.typeof ~= "RightParenthesis" then
				while current.typeof ~= "RightParenthesis" do
					table.insert(parameters, expect("Identifier", "<name> expected"))
					if current.typeof ~= "RightParenthesis" then
						expect("Comma", "')' expected")
					end
				end
			end
			expect("RightParenthesis", "')' expected")
			while current.typeof and current.typeof ~= "End" do
				table.insert(body, parseStatement())
			end
			local err = (current.line > line) and string.format("(to close 'function' at line %s) ", line) or ""
			expect("End", "'end' expected " .. err)
			return { kindof = "FunctionDeclaration", name = name, parameters = parameters, body = body }
		end
		-- wrong keyword
		throw("unexpected symbol near '" .. value .. "'.")
	end
	return parseExpression()
end

return function (source)
	current, keywords, pop, peek = {}, scan(source)
	return function ()
		current.typeof, current.value, current.line = peek()
		if current.typeof then
			return parseStatement("Program")
=======
---@param source string The raw source.
---@return (Statement|Expression)?
return function (source)
	current, pop, peek = scan(source)
	---@return (Statement|Expression)?
	return function ()
		current.typeof, current.value, current.line = peek()
		if current.typeof then
			return parseStatement()
>>>>>>> c0e6c07 (1st alpha of the parser, added Lua type checking)
		end
	end
end