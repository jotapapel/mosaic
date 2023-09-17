local function parseParameters (self)
	local parameters
	self:expect("LeftParenthesis", "Missing '(' after <identifier>.")
	if self.typeof ~= "RightParenthesis" then
		parameters = {}
		while self.typeof ~= "RightParenthesis" do
			table.insert(parameters, self:expect("Identifier"))
			if self.typeof ~= "RightParenthesis" then
				self:expect("Comma")
			end
		end
	end
	self:expect("RightParenthesis", "Missing ')' to close function parameters.")
	return parameters
end

local function parseStatement (self, parent)
	local typeof, value, line = self:consume()
	-- comments
	if typeof == "Comment" then
		return { kindof = "Comment", value = value:sub(3) }
	-- variable declaration
	elseif typeof == "Var" then
		local body = {}
		while true do
			repeat
				local key, value = self:expect("Identifier", "<identifier> missing in variable declaration statement."), nil
				if self.typeof == "Equal" then
					self:consume()
					value = self:parseExpression()
				end
				table.insert(body, { key = key, value = value })
				if self.typeof == "Comma" then
					self:consume()
					break
				end
				return { kindof = "VariableDeclaration", body = body }
			until true
		end
	-- function declaration
	elseif typeof == "Function" then
		local body = {}
		local identifier = self:expect("Identifier", "<identifier> missing in function declaration statement.")
		local parameters = parseParameters(self)
		while self.typeof ~= "End" do
			table.insert(body, self:parseStatement("function"))
		end
		self:expect("End", "'end' expected (to close 'function' at line " .. line .. ") near " .. self.value)
		return { kindof = "FunctionDeclaration", identifier = identifier, body = body }
	end
	-- unknown statement
	io.write("<mosaic> ", line, ": unexpected symbol found near '", value, "'.", "\n")
	os.exit()
end

return function (parser)
	return parseStatement(parser)
end