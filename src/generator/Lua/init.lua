local generateExpression, generateStatement ---@type Generator<Expression>, Generator<StatementExpression>
local output, exports ---@type string[], table<string, string>

--- Generate a code structure with the correct indentation.
---@param head string The header of the structure.
---@param body table The elements of the structure body.
---@param footer string The footer of the structure.
---@param level number The indent level of the final structure.
---@return string #The final structure.
local function generate (head, body, footer, level)
	local output = { head }
	for _, element in ipairs(body) do
		output[#output + 1] = element and (string.rep("\t", level + 1) .. element) or nil
	end
	return table.concat(output, "\n") .. "\n" .. string.rep("\t", level) .. footer
end

--- Iterate a table with the desired function and return the result in a new table, maintaining the indexes.
---@param tbl table The table to iterate.
---@param func function The function to use.
---@return table #The resulting table.
local function map (tbl, func)
	local result = {}
	for index, value in ipairs(tbl) do
		result[index] = func(value)
	end
	return result
end

--- Generate an expression.
---@param node Expression
---@param level? integer
---@return string?
function generateExpression(node, level)
	local kindof = node.kindof
	if kindof == "UnaryExpression" then
		return node.operator .. generateExpression(node.argument)
	elseif kindof == "Identifier" then
		return exports[node.value] or node.value
	elseif kindof == "StringLiteral" then
		return string.format("\"%s\"", node.value)
	elseif kindof == "Undefined" then
		return "nil"
	elseif kindof == "MemberExpression" then
		local pattern, record, property = node.computed and "%s[%s]" or "%s.%s", generateExpression(node.record), generateExpression(node.property)
		return string.format(pattern, record, property)
	elseif kindof == "CallExpression" then
		local caller, arguments = generateExpression(node.caller), {} ---@type string, string[]
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument, level)
		end
		return string.format("%s(%s)", caller, table.concat(arguments, ", "))
	elseif kindof == "NewExpression" then
		local prototype, arguments = generateExpression(node.caller), {}
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument, level)
		end
		return string.format("%s(%s)", prototype, table.concat(arguments, ", "))
	elseif kindof == "BinaryExpression" or kindof == "AssignmentExpression" then
		local pattern, operator = "%s", node.operator
		if operator == "is" then
			pattern, operator = "type(%s)", "=="
		elseif operator == "+" and (node.left.kindof == "StringLiteral" or node.right.kindof == "StringLiteral") then
			operator = ".."
		elseif operator == "<>" then
			operator = "~="
		end
		return string.format(pattern, generateExpression(node.left, level)) .. string.format(" %s ", operator) .. generateExpression(node.right, level)
	elseif kindof == "RecordLiteralExpression" then
		local parts = {} ---@type string[]
		for index, element in ipairs(node.elements) do
			local pattern = "[%s] = %s"
			if element.key then
				if string.match(element.key.value, "^[_%a][_%w]*$") then
					element.key.kindof, pattern = "Identifier", "%s = %s"
				elseif tonumber(element.key.value) then
					element.key.kindof, element.key.value = "NumberLiteral", tonumber(element.key.value)	
				end
			end
			local key, value = element.key and generateExpression(element.key), generateExpression(element.value) --[[@as string]]
			parts[index] = key and string.format(pattern, key, value) or string.format("%s", value)
		end
		return string.format("{ %s }", table.concat(parts, ", "))
	elseif kindof == "FunctionExpression" then
		local parameters = map(node.parameters, generateExpression) ---@type string[]
		local body = {} ---@type string[]
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("function (%s)", table.concat(parameters, ", ")), body, "end", level)
	elseif kindof == "ParenthesizedExpression" then
		local inner = generateExpression(node.node, level)
		return string.format("(%s)", inner)
	end
	return node.value
end

