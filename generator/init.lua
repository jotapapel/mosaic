local trace = require "tracer"
local parse = require "frontend.parser"
local json = require "json"

---@type table<string, string>, table
local templates, masterEnv = {}, setmetatable({}, { __index = _G })

local generateExpression

---@param target string
local function createEnv (target)
	local file <close> = io.open(target) or error("File not found.")
	local source = file:read("*a")
	local master = json.decode(source) or error("Non valid JSON data", 2)
	for k, v in pairs(master.literals) do
		masterEnv[k] = v
	end
	for i, template in ipairs(master.templates) do
		if type(template.templateof) == "table" then
			for _, t in ipairs(template.templateof) do
				templates[t] = template.content
			end
		else
			templates[template.templateof] = template.content
		end
	end
end

---@param str string
---@param env table
local function interpolate (str, env)
	str = str:gsub("%b<>", function (token)
		token = token:match("^%s*<(.-)>%s*$")
		local value = env[token]
		if not value then
			local fenv = setmetatable({}, { __index = function (_, k) return env[k] or masterEnv[k] end })
			local chunk, err = load("return " .. token, "interpolate", "t", fenv)
			if type(chunk) == "function" then
				value = chunk() or error("Cannot evaluate expression", 2)
			end
		end
		return value
	end)
	return str
end

---@param node Expression
---@return string
function generateExpression (node)
	local kindof = node.kindof
	---@type table<string, string>
	local env = setmetatable({}, { __index = node })
	local template = templates[kindof]
	if kindof == "UnaryExpression" then
		if type(template) == "table" then
			for _, optionalTemplate in ipairs(template) do
				if load("return " .. optionalTemplate.condition, "condition", "t", env)() then
					template = optionalTemplate.value
					break
				end
			end
		end
		env.argument = generateExpression(node.argument)
	elseif kindof == "MemberExpression" then
		env.record, env.property = generateExpression(node.record), generateExpression(node.property)
		if type(template) == "table" then
			for _, optionalTemplate in ipairs(template) do
				if load("return " .. optionalTemplate.condition, "condition", "t", env)() then
					template = optionalTemplate.value
					break
				end
			end
		end
	elseif kindof == "CallExpression" then
		env.caller = generateExpression(node.caller)
		for index, argument in ipairs(node.arguments) do
			env.arguments[index] = generateExpression(argument)
		end
	elseif kindof == "BinaryExpression" or kindof == "AssignmentExpression" then
		env.left, env.right = generateExpression(node.left), generateExpression(node.right)
	elseif kindof == "RecordLiteralExpression" then
		for index, element in ipairs(node.elements) do
			local key, value = element.key and generateExpression(element.key), generateExpression(element.value)
			env.elements[index] = key and string.format("%s = %s", key, value) or value
		end
	elseif kindof == "ParenthesizedExpression" then
		env.node = generateExpression(node.node)
	end
	return interpolate(template, env)
end

return function(source, target)
	createEnv(target)
	for node in parse(source) do
		local template = generateExpression(node)
		print(template)
	end
end