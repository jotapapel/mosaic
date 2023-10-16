local scan = require "frontend.scanner"
local json = require "json"

local current, pop, peek ---@type Lexeme, NextLexeme, CurrentLexeme
local parseExpression, parseStatement ---@type ExpressionParser, StatementParser
local escapedCharacters <const> = { [116] = "\t", [92] = "\\", [34] = "\"", [98] = "\b", [102] = "\f", [110] = "\n", [114] = "\r" }

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
	return typeof, value or "<eof>"
end

--- Expect a specific lexeme(s) from the scanner, throw an error when not found.
---@param message string The error message.
---@param ... string The expected types.
local function expect (message, ...)
	local lookup = {}
	for _, expected in ipairs({...}) do lookup[expected] = true end
	local typeof, value = consume()
	if not lookup[typeof] then
		throw(message .. " near '" .. value .. "'")
	end
end

--- Suppose a specific lexeme(s) from the scanner, consume it when found, do nothing otherwise.
---@param ... string The supposed lexeme types.
---@return string? #The supposed lexeme value.
local function suppose (...)
	local lookup = {}
	for _, expected in ipairs({...}) do lookup[expected] = true end
	local typeof, value = peek()
	if lookup[typeof] then
		consume()
		return value
	end
end

--- Check the kind of a node generated by a parsing function, throw an error when there's a mismatch.
---@param message? string The error message.
---@param parseFunc function The node to check.
---@param ... string The expected kind.
---@return StatementExpression #The expected lexeme value.
local function catch (message, parseFunc, ...)
	local value, lookup = current.value, {}
	for _, expected in ipairs({...}) do lookup[expected] = true end
	local node = parseFunc() --[[@as StatementExpression]]
	if not lookup[node.kindof] then
		throw(message .. " near '" .. value .. "'")
	end
	return node
end

---@return Term?
local function parseTerm ()
	local typeof, value = consume()
	-- UnaryExpressions
	if typeof == "Minus" or typeof == "Dollar" or typeof == "Pound" or typeof == "Bang" then
		return { kindof = "UnaryExpression", operator = value, argument = parseExpression() }
	-- Identifiers
	elseif typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	-- Strings
	elseif typeof == "String" then
		value = value:gsub("\\(%d%d%d)", function (d)
			local byte = tonumber(d)
			return escapedCharacters[byte]
		end)
		return { kindof = "StringLiteral", value = value }
	-- Numbers
	elseif typeof == "Number" then
		return { kindof = "NumberLiteral", value = tonumber(value) }
	elseif typeof == "Hexadecimal" then
		return { kindof = "NumberLiteral", value = tonumber(value, 16) }
	-- Booleans
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	-- Undefined
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	-- Parenthesized expressions
	elseif typeof == "LeftParenthesis" then
		local node = parseExpression()
		expect("')' expected", "RightParenthesis")
		return { kindof = "ParenthesizedExpression", node = node }
	end
	-- Unknown
	throw("unexpected symbol near '" .. value .. "'")
end

---@return MemberExpression
local function parseMemberExpression ()
	local record = parseTerm() --[[@as Term]]
	while current.typeof == "Dot" or current.typeof == "LeftBracket" do
		local property, computed ---@type Expression, boolean
		local typeof, value = consume()
		if typeof == "Dot" then
			property, computed = parseTerm(), false
			if not property or property.kindof ~= "Identifier" then
				throw("syntax error near '" .. value .. (property and property.value or "") .. "'")
			end
		else
			property, computed = parseExpression(), true
			expect("']' missing", "RightBracket")
		end
		record = { kindof = "MemberExpression", record = record, property = property, computed = computed } --[[@as MemberExpression]]
	end
	return record
end

---@param caller? MemberExpression
---@return CallExpression
local function parseCallExpression (caller)
	caller = parseMemberExpression()
	while current.typeof == "LeftParenthesis" do
		consume()
		caller = { kindof = "CallExpression", caller = caller, arguments = {} } --[[@as CallExpression]]
		while current.typeof ~= "RightParenthesis" do
			caller.arguments[#caller.arguments + 1] = parseExpression()
			suppose("Comma")
		end
		expect("')' expected", "RightParenthesis")
	end
	return caller
end

---@return BinaryExpression
local function parseMultiplicativeExpression ()
	local left = parseCallExpression()
	while current.typeof == "Asterisk" or current.typeof == "Slash" 
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left, operator = operator, right = parseCallExpression() } --[[@as BinaryExpression]]
	end
	return left
end

---@return BinaryExpression
local function parseAdditiveExpression ()
	local left = parseMultiplicativeExpression()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseMultiplicativeExpression() --[[@as Expression]] }
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
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseAdditiveExpression() --[[@as Expression]] }
	end
	return left
end

---@return BinaryExpression
local function parseLogicalExpression ()
	local left = parseComparisonExpression()
	while current.typeof == "And" or current.typeof == "Or" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", left = left --[[@as Expression]], operator = operator, right = parseComparisonExpression() --[[@as Expression]] }
	end
	return left
end

