local scan = require "scanner"

---@type Lexeme, NextLexeme, CurrentLexeme
local current, pop, peek
local parseExpression, parseStatement

--- Throw a local error.
---@param message string The error message.
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

---@return Expression?
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
		expect("RightParenthesis", "')' expected")
		return expression
	end
	-- unknown symbol
	throw("unexpected symbol near '" .. value .. "'")
end

---@return MemberExpression
local function parseMemberExpression ()
	local record = parseTerm()
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
			property, computed = parseExpression(), true
			expect("RightBracket", "']' missing")
		end
		record = { kindof = "MemberExpression", record = record, property = property, computed = computed }
	end
	return record
end

---@param caller? CallExpression|MemberExpression
---@return MemberExpression|CallExpression
local function parseCallExpression (caller)
	caller = parseMemberExpression()
	while current.typeof == "LeftParenthesis" do
		caller = { kindof = "CallExpression", caller = caller, arguments = {} }
		consume()
		repeat
			table.insert(caller.arguments, parseExpression())
			if current.typeof ~= "RightParenthesis" then
				expect("Comma", "')' expected")
			end
		until current.typeof == "RightParenthesis"
		expect("RightParenthesis", "')' expected")
	end
	return caller
end

---@return BinaryExpression|CallExpression|MemberExpression
local function parseMultiplicativeExpression ()
	---@type BinaryExpression|CallExpression|MemberExpression
	local left = parseCallExpression()
	while current.typeof == "Asterisk" or current.typeof == "Slash" 
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseCallExpression() }
	end
	return left
end

---@return BinaryExpression
local function parseAdditiveExpression ()
	local left = parseMultiplicativeExpression()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseMultiplicativeExpression() }
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
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseAdditiveExpression() }
	end
	return left
end

---@return BinaryExpression
local function parseLogicalExpression ()
	local left = parseComparisonExpression()
	while current.typeof == "And" or current.typeof == "Or" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseComparisonExpression() }
	end
	return left
end

---@return RecordLiteralExpression|BinaryExpression
local function parseRecordExpression ()
	if current.typeof ~= "LeftBracket" then
		return parseLogicalExpression()
	end
	consume()
	---@type RecordElement[]
	local properties = {}
	while current.typeof ~= "RightBracket" do
		---@type Term?
		local key
		if current.typeof == "Identifier" then
			key = parseTerm()
			expect({ ["Comma"] = true, ["Colon"] = true }, "']' expected")
		end
		properties[#properties + 1] = { kindof = "RecordElement", key = key, value = parseExpression() }
		suppose("Comma")
	end
	expect("RightBracket", "']' expected")
	return { kindof = "RecordLiteralExpression", properties = properties }
end

---@return AssignmentExpression|RecordLiteralExpression|BinaryExpression
local function parseAssignmentExpression ()
	local left = parseRecordExpression()
	if suppose("Equal") then
		return { kindof = "AssignmentExpression", left = left, operator = "=", right = parseExpression() }
	end
	return left
end

---@return Expression?
function parseExpression ()
	return parseAssignmentExpression()
end

---@return StatementExpression?
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
				local identifier = parseExpression()
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
		local body, name = {}, parseMemberExpression()
		---@type Expression[]
		local parameters = {}
		expect("LeftParenthesis", "missing '(' after <name>")
		while current.typeof ~= "RightParenthesis" do
			parameters[#parameters + 1] = parseExpression()
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
		local body, name = {}, parseExpression()
		expect("LeftBrace", "Missing '{' after <name>")
		---@type Expression?
		local parent = (current.typeof ~= "RightBrace") and parseExpression()
		expect("RightBrace", "Missing '}'")
		while current.typeof ~= "End" do
			body[#body + 1] = parseStatement()
		end
		local err = (current.line > line) and string.format("(to close 'prototype' at line %s) ", line) or ""
		expect("End", "'end' expected " .. err)
		return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body }
	-- IfStatement
	elseif typeof == "If" then
		---@type IfStatement|BlockStatement[]
		local node = { kindof = "IfStatement", consequent = {} }
		---@type Statement[]
		local consequent
		while current.typeof ~= "End" do
			if suppose({ ["If"] = true, ["Elseif"] = true }) then
				node.test, consequent = parseExpression(), node.consequent
				expect("Then", "'then' expected")
			elseif suppose("Else") then
				consequent = node.consequent or node
			end
			repeat
				consequent[#consequent + 1] = parseStatement()
				if current.typeof == "Elseif" or current.typeof == "Else" then
					---@type BlockStatement[]
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
		---@type Expression?, Expression?
		local goal, step
		---@type Identifier[]?, Expression?
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
				variable[#variable + 1] = parseTerm()
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
	end
	return parseExpression()
end

---@param source string The raw source.
---@return fun(): StatementExpression?
return function (source)
	current, pop, peek = scan(source)
	---@return StatementExpression?
	return function ()
		current.typeof, current.value, current.line = peek()
		if current.typeof then
			return parseStatement()
		end
	end
end