--- Generate an statement.
---@param node StatementExpression
---@param level? integer
---@return string?
function generateStatement(node, level)
	level = level or 0
	local kindof = node.kindof
	-- Comment
	if kindof == "Comment" then
		local content = map(node.content, function (value) return string.format("--%s", value) end)
		return table.concat(content, "\n" .. string.rep("\t", level))
	-- ImportDeclaration
	elseif kindof == "ImportDeclaration" then
		local location = generateExpression(node.location):match("^\"(.-)\"$")
		local internal = string.format("__%s", location:match("//?(.-)%."))
		if node.names.kindof then
			exports[node.names.value] = internal
		else
			for _, name in ipairs(node.names) do
				exports[name.value] = string.format("%s.%s", internal, name.value)
			end
		end
		return string.format("local %s = require(\"%s\")", internal, location)
	-- VariableDeclaration
	elseif kindof == "VariableDeclaration" then
		local lefts, rights, storage = {}, {}, (node.decorations and node.decorations["global"]) and "" or "local " ---@type string[], string[], string
		for index, declaration in ipairs(node.declarations) do
			local left, right = generateExpression(declaration.left) --[[@as string]], declaration.right and generateExpression(declaration.right, level) --[[@as string]] or "nil"
			if declaration.left.kindof == "RecordLiteralExpression" then
				left, right = left:match("^{%s*(.-)%s*}$"), (right == "...") and string.format("table.unpack(%s)", right) or right:match("^{%s*(.-)%s*}")
			end
			lefts[index], rights[index] = left, right
		end
		return storage .. string.format("%s = %s", table.concat(lefts, ', '), table.concat(rights, ', '))
	-- FunctionDeclaration
	elseif kindof == "FunctionDeclaration" then
		local name, parameters = generateExpression(node.name), map(node.parameters, generateExpression) ---@type string, string[]
		local storage = ((node.decorations and node.decorations["global"]) or (node.name.kindof == "MemberExpression") or not(node.name)) and "" or "local "
		local body = {} ---@type string[]
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("%sfunction %s (%s)", storage, name, table.concat(parameters, ", ")), body, "end", level)
	-- ReturnStatement
	elseif kindof == "ReturnStatement" then
		local arguments = map(node.arguments, generateExpression) ---@type string[]
		return string.format("return %s", table.concat(arguments, ", "))
	-- PrototypeDeclaration
	elseif kindof == "PrototypeDeclaration" then
		local name, parent, storage = generateExpression(node.name), node.parent and generateExpression(node.parent), (node.decorations and node.decorations["global"]) and "" or "local "
		local body, variables, functions = {}, {}, {} ---@type string[], string[], string[]
		local parameters, constructor = {}, {}
		for index, statement in ipairs(node.body) do
			if statement.kindof == "Comment" then
				local adjacent = node.body[index + 1]
				if adjacent and adjacent.kindof == "VariableDeclaration" then
					variables[#variables + 1] = generateStatement(statement, level + 3)
				elseif adjacent and adjacent.kindof == "FunctionDeclaration" then
					local target = adjacent.name.value == "constructor" and body or functions
					target[#target + 1] = generateStatement(statement, (adjacent.name.value == "constructor") and level + 1 or level)
				end
			elseif statement.kindof == "FunctionDeclaration" then
				if statement.name.value == "constructor" then
					parameters = map(statement.parameters, generateExpression)
					for statementIndex, statementStatement in ipairs(statement.body) do
						if statementIndex == 1 and parent then
							local arguments = {}
							for innerStatementIndex, argument in ipairs(statementStatement.arguments) do
								arguments[innerStatementIndex] = generateExpression(argument)
							end
							constructor[#constructor + 1] = string.format("local self = setmetatable(%s, { __index = %s })", parent and string.format("%s(%s)", parent, table.concat(arguments, ", ")) or "{}", name)
						else
							constructor[#constructor + 1] = generateStatement(statementStatement, level + 2)
						end
					end
				else
					local functionName = statement.name
					local functionParameters = (statement.decorations and statement.decorations["weak"]) and statement.parameters or { { kindof = "Identifier", value = "self" }, table.unpack(statement.parameters) }
					for _, innerStatement in ipairs(statement.body) do
						if innerStatement.kindof == "CallExpression" and (innerStatement.caller.record and innerStatement.caller.record.value == "super") then
							innerStatement.caller.record.value, innerStatement.arguments[1] = parent, { kindof = "Identifier", value = "self" }
						end
					end
					functions[#functions + 1] = generateStatement({ kindof = "VariableAssignment", assignments = { { kindof = "AssignmentExpression", left = { kindof = "MemberExpression", record = { kindof = "Identifier", value = name }, property = functionName, computed = false }, operator = "=", right = { kindof = "FunctionExpression", parameters = functionParameters, body = statement.body } } } }, level + 1)
				end
			elseif statement.kindof == "VariableDeclaration" then
				statement.decorations = { ["global"] = true }
				for _, declaration in ipairs(statement.declarations) do
					declaration.left.value = string.format("self.%s", declaration.left.value)
				end
				variables[#variables + 1] = generateStatement(statement)
			end
		end
		return storage .. generate(string.format("%s = (function (%s)", name, parent or ""), {
			generate(string.format("local %s = setmetatable({}, {", name), {
				generate(string.format("__call = function(%s%s)", name, (parent and (#parameters == 0)) and ", ..." or string.format(#parameters > 0 and ", %s" or "%s", table.concat(parameters, ", "))), {
					string.format("%s setmetatable(%s, { __index = %s })", (#constructor == 0 and #variables == 0) and "return" or "local self =", parent and string.format("%s(...)", parent) or "{}", name),
					(#variables > 0) and table.concat(variables, "\n" .. string.rep("\t", 3)),
					(#constructor > 0) and table.concat(constructor, "\n" .. string.rep("\t", 1)),
					(#constructor > 0 or #variables > 0) and "return self"
				}, "end", level + 2)
			}, "})", level + 1),
			(#functions > 0) and table.concat(functions, "\n" .. string.rep("\t", 1)),
			string.format("return %s", name)
		}, string.format("end)(%s)", parent or ""), level)
	elseif kindof == "IfStatement" then
		local output, latest = "if", node ---@type string, IfStatement?
		while latest do
			repeat
				local head, body = latest.test and generateExpression(latest.test), {} ---@type string?, string[]
				for index, statement in ipairs(latest.consequent or latest) do
					body[index] = generateStatement(statement, level + 1)
				end
				output, latest = output .. generate(string.format(head and " %s then" or "else", head or ""), body, "", level) .. ((latest.alternate and latest.alternate.test) and "elseif" or ""), latest.alternate
			until not latest
		end
		return output .. "end"
	elseif kindof == "WhileLoop" then
		local condition, body = generateExpression(node.condition), {} ---@type string, string[]
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("while %s do", condition), body, "end", level)
	elseif kindof == "BreakStatement" then
		return "break"
	elseif kindof == "ForLoop" then
		local head ---@type string
		local body = {} ---@type string[]
		if node.condition.init then
			head = string.format("%s, %s%s", generateExpression(node.condition.init --[[@as Expression]]), generateExpression(node.condition.goal), node.condition.step and string.format(", %s", generateExpression(node.condition.step)) or "")
		else
			local variables = {}
			for index, variable in ipairs(node.condition.variable) do
				variables[index] = generateExpression(variable)
			end
			head = string.format("%s in %s", table.concat(variables, ", "), generateExpression(node.condition.iterable))
		end
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("for %s do", head), body, "end", level)
	elseif kindof == "VariableAssignment" then
		local lefts, rights = {}, {} ---@type string[], string[]
		for index, assignment in ipairs(node.assignments) do
			local left, right = generateExpression(assignment.left) --[[@as string]], generateExpression(assignment.right, level) --[[@as string]]
			if assignment.left.kindof == "RecordLiteralExpression" then
				left, right = left:match("^{%s*(.-)%s*}$"), (right == "...") and right or string.format("table.unpack(%s)", right)
			end
			if assignment.operator:sub(1, 1):match("[%-%+%*//%^%%]") then
				right = left .. string.format(" %s ", assignment.operator:sub(1, 1)) .. right
			end
			lefts[index], rights[index] = left, right
		end
		return string.format("%s = %s", table.concat(lefts, ', '), table.concat(rights, ', '))
	elseif kindof == "CallExpression" or kindof == "NewExpression" then
		return generateExpression(node --[[@as Expression]], level)
	end
end

--- Generates source code in Lua based off an AST produced by the parser.
---@param ast AST The abstract syntax tree.
---@param level? integer Level of indentation to use.
---@return string #The output source code.
return function(ast, level)
	output, exports = {}, {}
	for _, node in ipairs(ast.body) do
		output[#output + 1] = string.rep("\t", level or 0) .. generateStatement(node, level)
	end
	return table.concat(output, "\n")
end

---@alias Generator<T> fun(node: T, level?: integer): string?