local scan = require "scanner"
local trace = require "tracer"

local current, keywords, pop, peek
local parseStatement, parseExpression

local function throw (message)
	io.write("<mosaic> ", current.line, ": ", message, ".\n")
	os.exit()
end

local function consume ()
	local typeof, value = pop()
	current.typeof, current.value, current.line = peek()
	return typeof, value or "<eof>"
end

local function expect (expected, message)
	local lookup = (type(expected) == "string") and { [expected] = true } or expected
	local typeof, value = consume()
	if not lookup[typeof] then
		throw(message .. " near '" .. value .. "'")
	end
	return value
end

local function suppose (supposed)
	local lookup = (type(supposed) == "string") and { [supposed] = true } or supposed
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

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
	while current.typeof == "Dot" or current.typeof == "LeftBracket" do
		local property, computed
		local typeof, value = consume()
		if typeof == "Dot" then
			property, computed = parseTerm(), false
			if not property or property.kindof ~= "Identifier" then
				throw("syntax error near '" .. value .. (property and property.value or "") .. "'")
			end
		else
			value, property, computed = current.value, parseExpression(), true
			if not property then 
				throw("unexpected symbol near '" .. value .. "'")
			end
			expect("RightBracket", "']' missing") 
		end
		node = { kindof = "MemberExpression", record = node, property = property, computed = computed }
	end
	return node
end

--- CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
local function parseCallExpression (caller)
	local caller = parseMemberExpression()
	while current.typeof == "LeftParenthesis" do
		consume()
		caller = { kindof = "CallExpression", caller = caller, arguments = {} }
		repeat
			table.insert(caller.arguments, parseExpression())
			if current.typeof ~= "RightParenthesis" then
				expect("Comma", "')' expected")
			end
		until current.typeof == "RightParenthesis"
		expect("RightParenthesis", "')' expected")
		if current.typeof ~= "LeftParenthesis" then
			break
		end
	end
	return caller
end

-- Operator = "and" | "or" | "==" | ">" | "<" | ">=" | "<=" | "<>" | "+" | "-" | "*" | "/" | "^" | "%"
-- BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: Operator, right: Expression }
local function parseMultiplicativeExpression ()
	local left = parseCallExpression()
	while current.typeof == "Asterisk" or current.typeof == "Slash" 
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseCallExpression() }
	end
	return left
end

local function parseAdditiveExpression ()
	local left = parseMultiplicativeExpression()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseMultiplicativeExpression() }
	end
	return left
end

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

local function parseLogicalExpression ()
	local left = parseComparisonExpression()
	while current.typeof == "And" or current.typeof == "Or" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseComparisonExpression() }
	end
	return left
end

-- RecordElement { kindof: "RecordElement", key?: Identifier, value: Expression }
-- RecordLiteralExpression { kindof: "RecordLiteral", properties: RecordElement[] }
local function parseRecordExpression ()
	if current.typeof ~= "LeftBracket" then
		return parseLogicalExpression()
	end
	consume()
	local properties = {}
	while current.typeof ~= "RightBracket" do
		local key
		if current.typeof == "Identifier" then
			key = parseTerm()
			expect({ ["Comma"] = true, ["Colon"] = true }, "']' expected")
		end
		table.insert(properties, { kindof = "RecordMember", key = key, value = parseExpression() })
		if current.typeof ~= "RightBracket" then
			expect("Comma", "']' expected")
		end
	end
	expect("RightBracket", "']' expected")
	return { kindof = "RecordLiteralExpression", properties = properties }
end

-- AssignmentExpression { kindof: "AssignmentExpression", left: Identifier | RecordMember, operator: string, right: Expression }
local function parseAssignmentExpression ()
	local left = parseRecordExpression()
	if suppose("Equal") then
		return { kindof = "AssignmentExpression", left = left, operator = "=", right = parseExpression() }
	end
	return left
end

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
		end
	end
end