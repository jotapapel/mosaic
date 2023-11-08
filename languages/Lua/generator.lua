local json = require "lib.json"
local parse = require "src.parser"
local generateExpression, generateStatement ---@type ExpressionGenerator, StatementGenerator

---@return string
function generateExpression(node)
	local kindof = node.kindof
	if kindof == "UnaryExpression" then
		return node.operator .. generateExpression(node.argument)
	elseif kindof == "StringLiteral" then
		return string.format('"%s"', node.value)
	elseif kindof == "Undefined" then
		return "nil"
	elseif kindof == "MemberExpression" then
		return string.format(node.computed and "%s[%s]" or "%s.%s", generateExpression(node.record), generateExpression(node.property))
	elseif kindof == "CallExpression" then
		local caller, arguments = generateExpression(node.caller), {} ---@type string, string[]
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument)
		end
		return string.format("%s(%s)", caller, table.concat(arguments, ", "))
	elseif kindof == "RecordLiteralExpression" then
		local parts = {} ---@type string[]
		for index, element in ipairs(node.elements) do
			local key, value = element.key and generateExpression(element.key), generateExpression(element.value) --[[@as string]]
			parts[index] = key and string.format("%s = %s", key, value) or string.format("%s", value)
		end
		return string.format("{ %s }", table.concat(parts, ", "))
	elseif kindof == "BinaryExpression" then
		node.operator = (node.operator == "<>") and "~=" or node.operator
		return generateExpression(node.left) .. string.format(" %s ", node.operator) .. generateExpression(node.right)
	elseif kindof == "AssignmentExpression" then
		local left, right = generateExpression(node.left), generateExpression(node.right) ---@type string, string
		if node.left.kindof == "RecordLiteralExpression" then
			left, right = left:match("^{%s*(.-)%s*}"), (right == "...") and string.format("table.unpack(%s)", right) or right:match("^{%s*(.-)%s*}")
		end
		return left .. " = " .. right
	elseif kindof == "ParenthesizedExpression" then
		return string.format("(%s)", generateExpression(node.node))
	end
	return node.value
end

function generateStatement(node, level)
	local kindof = node.kindof
	-- Comment
	if kindof == "Comment" then
		return string.format("--%s", node.content)
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
		local ids, inits = table.concat(identifiers, ', '), table.concat(initials, ', ')
		return string.format("local %s = %s", ids, inits)
	-- FunctionDeclaration
	elseif kindof == "FunctionDeclaration" then
		local storage = (node.name.kindof == "MemberExpression") and "" or "local "
		local name, parameters, body = generateExpression(node.name), {}, {} ---@type string, string[], string[]
		for index, parameter in ipairs(node.parameters) do
			parameters[index] = generateExpression(parameter)
		end
		for index, statement in ipairs(node.body) do
			body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
		end
		while node.decorations and #node.decorations > 0 do
			local decorator = table.remove(node.decorations)
			if decorator == "global" then
				storage = ""
			else
				throw("")
			end
		end
		return storage .. string.format("function %s (%s)\n%s\n%send", name, table.concat(parameters, ", "), table.concat(body, "\n"), string.rep("\t", level))
	-- ReturnStatement
	elseif kindof == "ReturnStatement" then
		local arguments = {} ---@type string[]
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument)
		end
		return string.format("return %s", table.concat(arguments, ", "))
	-- PrototypeDeclaration
	elseif kindof == "PrototypeDeclaration" then
		-- TODO: PrototypeDeclaration
	elseif kindof == "IfStatement" then
		local latest, output = node, "if " ---@type IfStatement?, string
		while latest do
			repeat
				local head, body = latest.test and generateExpression(latest.test), {} ---@type string?, string[]
				for index, statement in ipairs(latest.consequent or latest) do
					body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
				end
				output, latest = output .. (head or "") .. string.format(head and " then\n%s" or "\0else\n%s", table.concat(body, "\n")) .. (latest.alternate and (latest.alternate.kindof and "\n\0elseif " or "\n") or ""), latest.alternate
			until not latest
		end
		return output:gsub("\0", string.rep("\t", level)) .. "\n" .. string.rep("\t", level) .. "end"
	elseif kindof == "WhileLoop" then
		local condition, body = generateExpression(node.condition), {} ---@type string, string[]
		for index, statement in ipairs(node.body) do
			body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
		end
		return string.format("while %s do\n%s\n%send", condition, table.concat(body, "\n"), string.rep("\t", level))
	elseif kindof == "BreakStatement" then
		return "break"
	elseif kindof == "ForLoop" then
		local head, body = nil, {} ---@type string, string[]
		if node.condition.init then
			head = string.format("%s, %s%s", generateExpression(node.condition.init), generateExpression(node.condition.goal), node.condition.step and string.format(", %s", generateExpression(node.condition.step)) or "")
		else
			local variables = {}
			for index, variable in ipairs(node.condition.variable) do
				variables[index] = generateExpression(variable)
			end
			head = string.format("%s in %s", table.concat(variables, ", "), generateExpression(node.condition.iterable))
		end
		for index, statement in ipairs(node.body) do
			body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
		end
		return string.format("for %s do\n%s\n%send", head, table.concat(body, "\n"), string.rep("\t", level))
	end
	return generateExpression(node)
end

---@param source string
return function(source)
	local output = {}
	for node in parse(source) do
		output[#output + 1] = generateStatement(node, 0)
	end
	return table.concat(output, "\n")
end
