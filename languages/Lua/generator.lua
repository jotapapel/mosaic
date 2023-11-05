local json = require "lib.json"
local generateExpression, generateStatement ---@type ExpressionGenerator, StatementGenerator

--- Throw a local error.
---@param message string The error message.
---@param line string The line of the error.
local function throw (message, line)
	io.write("<mosaic> ", line, ": ", message, ".\n")
	os.exit()
end

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
	elseif kindof == "AssignmentExpression" or kindof == "BinaryExpression" then
		return generateExpression(node.left) .. string.format(" %s ", node.operator) .. generateExpression(node.right)
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
				identifier, init = identifier:match("^{%s*(.-)%s*}$"), string.format("table.unpack(%s)", init)
			end
			identifiers[index], initials[index] = identifier, init
		end
		local ids, inits = table.concat(identifiers, ', '), table.concat(initials, ', ')
		return string.format("local %s = %s", ids, inits)
	-- FunctionDeclaration
	elseif kindof == "FunctionDeclaration" then
		local name, parameters, body = generateExpression(node.name), {}, {} ---@type string, string[], string[]
		for index, parameter in ipairs(node.parameters) do
			parameters[index] = generateExpression(parameter)
		end
		for index, statement in ipairs(node.body) do
			body[index] = string.rep("\t", level + 1) .. generateStatement(statement, level + 1)
		end
		return string.format("local function %s (%s)\n%s\n%send", name, table.concat(parameters, ", "), table.concat(body, "\n"), string.rep("\t", level))
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
				output, latest = output .. (head or "") .. string.format(head and " then\n%s" or "else\n%s", table.concat(body, "\n")) .. (latest.alternate and (latest.alternate.kindof and "\nelseif " or "\n") or ""), latest.alternate
			until not latest
		end
		return output .. "\n" .. string.rep("\t", level) .. "end"
	end
	return generateExpression(node)
end

---@param ast StatementExpression[]
return function(ast)
	local output = {}
	for index, node in ipairs(ast) do
		output[index] = generateStatement(node, 0)
	end
	return table.concat(output, "\n")
end
