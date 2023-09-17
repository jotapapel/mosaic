local scan = require "scanner"

local peek, pop
local parser = {}

function parser:consume ()
	local typeof, value, _, line = pop()
	self.typeof, self.value, self.line = peek()
	return typeof, value, line or "(near EOF)"
end

function parser:expect (a, b)
    local typeof, value, line = self:consume()
    if typeof == a then
        return value
    end
    io.write("<mosaic> ", line, ": ", b or "type mismatch (expecting " .. a .. ", found " .. (typeof or "EOF") .. ")", "\n")
	os.exit()
end

function parser:parseTerm ()
	local typeof, value = self:consume()
	if typeof == "Identifier" then
		return { kindof = "Identifier", value = value }
	elseif typeof == "String" then
		return { kindof = "StringLiteral", value = value:sub(2, -2) }
	elseif typeof == "Number" then
		return { kindof = "NumberLiteral", value = value:gsub("&", "0x") }
	elseif typeof == "Boolean" then
		return { kindof = "BooleanLiteral", value = value }
	elseif typeof == "Undefined" then
		return { kindof = "Undefined" }
	elseif typeof == "LeftParenthesis" then
		value = self:parseExpression()
		self:expect("RightParenthesis", "')' expected near '" .. self..value .. "'.")
		return value
	end
end

function parser:parseUnary ()
	if self.typeof == "Minus" or self.typeof == "Dollar"
	   or self.typeof == "Pound" or self.typeof == "Bang" then
		local operator = self.value
		self:consume()
		return { kindof = "UnaryExpression", operator = operator, value = self:parseExpression() }
	end
	return self:parseTerm()
end

function parser:parseMember ()
	local record = self:parseUnary()
	while self.typeof == "Dot" or self.typeof == "LeftBracket" do
		local typeof, property = self.typeof, nil
		consume()
		if typeof == "Dot" then
			property = self:parseTerm()
			if property.kindof ~= "Identifier" then
				io.write("<mosaic> ", self.line, ": Expecting <identifier> right of '.'.")
				os.exit()
			end
		else
			property = self:parseExpression()
			self:expect("RightBracket", "Missing ']' near '" .. self.value .. "'.") 
		end
		record = { kindof = "MemberExpression", record = record, property = property }
	end
	return record
end

function parser:parseArgumentList ()
	local arguments = { self:parseRecord() }
	while self.typeof == "Comma" do
		self:consume()
		table.insert(arguments, self:parseRecord())
	end
	return arguments
end

function parser:parseArguments ()
	self:expect("LeftParenthesis")
	local arguments = (self.typeof == "RightParenthesis") and {} or self:parseArgumentList()
	self:expect("RightParenthesis")
	return arguments
end

function parser:parseCall (caller)
	local expression = { kindof = "CallExpression", caller = caller, args = self:parseArguments() }
	if self.typeof == "LeftParenthesis" then
		expression = self:parseCall(expression)
	end
	return expression
end

function parser:parseCallMember ()
	local member = self:parseMember()
	if self.typeof == "LeftParenthesis" then
		return self:parseCall(member)
	end
	return member
end

function parser:parseMultiplicative ()
	local left = self:parseCallMember()
	while self.typeof == "Asterisk" or self.typeof == "Slash"
		  or self.typeof == "Circumflex" or self.typeof == "Percent" do
		local operator = self.value
		self:consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = self:parseCallMember() }
	end
	return left
end

function parser:parseAdditive ()
	local left = self:parseMultiplicative()
	while self.typeof == "Plus" or self.typeof == "Minus" do
		local operator = self.value
		self:consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = self:parseMultiplicative() }
	end
	return left
end

function parser:parseComparison ()
	local left = self:parseAdditive()
	while self.typeof == "IsEqual" or self.typeof == "Greater" or self.typeof == "Less"
		  or self.typeof == "GreaterEqual" or self.typeof == "LessEqual" or self.typeof == "NotEqual" do
		local operator = self.value
		consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = self:parseAdditive() }
	end
	return left
end

function parser:parseLogical ()
	local left = parser:parseComparison()
	while self.typeof == "And" or self.typeof == "Or" do
		local operator = self.value
		self:consume()
		left = { kindof = "BinaryExpression", operator = operator, left = left, right = self:parseComparison() }
	end
	return left
end

function parser:parseRecord ()
	if self.typeof ~= "LeftBracket" then
		return self:parseLogical()
	end
	self:consume()
	local properties = {}
	while self.typeof ~= "RightBracket" do
		repeat
			local key
			if self.typeof == "Identifier" then
				key = { kindof = "Identifier", value = self.value }
				self:consume()
				if self.typeof ~= "RightBracket" then
					self:expect("Comma")
					table.insert(properties, { kindof = "RecordElement", value = key })
					break
				end
				self:expect("Colon")
			end
			table.insert(properties, { kindof = "RecordElement", key = key, value = self:parseLogical() })
			if self.typeof ~= "RightBracket" then
				self:expect("Comma")
			end
			break
		until true
	end
	return { kindof = "RecordLiteral", properties = properties }
end

function parser:parseExpression ()
	local expression = self:parseRecord()
	if self.typeof == "Equal" then
		self:consume()
		local key, value = expression, self:parseExpression()
		return { kindof = "VariableAssignment", key = key, value = value }
	end
	return expression
end

function parser:parseStatement()
	local statement = require "statements"
	return statement(self)
end

return function(source)
    pop, peek = scan(source)
	return function ()
		local typeof = peek()
		if typeof then
			return parser:parseStatement()
		end
	end
end