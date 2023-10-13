local parser = require "frontend.parser"
local interpolate = require "backend.interpolator"
---@type ExpressionGenerator, StatementGenerator
local generateExpression, generateStatement

function generateExpression (node)
	local kindof = node.kindof
	if kindof == "Identifier" or kindof == "NumberLiteral" or kindof == "BooleanLiteral" then
		return node.value
	elseif kindof == "StringLiteral" then
		return interpolate('"${value}"', node)
	elseif kindof == "Undefined" then
		return "nil"
	end
end

function generateStatement (node)
	local kindof = node.kindof
	if kindof == "Comment" then
		return interpolate("--${content}", node)
	elseif kindof == "VariableDeclaration" then
		local identifiers, initials = {}, {}
		for index, declaration in ipairs(node.declarations) do
			identifiers[index], initials[index] = generateExpression(declaration.identifier), declaration.init and generateExpression(declaration.init)
		end
		local ids, inits = table.concat(identifiers, ', '), table.concat(initials, ', ')
		return interpolate("${ids} = ${inits}", nil, 3)
	end
end

---@param ast StatementExpression[]
return function (ast)
	local output = {}
	for index, node in ipairs(ast) do
		output[index] = generateStatement(node)
	end
	return table.concat(output, "\n")
end