local parser = require "frontend.parser"
---@type ExpressionGenerator, StatementGenerator
local generateExpression, generateStatement
local globalmt <const> = { __index = _G }

local function interpolate (input, env)
	setmetatable(env, globalmt)
	local output = input:gsub("{{(.-)}}", function(expr)
		local success, result = pcall(load, "return " .. expr, "interpolate", "t", env)
		return success and assert(result, "Cannot evaluate expression.")() or env[expr]
	end)
	return output
end

function generateExpression (node)
	local kindof = node.kindof
	if kindof == "Identifier" or kindof == "NumberLiteral" or kindof == "BooleanLiteral" then
		return node.value
	elseif kindof == "StringLiteral" then
		return interpolate('"{{value}}"', node)
	elseif kindof == "Undefined" then
		return "nil"
	end
end

function generateStatement (node)
	local kindof = node.kindof
	if kindof == "Comment" then
		return interpolate("--{{content}}", node)
	elseif kindof == "VariableDeclaration" then
		local identifiers, initials = {}, {}
		for index, declaration in ipairs(node.declarations) do
			identifiers[index], initials[index] = generateExpression(declaration.identifier), declaration.init and generateExpression(declaration.init)
		end
		return interpolate("{{table.concat(identifiers, ', ')}}{{(#initials > 0) and ' = ' or ''}}{{table.concat(initials, ', ')}}", { identifiers = identifiers, initials = initials })
	end
end

---@param ast StatementExpression[]
return function (ast)
	local output = {}
	for index, node in ipairs(ast) do
		output[#output + 1] = generateStatement(node)
	end
	return table.concat(output, "\n")
end