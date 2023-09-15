local scan = require "scanner"
local trace = require "tracer"

local peek, pop, current
local consume, expect
local parseStatement, parseExpression, parseRecord,
	  parseLogical, parseComparison, parseAdditive, parseMultiplicative,
	  parseTerm

function consume ()
	local typeof, value = pop()
	current.typeof, current.value = peek()
	return typeof, value
end

function expect (a, b)
    local typeof, value = consume()
    if typeof == a then
        return value
    end
    error(b or "<mosaic> type mismatch (expecting " .. a .. ", found " .. (typeof or "EOF") .. ")", 2)
end

function parseTerm ()
	local typeof, value = consume()
	if typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	elseif typeof == "String" then
		return { kindof = "StringLiteral", value = value:sub(2, -2) }
	elseif typeof == "Number" then
		if value:sub(1, 1) == "&" then
			return { kindof = "NumberLiteral", value = value:sub(2) }
		end
		return { kindof = "NumberLiteral", value = value }
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	elseif typeof == "LeftParenthesis" then
		value = parseExpression()
		expect("RightParenthesis", "<mosaic> ')' expected.")
		return value
	end
end

function parseMultiplicative ()
	local left = parseTerm()
	while current.typeof == "Asterisk" or current.typeof == "Slash"
		  or current.typeof == "Circumflex" or current.typeof == "Percent" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = parseTerm() }
	end
	return left
end

function parseAdditive ()
	local left = parseMultiplicative()
	while current.typeof == "Plus" or current.typeof == "Minus" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = parseMultiplicative() }
	end
	return left
end

function parseComparison ()
	local left = parseAdditive()
	while current.typeof == "IsEqual" or current.typeof == "Greater" or current.typeof == "Less"
		  or current.typeof == "GreaterEqual" or current.typeof == "LessEqual" or current.typeof == "NotEqual" do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = parseAdditive() }
	end
	return left
end

function parseLogical ()
	local left = parseComparison()
	while current.typeof == "Keyword" and (current.value == "and" or current.value == "or") do
		local operator = current.value
		consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = parseComparison() }
	end
	return left
end

function parseRecord ()
	if current.typeof ~= "LeftBracket" then
		return parseLogical()
	end
	consume()
	local properties = {}
	while current.typeof ~= "RightBracket" do
		repeat
			local k
			if current.typeof == "RightBracket" then
				break
			elseif current.typeof == "Identifier" then
				k = current.value
				consume()
				if current.typeof == "Comma" or current.typeof == "RightBracket" then
					if current.typeof == "Comma" then
						consume()
					end
					table.insert(properties, { kindof = "RecordElement", value = k })
					break
				end
				expect("Colon")
			end
			table.insert(properties, { kindof = "RecordElement", key = k, value = parseTerm() })
			if current.typeof == "RightBracket" then
				break
			end
			expect("Comma")
			break
		until current.typeof == "RightBracket"
	end
	return { kindof = "RecordLiteral", properties = properties }
end

function parseExpression ()
	local expression = parseRecord()
	if current.typeof == "Equal" then
		consume()
		local key, value = expression, parseExpression()
		return { kindof = "VariableAssignment", key = key, value = value }
	end
	return expression
end

function parseStatement ()
	local typeof, value = peek()
	if typeof == "Comment" then
		consume()
		return { kindof = "Comment", value = value:sub(3) }
	elseif typeof == "Keyword" then
		consume()
		-- variable declaration
		if value == "var" then
			local body = {}
			while true do
				repeat
					local k, v = expect("Identifier"), nil
					if current.typeof == "Equal" then
						consume()
						v = parseExpression()
					end
					table.insert(body, { kindof = "VariableAssignment", key = k, value = v })
					if current.typeof == "Comma" then
						consume()
						break
					end
					return { kindof = "VariableDeclaration", body = body }
				until true
			end
		end
	end
	return parseExpression()
end

return function(source)
    current, pop, peek = {}, scan(source)
	return function ()
		return parseStatement()
	end
end