---@return RecordLiteralExpression|BinaryExpression
local function parseRecordExpression ()
	if current.typeof == "LeftBracket" then
		consume()
		local elements = {} ---@type RecordElement[]
		while current.typeof ~= "RightBracket" do
			local key ---@type StringLiteral?
			local value = parseExpression() --[[@as Expression]]
			if value.kindof == "StringLiteral" then
				if not (current.typeof == "Comma" or current.typeof == "RightBracket") then
					expect("':' missing", "Colon")
					key = value
				end
			end
			elements[#elements + 1] = { kindof = "RecordElement", key = key, value = (key and parseExpression() or value) --[[@as Expression]] }
			suppose("Comma")
		end
		expect("']' expected", "RightBracket")
		return { kindof = "RecordLiteralExpression", elements = elements }
	end
	return parseLogicalExpression()
end

---@return AssignmentExpression|RecordLiteralExpression
local function parseAssignmentExpression ()
	local left = parseRecordExpression()
	if suppose("Equal") then
		return { kindof = "AssignmentExpression", left = left --[[@as Expression]], operator = "=", right = parseExpression() --[[@as Expression]] }
	end
	return left
end

---@return Expression?
function parseExpression ()
	return parseAssignmentExpression()
end

---@return StatementExpression?
function parseStatement ()
	local decorations ---@type string[]?
	while true do
		repeat
			local typeof, value, line = peek()
			-- Comment
			if typeof == "Comment" then
				consume()
				return { kindof = "Comment", content = value }
			elseif typeof == "At" then
				decorations = {}
				while current.typeof == "At" do
					consume()
					decorations[#decorations + 1] = expect("<name> expected", "Identifier")
				end
				break
			-- VariableDeclaration
			elseif typeof == "Var" then
				consume()
				local declarations = {}
				repeat
					local identifier = catch("<name> expected", parseTerm, "Identifier")
					local init = suppose("Equal") and parseExpression()
					declarations[#declarations + 1] = { kindof = "VariableDeclarator", identifier = identifier --[[@as Identifier]], init = init }
					suppose("Comma")
				until current.typeof ~= "Identifier"
				return { kindof = "VariableDeclaration", declarations = declarations --[=[@as VariableDeclarator[]]=], decorations = decorations }
			-- FunctionDeclaration
			elseif typeof == "Function" then
				consume()
				local body, parameters = {}, {} ---@type BlockStatement[], Identifier[]
				local name = catch("<name> expected", parseMemberExpression, "Identifier", "MemberExpression")
				expect("'(' expected after <name>", "LeftParenthesis")
				while current.typeof == "Identifier" do
					parameters[#parameters + 1] = catch("<name> expected", parseTerm, "Identifier")
					suppose("Comma")
				end
				expect("')' expected", "RightParenthesis")
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'function' at line %s)" or "", line), "End")
				return { kindof = "FunctionDeclaration", name = name --[[@as Identifier|MemberExpression]], parameters = parameters, body = body, decorations = decorations }
			-- ReturnStatement
			elseif typeof == "Return" then
				consume()
				local arguments = { parseExpression() } ---@type Expression[]
				while current.typeof == "Comma" do
					consume()
					arguments[#arguments + 1] = parseExpression()
				end
				return { kindof = "ReturnStatement", arguments = arguments }
			-- PrototypeDeclaration
			elseif typeof == "Prototype" then
				consume()
				local body = {} ---@type BlockStatement[]
				local name = catch("<name> expected", parseMemberExpression, "Identifier", "MemberExpression") --[[@as Identifier|MemberExpression]]
				expect("Missing '{' after <name>", "LeftBrace")
				local parent = (current.typeof ~= "RightBrace") and parseExpression() or nil ---@type Expression?
				expect("Missing '}'", "RightBrace")
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'prototype' at line %s)" or "", line), "End")
				return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body, decorations = decorations }
			-- IfStatement
			elseif typeof == "If" then
				local node = { kindof = "IfStatement" }
				local latest = node --[[@as IfStatement]]
				while current.typeof ~= "End" do
					if suppose("If", "Elseif") then
						latest.test, latest.consequent = parseExpression(), {}
						expect("'then' missing", "Then")
					end
					repeat
						local target = latest.consequent or latest
						target[#target + 1] = parseStatement()
						if current.typeof == "Elseif" or suppose("Else") then
							latest.alternate = (current.typeof == "Elseif") and { kindof = "IfStatement" } or {}
							latest = latest.alternate
						end
					until current.typeof == "Elseif" or current.typeof == "End"
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'if' at line %s)" or "", line), "End")
				return node
			-- WhileLoop
			elseif typeof == "While" then
				consume()
				local condition = parseExpression()
				expect("'do' expected", "Do")
				---@type Statement[]
				local body = {}
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
				local initial = parseExpression() --[[@as Expression]]
				if initial.kindof == "AssignmentExpression" then
					expect("'to' expected", "To")
					condition = { init = initial, goal = parseExpression(), step = suppose("Step") and parseExpression() } --[[@as NumericLoopCondition]]
				elseif initial.kindof == "Identifier" then
					local variable = { initial --[[@as Identifier]] } ---@type Identifier[]
					suppose("Comma")
					while current.typeof == "Identifier" do
						variable[#variable + 1] = parseTerm() --[[@as Identifier]]
						suppose("Comma")
					end
					expect("'in' expected", "In")
					condition = { variable = variable, iterable = parseExpression() } --[[@as IterationLoopCondition]]
				end
				expect("'do' missing", "Do")
				local body = {} ---@type StatementExpression[]
				while current.typeof ~= "End" do
					body[#body + 1] = parseStatement()
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'for' at line %s)" or "", line), "End")
				return { kindof = "ForLoop", condition = condition, body = body }
			end
			return parseExpression()
		until true
	end
end

---@param source string The raw source.
---@return StatementExpression[] #The AST table.
return function (source)
	current, pop, peek = {}, scan(source)
	current.typeof, current.value, current.line = peek()
	local program = {} ---@type StatementExpression[]
	while current.typeof do
		program[#program + 1] = parseStatement()
	end
	return program
end