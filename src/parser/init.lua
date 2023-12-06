local scan = require "src.parser.scanner"
local json = require "lib.json"

local parseMemberExpression, parseNewCallMemberExpression ---@type Parser<MemberExpression|Term>, Parser<CallExpression|NewExpression|MemberExpression>
local parseExpression, parseStatement ---@type Parser<Expression>, Parser<StatementExpression, Identifier|Identifier[]>
local current, pop, peek ---@type Lexeme, LexicalScanner, LexicalScanner
local escapedCharacters <const> = { [116] = "\\t", [92] = "\\\\", [34] = "\\\"", [98] = "\\b", [102] = "\\f", [110] = "\\n", [114] = "\\r", [39] = "\\\'" }

--- Throw a local error.
---@param message string The error message.
local function throw (message, line)
	io.write("<mosaic> ", line or current.line, ": ", message, ".\n")
	os.exit()
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
		return { kindof = typeof }
	-- Ellipsis
	elseif typeof == "Ellipsis" then
		if current.typeof == "Identifier" then
			return { kindof = "UnaryExpression", operator = "...", argument = parseMemberExpression() }
		end
		return { kindof = "Ellipsis", value = value }
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
	if member.kindof == "Identifier" or member.kindof == "MemberExpression" then
		if suppose "LeftBrace" then
			return parseNewExpression(member)
		elseif current.typeof == "LeftParenthesis" then
			return parseCallExpression(member)
		elseif suppose "Colon" then
			if (member.kindof == "MemberExpression" or member.kindof == "Identifier") then
				local property = catch("<name> expected", parseTerm, "Identifier") --[[@as Expression]]
				local caller = { kindof = "MemberExpression", record = member --[[@as Expression]], property = property, computed = false, instance = true }
				return parseCallExpression(caller, member)
			elseif member.kindof == "StringLiteral" then
				---@cast member +StringLiteral
				member.key = true
				return member
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
			elements[#elements + 1] = { kindof = "RecordElement", key = key, value = (key and parseExpression() or value) --[[@as Expression]] }
			suppose("Comma")
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
			body[#body + 1] = parseStatement()
		end
		expect("'end' expected " .. string.format((current.line > line) and "(to close 'function' at line %s)" or "", line), "End")
		return { kindof = "FunctionExpression", parameters = parameters, body = body } --[[@as FunctionExpression]]
	end
	return parseRecordExpression()
end

---@return Expression?
function parseExpression ()
	return parseFunctionExpression()
end

---@return StatementExpression?, (Identifier|Identifier[])?
function parseStatement ()
	local decorations, exportable ---@type string[]?, boolean?
	while true do
		repeat
			local typeof, value, line = peek()
			-- Decorators
			if typeof == "At" then
				decorations = {} ---@type { [string]: true }
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
						names[#names + 1] = (name.value.kindof == "Identifier") and name.value or throw("element must be an identifier") --[[@as Identifier]]
					end
				end
				expect("'from' expected", "From")
				local location = catch("<string> expected", parseTerm, "StringLiteral")
				return { kindof = "ImportDeclaration", names = names --[=[@as Identifier|Identifier[]]=], location = location }
			-- VariableDeclaration
			elseif typeof == "Var" then
				consume()
				local declarations, exports = {}, exportable and {} ---@type AssignmentExpression[], (Identifier|Identifier[])?
				while current.typeof == "Identifier" or current.typeof == "LeftBracket" do
					local left = catch("<name> expected", parseExpression, "Identifier", exportable or "RecordLiteralExpression") --[[@as Identifier]]
					local right = suppose("Equal") and ((left.kindof == "RecordLiteralExpression") and catch("'<record> or '...' expected", parseExpression, "RecordLiteralExpression", "Ellipsis", "UnaryExpression") or parseExpression()) --[[@as Expression]]
					declarations[#declarations + 1] = { kindof = "AssignmentExpression", left = left, operator = "=", right = right }
					if not suppose "Comma" then
						break
					end
				end
				if exportable then
					if decorations and decorations["default"] then
						if #declarations > 1 then
							throw("there can only be one default export")
						else
							exports = declarations[1].left
						end
					else
						for index, assignment in ipairs(declarations) do
							exports[index] = assignment.left
						end
					end
				end
				return { kindof = "VariableDeclaration", declarations = declarations, decorations = decorations }, exports
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
				return { kindof = "FunctionDeclaration", name = name --[[@as Identifier]], parameters = parameters, body = body, decorations = decorations }, exportable and { name } or nil
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
				local body, constructor = {}, false ---@type (Comment|VariableDeclaration|FunctionDeclaration)[], boolean
				local name = catch("<name> expected", parseMemberExpression, "Identifier", exportable or "MemberExpression") --[[@as Expression]]
				expect("Missing '{' after <name>", "LeftBrace")
				local parent = (current.typeof ~= "RightBrace") and parseExpression() or nil ---@type Expression?
				expect("Missing '}'", "RightBrace")
				while current.typeof ~= "End" do
					local last, statement = current.line, catch("syntax error", parseStatement, "Comment", "VariableDeclaration", "FunctionDeclaration") --[[@as Comment|VariableDeclaration|FunctionDeclaration]]
					if statement.kindof == "FunctionDeclaration" then
						if statement.name.kindof ~= "Identifier" then
							throw("syntax error, <name> expected", last)
						end
						if statement.name.value == "constructor" then
							if parent then
								local firstStatement = statement.body[1] ---@type CallExpression
								if not (firstStatement and firstStatement.kindof == "CallExpression" and firstStatement.caller.value == "super") then
									throw("'super' call required inside extended prototype constructor", last)
								end
							end
							if decorations and decorations["abstract"] then
								throw("prototype is abstract, no constructor implementations are allowed", last)	
							end
							constructor = constructor and throw("multiple constructor implementations are not allowed", last) or true
						end
					end
					body[#body + 1] = statement
				end
				expect("'end' expected " .. string.format((current.line > line) and "(to close 'prototype' at line %s)" or "", line), "End")
				return { kindof = "PrototypeDeclaration", name = name, parent = parent, body = body, decorations = decorations }, exportable and { name } or nil
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
						local target = latest.consequent or latest
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
				local last, initial = current.value, parseExpression() --[[@as Expression]]
				if initial.kindof == "Identifier" then
					expect("'=' expected", "Equal")
					initial = { kindof = "AssignmentExpression", left = initial, operator = "=", right = parseExpression() } --[[@as AssignmentExpression]]
					expect("'to' expected", "To")
					condition = { init = initial, goal = parseExpression(), step = suppose("Step") and parseExpression() } --[[@as NumericLoopCondition]]
				elseif initial.kindof == "RecordLiteralExpression" then
					local variable = {} ---@type Identifier[]
					for index, element in ipairs(initial.elements) do
						if element.value.kindof ~= "Identifier" or element.key then
							throw(string.format("expected <name> near record element nº %i", index))
						else
							variable[#variable + 1] = element.value
						end
					end
					expect("'in' expected", "In")
					condition = { variable = variable, iterable = parseExpression() } --[[@as IterationLoopCondition]]
				else
					throw("<name> or <record> expected near '" .. last .. "'")
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
						operator, right = expect("'=' expected", "Equal"), catch("'<record> or '...' expected", parseExpression, "RecordLiteralExpression", "Ellipsis")
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
				return { kindof = "VariableAssignment", assignments = assignments }
			end
			-- Unknown
			throw("unexpected symbol near '" .. value .. "'")
		until true
	end
end

--- Generates an AST from a raw source.
---@param source string The raw source.
---@param kindof string The AST kind.
---@return AST #The AST table.
return function (source, kindof)
	local ast = { kindof = kindof, body = {}, exports = {} } ---@type AST
	current, pop, peek = scan(source)
	current.typeof, current.value, current.line = peek()
	while current.typeof do
		local statement, export = parseStatement()
		ast.body[#ast.body + 1] = statement
		if export and ast.kindof == "Module" then
			local node = { kindof = "VariableAssignment", assignments = {} } ---@type VariableAssignment
			---@cast export +Identifier
			if export.kindof == "Identifier" then
				if ast.exports["default"] then
					throw("default value already exported")
				end
				node.assignments[#node.assignments + 1], ast.exports["default"] = { kindof = "AssignmentExpression", left = { kindof = "MemberExpression", record = { kindof = "Identifier", value = "exports" }, property = { kindof = "Identifier", value = "default" }, computed = false }, operator = "=", right = export }, true
			else
				for _, identifier in ipairs(export) do
					local left = { kindof = "MemberExpression", record = { kindof = "Identifier", value = "exports" }, property = identifier, computed = false } ---@type MemberExpression
					if ast.exports[identifier.value] then
						throw("<name> must be unique, '" .. identifier.value .. "' already exported")
					end
					node.assignments[#node.assignments + 1], ast.exports[identifier.value] = { kindof = "AssignmentExpression", left = left, operator = "=", right = identifier }, true
				end
			end
			ast.body[#ast.body + 1] = node
		end
	end
	return ast
end

---@alias Parser<P, Q> fun(): P?, Q?
---@alias AST { kindof: "Program"|"Module", body: StatementExpression[], exports: table<string, boolean> }