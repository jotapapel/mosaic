local json = require "lib.json"
local parse = require "src.parser"
local generateExpression, generateStatement ---@type ExpressionGenerator, StatementGenerator

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
	output[#output + 1] =  string.rep("\t", level) .. footer
	return table.concat(output, "\n")
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

---@return string
function generateExpression(node)
	local kindof = node.kindof
	if kindof == "UnaryExpression" then
		return node.operator .. generateExpression(node.argument)
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
			arguments[index] = generateExpression(argument)
		end
		return string.format("%s(%s)", caller, table.concat(arguments, ", "))
	elseif kindof == "NewExpression" then
		local caller, arguments = generateExpression(node.caller), {}
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument)
		end
		return string.format("%s(%s)", caller, table.concat(arguments, ", "))
	elseif kindof == "BinaryExpression" then
		local operator = (node.operator == "<>") and "~=" or node.operator
		if operator == "+" and (node.left.kindof == "StringLiteral" or node.right.kindof == "StringLiteral") then
			operator = ".."
		end
		return generateExpression(node.left) .. string.format(" %s ", operator) .. generateExpression(node.right)
	elseif kindof == "RecordLiteralExpression" then
		local parts = {} ---@type string[]
		for index, element in ipairs(node.elements) do
			local pattern = element.key and ((element.key.kindof == "StringLiteral") and "[%s] = %s" or "%s = %s")
			local key, value = element.key and generateExpression(element.key), generateExpression(element.value) --[[@as string]]
			parts[index] = key and string.format(pattern, key, value) or string.format("%s", value)
		end
		return string.format("{ %s }", table.concat(parts, ", "))
	elseif kindof == "ParenthesizedExpression" then
		local node = generateExpression(node.node)
		return string.format("(%s)", node)
	end
	return node.value
end

function generateStatement(node, level)
	level = level or 0
	local kindof = node.kindof
	-- Comment
	if kindof == "Comment" then
		local content = map(node.content, function (value)
			return string.format("--%s", value)
		end)
		return table.concat(content, "\n" .. string.rep("\t", level))
	-- VariableDeclaration
	elseif kindof == "VariableDeclaration" then
		local identifiers, initials = {}, {}
		for index, declaration in ipairs(node.declarations) do
			local identifier, init = generateExpression(declaration.identifier), declaration.init and generateExpression(declaration.init) or "nil"
			if declaration.identifier.kindof == "RecordLiteralExpression" then
				identifier, init = identifier:match("^{%s*(.-)%s*}$"), (init == "...") and string.format("table.unpack(%s)", init) or init:match("^{%s*(.-)%s*}")
			end
			identifiers[index], initials[index] = identifier, init
		end
		return string.format("local %s = %s", table.concat(identifiers, ', '), table.concat(initials, ', '))
	-- FunctionDeclaration
	elseif kindof == "FunctionDeclaration" then
		local name, parameters, body = generateExpression(node.name), map(node.parameters, generateExpression), {} ---@type string, string[], string[]
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("function %s (%s)", name, table.concat(parameters, ", ")), body, "end", level)
	-- ReturnStatement
	elseif kindof == "ReturnStatement" then
		local arguments = map(node.arguments, generateExpression) ---@type string[]
		return string.format("return %s", table.concat(arguments, ", "))
	-- PrototypeDeclaration
	elseif kindof == "PrototypeDeclaration" then
		local name, parent = generateExpression(node.name), node.parent and generateExpression(node.parent)
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
					for index, statement in ipairs(statement.body) do
						if index == 1 and parent then
							local arguments = {}
							for innerIndex, argument in ipairs(statement.arguments) do
								arguments[innerIndex] = generateExpression(argument)
							end
							constructor[index] = string.format("local self = setmetatable(%s, { __index = %s })", parent and string.format("%s(%s)", parent, table.concat(arguments, ", ")) or "{}", name)
						else
							constructor[#constructor + 1] = generateStatement(statement, level + 2)
						end
					end
				else
					statement.name.value, statement.parameters = string.format("%s.%s", name, statement.name.value), { { kindof = "Identifier", value = "self"}, table.unpack(statement.parameters) }
					for index, innerStatement in ipairs(statement.body) do
						if innerStatement.kindof == "CallExpression" and (innerStatement.caller.record and innerStatement.caller.record.value == "super") then
							innerStatement.caller.record.value, innerStatement.arguments[1] = parent, { kindof = "Identifier", value = "self" }
						end
					end
					functions[#functions + 1] = generateStatement(statement, level + 1)
				end
			elseif statement.kindof == "VariableDeclaration" then
				for index, declaration in ipairs(statement.declarations) do
					declaration.identifier.value = string.format("self.%s", declaration.identifier.value)
				end
				variables[#variables + 1] = generateStatement(statement):match("^local%s(.-)$")
			end
		end
		return generate(string.format("local %s = (function (%s)", name, parent or ""), {
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
			body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
		end
		return generate(string.format("while %s do", condition), body, "end", level)
	elseif kindof == "BreakStatement" then
		return "break"
	elseif kindof == "ForLoop" then
		local head ---@type string
		local body = {} ---@type string[]
		if node.condition.init then
			head = string.format("%s, %s%s", generateStatement(node.condition.init), generateExpression(node.condition.goal), node.condition.step and string.format(", %s", generateExpression(node.condition.step)) or "")
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
		local lefts, rights = {}, {}
		for index, assignment in ipairs(node.assignments) do
			local left, right = generateExpression(assignment.left), generateExpression(assignment.right)
			if assignment.left.kindof == "RecordLiteralExpression" then
				left, right = left:match("^{%s*(.-)%s*}$"), (right == "...") and right or string.format("table.unpack(%s)", right)
			end
			lefts[index], rights[index] = left, right
		end
		return string.format("%s = %s", table.concat(lefts, ', '), table.concat(rights, ', '))
	end
	return generateExpression(node)
end

---@param source string
return function(source)
	local output = {}
	for node in parse(source) do
		--print(json.encode(node, true))
		output[#output + 1] = generateStatement(node)
	end
	return table.concat(output, "\n")
end
