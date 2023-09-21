local trace = require "tracer"
local scan = require "scanner"

local current, pop, peek
local parseExpression, parseStatement

local function syntaxError (msg, value, line)
	io.write("<mosaic> ", line or current.line, ": ", msg," near '", value or current.value, "'.", "\n")
	os.exit()
end

local function consume ()
	local typeof, value, _, line = pop()
	current.typeof, current.value, current.line = peek()
	return typeof, value, line
end

local function expect (expectedType, msg)
	local typeof, value, line = consume()
	if typeof ~= expectedType then
		msg = msg or string.format("expecting <%s>", expectedType:lower())
		syntaxError(msg, value, line)
	end
	return value
end

-- type Term = Identifier | StringLiteral | NumberLiteral | BooleanLiteral | Undefined
local function parseTerm ()
	local typeof, value = consume()
	-- type Identifier = { kindof: "Identifier", value: string }
	if typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	-- type StringLiteral = { kindof: "StringLiteral", value: string }
	elseif typeof == "String" then
		return { kindof = "StringLiteral", value = value:sub(2, -2) }
	-- type NumberLiteral = { kindof: "NumberLiteral", value: string }
	elseif typeof == "Number" then
		return { kindof = "NumberLiteral", value = value:gsub("&", "0x") }
	-- type BooleanLiteral = { kindof: "BooleanLiteral", value: string }
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	-- type Undefined = { kindof: "Undefined" }
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	elseif typeof == "LeftParenthesis" then
		value = parseExpression()
		expect("RightParenthesis", "')' expected")
		return value
	end
end

-- interface UnaryExpression { kindof: "UnaryExpression", operator: string, argument: Expression }
local function parseUnary ()
	if current.typeof == "Minus" or current.typeof == "Dollar"
	   or current.typeof == "Pound" or current.typeof == "Bang" then
		local operator = current.value
		consume()
		return { kindof = "UnaryExpression", operator = operator, value = parseExpression() }
	end
	return parseTerm()
end

-- interface MemberExpression { kindof: "MemberExpression", record: Identifier, property: Identifier }
local function parseMember ()
	local record = parseUnary()
	while current.typeof == "Dot" or current.typeof == "LeftBracket" do
		local property, computed
		local typeof, value = consume()
		if typeof == "Dot" then
			property, computed = parseTerm(), false
			if not property or property.kindof ~= "Identifier" then
				syntaxError("unknown symbol found", value)
			end
		else
			property, computed = parseExpression(), true
			expect("RightBracket", "missing ']'") 
		end
		record = { kindof = "MemberExpression", record = record, property = property }
	end
	return record
end

local function parseArgumentList ()
	local arguments = { parseExpression() }
	while current.typeof == "Comma" do
		consume()
		table.insert(arguments, parseExpression())
	end
	return arguments
end

local function parseArguments ()
	local arguments
	expect("LeftParenthesis", "'(' expected")
	if current.typeof ~= "RightParenthesis" then
		arguments = parseArgumentList()
	end
	expect("RightParenthesis", "')' expected")
	return arguments
end

-- interface CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
local function parseCall (caller)
	local expression = { kindof = "CallExpression", caller = caller, arguments = parseArguments() }
	if current.typeof == "LeftParenthesis" then
		expression = parseCall(expression)
	end
	return expression
end

local function parseCallMember ()
	local member = parseMember()
	if current.typeof == "LeftParenthesis" then
		return parseCall(member)
	end
	return member
end

-- interface BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: string, right: Expression }
local function parseMultiplicative ()
	local left = parseCallMember()
	while current.typeof == "Asterisk" or current.typeof == "Slash"
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseCallMember() }
	end
	return left
end

-- interface BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: string, right: Expression }
local function parseAdditive ()
	local left = parseMultiplicative()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseMultiplicative() }
	end
	return left
end

-- interface BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: string, right: Expression }
local function parseComparison ()
	local left = parseAdditive()
	while current.typeof == "IsEqual" or current.typeof == "Greater" or current.typeof == "Less"
		  or current.typeof == "GreaterEqual" or current.typeof == "LessEqual" or current.typeof == "NotEqual" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseAdditive() }
	end
	return left
end

-- interface BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: string, right: Expression }
local function parseLogical ()
	local left = parseComparison()
	while current.typeof == "And" or current.typeof == "Or" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseComparison() }
	end
	return left
end

-- type RecordElement = { kindof: "RecordElement", value: Expression }
-- type RecordMember = { kindof: "RecordMember", key: Identifier, value: Expression }
-- interface RecordLiteral { kindof: "RecordLiteral", properties: (RecordMember | RecordElement)[] }
local function parseRecord ()
	if current.typeof ~= "LeftBracket" then
		return parseLogical()
	end
	consume()
	local properties = {}
	local typeof, value
	while typeof ~= "RightBracket" do
		repeat
			if current.typeof == "Identifier" then
				typeof, value = consume()
				if current.typeof == "RightBracket" or current.typeof == "Comma" then
					table.insert(properties, { kindof = "RecordElement", value = value })
					typeof, value = consume()
					break
				end
				expect("Colon")
			end
			table.insert(properties, { kindof = "RecordMember", key = value, value = parseExpression() })
			if current.typeof == "RightBracket" or current.typeof == "Comma" then
				typeof, value = consume()
				break
			end
		until typeof == "RightBracket"
	end
	return { kindof = "RecordLiteral", properties = properties }
end

-- type Expression = RecordLiteral | BinaryExpression | CallExpression | MemberExpression | UnaryExpression | Term
function parseExpression ()
	return parseRecord()
end

local function parseName (self)
	local name = parseMember()
	if not (name.kindof == "MemberExpression" or name.kindof == "Identifier") then
		syntaxError("<name> expected")
	end
	return name
end

local function parseParameters ()
	local parameters
	expect("LeftParenthesis", "missing '(' after <name>")
	if current.typeof ~= "RightParenthesis" then
		parameters = {}
		while current.typeof ~= "RightParenthesis" do
			table.insert(parameters, expect("Identifier", "expecting <name>"))
			if current.typeof ~= "RightParenthesis" then
				expect("Comma", "expecting ')'")
			end
		end
	end
	expect("RightParenthesis", "missing ')' to close function parameters")
	return parameters
end

function parseStatement(kindof)
	local typeof, value, line = peek()
	-- interface Comment { kindof: "Comment", content: string }
	if typeof == "Comment" then
		consume()
		return { kindof = "Comment", content = value:sub(3) }
	-- type VariableDeclarator = { kindof: "VariableDeclarator", identifier: Identifier, init?: Expression }
	-- interface VariableDeclaration { kindof: "VariableDeclaration", declarations: VariableDeclarator[] }
	elseif typeof == "Var" then
		consume()
		local declarations = {}
		while true do
			repeat
				local init
				local identifier = expect("Identifier", "<name> expected")
				if not (current.typeof == "Equal" or current.typeof == "Comma") then
					syntaxError("unexpected symbol near")
				elseif current.typeof == "Equal" then
					consume()
					init = parseExpression()
				end
				table.insert(declarations, { kindof = "VariableDeclarator", identifier = identifier, init = init })
				if current.typeof == "Comma" then
					consume()
					break
				end
				return { kindof = "VariableDeclaration", declarations = declarations }
			until true
		end
	-- interface FunctionDeclaration { kindof: "FunctionDeclaration", name: Identifier | RecordMember, parameters: Identifier[], body: Statement[] }
	elseif typeof == "Function" then
		consume()
		local body = {}
		local name = parseName()
		local parameters = parseParameters()
		while peek() and current.typeof ~= "End" do
			table.insert(body, parseStatement("FunctionDeclaration"))
		end
		expect("End", "'end' expected (to close 'function' at line " .. line .. ")")
		return { kindof = "FunctionDeclaration", name = name, parameters = parameters, body = body }
	-- interface ReturnStatement { kindof: "ReturnStatement", argument: Expression }
	elseif typeof == "Return" then
		consume()
		local argument = parseExpression()
		return { kindof = "ReturnStatement", argument = argument }
	-- interface PrototypeDeclaration { kindof "PrototypeDeclaration", name: Identifier | RecordMember,
	--									parent: Identifier | RecordMember, body: (Comment | VariableDeclaration | FunctionDeclaration)[] }
	elseif typeof == "Prototype" then
		consume()
		local body = {}
		local name = parseName()
		expect("LeftBrace", "missing '{' after <name>")
		local parent = parseName()
		expect("RightBrace", "missing '}' to close prototype parent")
		while peek() and current.typeof ~= "End" do
			table.insert(body, parseStatement("PrototypeDeclaration"))
		end
		self:expect("End", "'end' expected (to close 'prototype' at line " .. line .. ")")
		return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body }
	-- interface IfStatement { kindof: "IfStatement", test: Expression, consequent: Statement[], alternate?: IfStatement | Statement[] }
	elseif typeof == "If" then
		local statementNode = { kindof = "IfStatement", consequent = {} }
		local currentNode = statementNode
		while current.typeof ~= "End" do
			local typeof = consume()
			if typeof == "If" or typeof == "Elseif" then
				currentNode.test = parseExpression()
				expect("Then", "'then' expected")
			end
			repeat
				table.insert(currentNode.consequent or currentNode, parseStatement("IfStatement"))
				if current.typeof == "Elseif" or current.typeof == "Else" then
					statementNode.alternate = (current.typeof == "Elseif") and { kindof = "IfStatement", consequent = {} } or {}
					currentNode = statementNode.alternate
					break
				end
			until current.typeof == "Elseif" or current.typeof == "Else" or current.typeof == "End"
		end
		expect("End", "'end' expected (to close 'if' at line " .. line .. ")")
		return statementNode
	-- interface WhileLoop { kindof: "WhileLoop", condition: Expression, body: Statement[] }
	elseif typeof == "While" then
		consume()
		local condition = parseExpression()
		expect("Do", "'do' expected")
		local body = {}
		while current.typeof ~= "End" do
			table.insert(body, parseStatement("WhileLoop"))
		end
		expect("End", "'end' expected (to close 'while' at line " .. line .. ")")
		return { kindof = "WhileLoop", condition = condition, body = body }
	-- interface BreakStatement { kindof: "BreakStatement" }
	elseif typeof == "Break" then
		consume()
		return { kindof = "BreakStatement" }
	end
	-- interface AssignmentExpression { kindof: "AssignmentExpression", left: Identifier | RecordMember, operator: string, right: Expression }
	local left = parseExpression()
	if current.typeof == "Equal" then
		local operator = current.value
		consume()
		return { kindof = "AssignmentExpression", left = left, operator = operator, right = parseExpression() }
	end
	return left
end

return function (source)
	current, pop, peek = {}, scan(source)
	return function ()
		current.typeof, current.value, current.line = peek()
		if current.typeof then
			return parseStatement("program")
		end
	end
end