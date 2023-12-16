local json = require "lib.json"
local generateExpression, generateStatement ---@type Generator<Expression>, Generator<StatementExpression>
local output, exports ---@type string[], table<string, string>

--- Generate a code structure with the correct indentation.
---@param head string The header of the structure.
---@param body table The elements of the structure body.
---@param footer string The footer of the structure.
---@param level number The indent level of the final structure.
---@return string #The final structure.
local function generate (head, body, footer, level)
	local parts = { head }
	for index = 1, #body do
		local element = body[index]
		if type(element) == "string" then
			parts[#parts + 1] = string.rep("\t", level + 1) .. element
		end
	end
	return table.concat(parts, "\n") .. "\n" .. string.rep("\t", level or 0) .. footer
end

--- Unpack a table.
---@param parts table[]
---@return table[]
local function unpack (parts)
	local tbl = {}
	for _, outerValue in pairs(parts) do
		if type(outerValue) == "table" then
			local isarray = false
			for innerKey, innerValue in pairs(outerValue) do
				if type(innerKey) == "number" and innerKey >= 1 and innerKey <= #outerValue and math.floor(innerKey) == innerKey then
					isarray = true
					tbl[#tbl + 1] = innerValue
				end
			end
			if not isarray then
				tbl[#tbl + 1] = outerValue
			end
		end
	end
	return tbl
end

--- Iterate a table with the desired function and return the result in a new table, maintaining the indexes.
---@param tbl table The table to iterate.
---@param func function The function to use.
---@param ... any Optional parameters to pass on to the table (after the value found)
---@return table #The resulting table.
local function map (tbl, func, ...)
	local result = {}
	for index, value in ipairs(tbl) do
		result[index] = func(value, ...)
	end
	return result
end

--- Generate an expression.
---@param node Expression
---@param level? integer
---@param ... any
---@return string?
function generateExpression(node, level, ...)
	level = level or 0
	local kindof = node.kindof
	if kindof == "UnaryExpression" then
		local operator, argument = node.operator, generateExpression(node.argument, level)
		if operator == "!" then
			return string.format("not(%s)", argument)
		elseif operator == "#" then
			if node.argument.kindof == "Ellipsis" then
				return "select(\"#\", ...)"
			end
			return string.format("#%s", argument)
		elseif operator == "..." then
			return string.format("table.unpack(%s)", argument)
		end
		return operator .. argument
	elseif kindof == "Identifier" then
		local name = ...
		if name and node.value == "super" then
			return "supa"
		end
		return exports[node.value] or node.value
	elseif kindof == "StringLiteral" then
		return string.format("\"%s\"", node.value)
	elseif kindof == "Ellipsis" then
		return "..."
	elseif kindof == "Undefined" then
		return "nil"
	elseif kindof == "MemberExpression" then
		local pattern, record, property = node.computed and "%s[%s]" or "%s.%s", generateExpression(node.record, level), generateExpression(node.property, level)
		return string.format(pattern, record, property)
	elseif kindof == "CallExpression" then
		if node.caller.value == "super" and ... then
			node.caller.value = select(1, ...)
			node.arguments = unpack {
				{
					kindof = "Identifier",
					value = "self"
				},
				node.arguments
			} ---@type Identifier[]
		end
		local caller, arguments = generateExpression(node.caller, level), {} ---@type string, string[]
		for index, argument in ipairs(node.arguments) do
			arguments[index] = generateExpression(argument, level)
		end
		return string.format("%s(%s)", caller, table.concat(arguments, ", "))
	elseif kindof == "NewExpression" then
		local prototype, arguments = generateExpression(node.prototype, level), {}
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
		return string.format(pattern, generateExpression(node.left, level)) .. string.format(" %s ", operator) .. generateExpression(node.right, level, ...)
	elseif kindof == "RecordLiteralExpression" then
		local parts = {} ---@type string[]
		for index, element in ipairs(node.elements) do
			local pattern = "[%s] = %s"
			if element.key then
				if string.match(element.key.value, "^[_%a][_%w]*$") then
					(element.key --[[@as Identifier]]).kindof, pattern = "Identifier", "%s = %s"
				elseif tonumber(element.key.value) then
					(element.key --[[@as NumberLiteral]]).kindof, (element.key --[[@as NumberLiteral]]).value = "NumberLiteral", tonumber(element.key.value)
				end
			end
			local key, value = element.key and generateExpression(element.key), generateExpression(element.value, level) --[[@as string]]
			parts[index] = key and string.format(pattern, key, value) or string.format("%s", value)
		end
		return string.format(#parts > 0 and "{ %s }" or "{}", table.concat(parts, ", "))
	elseif kindof == "FunctionExpression" then
		local parameters = map(node.parameters, generateExpression, level) ---@type string[]
		local body = {} ---@type string[]
		for _, statement in ipairs(node.body) do
			body[#body + 1] = generateStatement(statement, level, ...)
		end
		return generate(string.format("function (%s)", table.concat(parameters, ", ")), body, "end", level - 1)
	elseif kindof == "ParenthesizedExpression" then
		local inner = generateExpression(node.node, level, ...)
		return string.format("(%s)", inner)
	end
	return node.value
end

--- Generate an statement.
---@param node StatementExpression
---@param level? integer
---@return string?
function generateStatement(node, level, ...)
	level = level or 0
	local kindof = node.kindof
	-- Comment
	if kindof == "Comment" then
		local content = map(node.content, function (value) return string.format("--%s", value) end)
		return table.concat(content, "\n" .. string.rep("\t", level))
	-- ImportDeclaration
	elseif kindof == "ImportDeclaration" then
		local location = generateExpression(node.location, level):match("^\"(.-)\"$")
		local internal = string.format("__%s", location:match("/(.-)%."):gsub("/", "_"))
		if node.names.kindof then
			exports[node.names.value] = string.format("%s.default", internal)
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
			local left, right = generateExpression(declaration.left, level) --[[@as string]], declaration.right and generateExpression(declaration.right, level + 1, ...) --[[@as string]] or "nil"
			if declaration.left.kindof == "RecordLiteralExpression" then
				left, right = left:match("^{%s*(.-)%s*}$"), (right == "..." or declaration.right.kindof == "UnaryExpression" or declaration.right.kindof == "CallExpression") and right or string.format("table.unpack(%s)", right)
			end
			lefts[index], rights[index] = left, right
		end
		return storage .. string.format("%s = %s", table.concat(lefts, ', '), table.concat(rights, ', '))
	-- FunctionDeclaration
	elseif kindof == "FunctionDeclaration" then
		local name, parameters = generateExpression(node.name, level), map(node.parameters, generateExpression, level) ---@type string, string[]
		local storage = ((node.decorations and node.decorations["global"]) or (node.name.kindof == "MemberExpression") or not(node.name)) and "" or "local "
		local body = {} ---@type string[]
		for _, statement in ipairs(node.body) do
			body[#body + 1] = generateStatement(statement, level + 1, node.super)
		end
		return generate(string.format("%sfunction %s (%s)", storage, name, table.concat(parameters, ", ")), body, "end", level)
	-- ReturnStatement
	elseif kindof == "ReturnStatement" then
		local arguments = map(node.arguments, generateExpression, level) ---@type string[]
		return string.format("return %s", table.concat(arguments, ", "))
	-- PrototypeDeclaration
	elseif kindof == "PrototypeDeclaration" then
		local name, parent = generateExpression(node.name) --[[@as string]], node.parent and generateExpression(node.parent) --[[@as string]]
		local safeName, safeParent = name:gsub("%.", "_"), parent and parent:gsub("%.", "_")
		local prototypeContructorComment, prototypeConstructorParameters, prototypeConstructorBody
		local prototypeIndexes, prototypeNewIndexes = {}, {}
		local prototypeVariables, prototypeFunctions = {}, {}
		for index, statementExpression in ipairs(node.body) do
			if statementExpression.kindof == "Comment" then
				local adjacentNode = node.body[index + 1]
				if adjacentNode then
					if adjacentNode.kindof == "VariableDeclaration" then
						prototypeVariables[#prototypeVariables + 1] = statementExpression
					elseif adjacentNode.kindof == "FunctionDeclaration" then
						if adjacentNode.name.value == "constructor" then
							prototypeContructorComment = statementExpression
						else
							prototypeFunctions[#prototypeFunctions + 1] = statementExpression
						end
					end
				end
			elseif statementExpression.kindof == "VariableAssignment" and statementExpression.decorations then
				local ifNode = {
					kindof = "IfStatement",
					test = {
						kindof = "BinaryExpression",
						left = {
							kindof = "Identifier",
							value = "key"
						},
						operator = "==",
						right = {
							kindof = "StringLiteral",
							value = statementExpression.assignments[1].left.value
						}
					}
				} ---@type IfStatement
				if statementExpression.decorations["set"] then
					ifNode.consequent = statementExpression.assignments[1].right.body --[=[@as BlockStatement[]]=]
					if not prototypeNewIndexes.kindof then
						prototypeNewIndexes = ifNode
					else
						prototypeNewIndexes.alternate = ifNode  --[[@as IfStatement]]
					end
				elseif statementExpression.decorations["get"] then
					ifNode.consequent = statementExpression.assignments[1].right.body --[=[@as BlockStatement[]]=]
					if not prototypeIndexes.kindof then
						prototypeIndexes = ifNode
					else
						prototypeIndexes.alternate = ifNode --[[@as IfStatement]]
					end
				end
			elseif statementExpression.kindof == "VariableDeclaration" then
				local assignments = {} ---@type AssignmentExpression[]
				for _, declaration in ipairs(statementExpression.declarations) do
					assignments[#assignments + 1] = {
						kindof = "AssignmentExpression",
						left = {
							kindof = "MemberExpression",
							record = {
								kindof = "Identifier",
								value = name
							},
							property = declaration.left,
							computed = false
						},
						operator = declaration.operator,
						right = declaration.right
					}
				end
				prototypeVariables[#prototypeVariables + 1] = {
					kindof = "VariableAssignment",
					assignments = assignments
				}
			elseif statementExpression.kindof == "FunctionDeclaration" then
				if statementExpression.name.value == "constructor" then
					local firstInnerStatementExpression = table.remove(statementExpression.body, 1)
					if firstInnerStatementExpression and firstInnerStatementExpression.kindof == "CallExpression" and firstInnerStatementExpression.caller.value == "super" then
						prototypeConstructorParameters = statementExpression.parameters
						prototypeConstructorBody = unpack {
							{
								kindof = "VariableDeclaration",
								declarations = {
									{
										kindof = "AssignmentExpression",
										left = {
											kindof = "Identifier",
											value = "self"
										},
										operator = "=",
										right = {
											kindof = "CallExpression",
											caller = {
												kindof = "Identifier",
												value = safeParent
											},
											arguments =	firstInnerStatementExpression.arguments
										}
									}
								}
							},
							{
								kindof = "CallExpression",
								caller = {
									kindof = "Identifier",
									value = "setmetatable"
								},
								arguments = {
									{
										kindof = "Identifier",
										value = "self"
									},
									{
										kindof = "Identifier",
										value = safeName
									}
								}
							},
							statementExpression.body,
							{
								kindof = "ReturnStatement",
								arguments = {
									{
										kindof = "Identifier",
										value = "self"
									}
								}
							}
						}
					else
						prototypeConstructorBody = unpack {
							{
								kindof = "VariableDeclaration",
								declarations = {
									{
										kindof = "AssignmentExpression",
										left = {
											kindof = "Identifier",
											value = "self"
										},
										operator = "=",
										right = {
											kindof = "CallExpression",
											caller = {
												kindof = "Identifier",
												value = "setmetatable"
											},
											arguments = {
												{
													kindof = "RecordLiteralExpression",
													elements = {}
												},
												{
													kindof = "Identifier",
													value = safeName
												}
											}
										}
									}
								}
							},
							firstInnerStatementExpression,
							statementExpression.body,
							{
								kindof = "ReturnStatement",
								arguments = {
									{
										kindof = "Identifier",
										value = "self"
									}
								}
							}
						}
					end
				else
					prototypeFunctions[#prototypeFunctions + 1] = {
						kindof = "VariableAssignment",
						assignments = {
							{
								kindof = "AssignmentExpression",
								left = {
									kindof = "MemberExpression",
									record = {
										kindof = "Identifier",
										value = safeName
									},
									property = statementExpression.name,
									computed = false
								},
								operator = "=",
								right = {
									kindof = "FunctionExpression",
									parameters = unpack {
										{
											kindof = "Identifier",
											value = "self"
										},
										statementExpression.parameters
									},
									body = statementExpression.body --[=[@as BlockStatement[]]=]
								} --[[@as FunctionExpression]]
							} --[[@as AssignmentExpression]]
						},
						decorations = {
							["method"] = true
						}
					} --[[@as VariableAssignment]]
				end
			end
		end
		local prototypeConstructor = {
			kindof = "VariableAssignment",
			assignments = {
				{
					kindof = "AssignmentExpression",
					left = {
						kindof = "MemberExpression",
						record = {
							kindof = "Identifier",
							value = safeName
						},
						property = {
							kindof = "Identifier",
							value = "__call"
						},
						computed = false
					},
					operator = "=",
					right = {
						kindof = "FunctionExpression",
						parameters = unpack {
							{
								kindof = "Identifier",
								value = safeName
							},
							prototypeConstructorParameters or (parent and { kindof = "Ellipsis" } or nil)
						},
						body = unpack {
							prototypeConstructorBody or {
								kindof = "ReturnStatement",
								arguments = {
									{
										kindof = "CallExpression",
										caller = {
											kindof = "Identifier",
											value = "setmetatable"
										},
										arguments = {
											{
												kindof = "RecordLiteralExpression",
												elements = {}
											},
											{
												kindof = "Identifier",
												value = safeName
											}
										}
									}
								}
							}
						} --[=[@as BlockStatement[]]=]
					}
				}
			}
		}
		return generateStatement({
			kindof = "VariableDeclaration",
			declarations = {
				{
					kindof = "AssignmentExpression",
					left = node.name,
					operator = "=",
					right = {
						kindof = "CallExpression",
						caller = {
							kindof = "ParenthesizedExpression",
							node = {
								kindof = "FunctionExpression",
								parameters = {
									parent and { kindof = "Identifier", value = safeParent }
								},
								body = unpack {
									{
										kindof = "VariableDeclaration",
										declarations = {
											{
												kindof = "AssignmentExpression",
												left = {
													kindof = "Identifier",
													value = safeName
												},
												operator = "=",
												right = {
													kindof = "RecordLiteralExpression",
													elements = {}
												}
											}
										}
									},
									(prototypeIndexes.kindof == "IfStatement") and {
										kindof = "VariableAssignment",
										assignments = {
											{
												kindof = "AssignmentExpression",
												left = {
													kindof = "MemberExpression",
													record = {
														kindof = "Identifier",
														value = safeName
													},
													property = {
														kindof = "Identifier",
														value = "__index"
													},
													computed = false
												},
												operator = "=",
												right = {
													kindof = "FunctionExpression",
													parameters = {
														{
															kindof = "Identifier",
															value = "self"
														},
														{
															kindof = "Identifier",
															value = "key"
														}
													},
													body = unpack {
														prototypeIndexes,
														{
															kindof = "ReturnStatement",
															arguments = {
																parent and {
																	kindof = "BinaryExpression",
																	left = {
																		kindof = "CallExpression",
																		caller = {
																			kindof = "Identifier",
																			value = "rawget"
																		},
																		arguments = {
																			{
																				kindof = "Identifier",
																				value = safeName
																			},
																			{
																				kindof = "Identifier",
																				value = "key"
																			}
																		}
																	},
																	operator = "or",
																	right = {
																		kindof = "MemberExpression",
																		record = {
																			kindof = "Identifier",
																			value = safeParent
																		},
																		property = {
																			kindof = "Identifier",
																			value = "key"
																		},
																		computed = true
																	}
																} or {
																	kindof = "CallExpression",
																	caller = {
																		kindof = "Identifier",
																		value = "rawget"
																	},
																	arguments = {
																		{
																			kindof = "Identifier",
																			value = safeName
																		},
																		{
																			kindof = "Identifier",
																			value = "key"
																		}
																	}
																}
															}
														}
													}
												}
											}
										}
									} or {
										kindof = "VariableAssignment",
										assignments = {
											{
												kindof = "AssignmentExpression",
												left = {
													kindof = "MemberExpression",
													record = {
														kindof = "Identifier",
														value = safeName
													},
													property = {
														kindof = "Identifier",
														value = "__index"
													},
													computed = false
												},
												operator = "=",
												right = {
													kindof = "Identifier",
													value = safeName
												}
											}
										}
									},
									(prototypeNewIndexes.kindof == "IfStatement") and {
										kindof = "VariableAssignment",
										assignments = {
											{
												kindof = "AssignmentExpression",
												left = {
													kindof = "MemberExpression",
													record = {
														kindof = "Identifier",
														value = safeName
													},
													property = {
														kindof = "Identifier",
														value = "__newindex"
													},
													computed = false
												},
												operator = "=",
												right = {
													kindof = "FunctionExpression",
													parameters = {
														{
															kindof = "Identifier",
															value = "self"
														},
														{
															kindof = "Identifier",
															value = "key"
														},
														{
															kindof = "Identifier",
															value = "value"
														}
													},
													body = unpack {
														(function ()
															prototypeNewIndexes.alternate = {
																{
																	kindof = "CallExpression",
																	caller = {
																		kindof = "Identifier",
																		value = "rawset"
																	},
																	arguments = {
																		{
																			kindof = "Identifier",
																			value = "self"
																		},
																		{
																			kindof = "Identifier",
																			value = "key"
																		},
																		{
																			kindof = "Identifier",
																			value = "value"
																		}
																	}
																}
															}
															return prototypeNewIndexes
														end)()
													}
												}
											}
										}
									},
									prototypeContructorComment,
									prototypeConstructor,
									prototypeVariables,
									prototypeFunctions,
									{
										kindof = "ReturnStatement",
										arguments = {
											{
												kindof = "CallExpression",
												caller = {
													kindof = "Identifier",
													value = "setmetatable"
												},
												arguments = {
													{
														kindof = "Identifier",
														value = safeName
													},
													{
														kindof = "Identifier",
														value = safeName
													}
												}
											}
										}
									}
								} --[=[@as BlockStatement[]]=],
								decorations = {
									["prototype"] = true
								}
							}
						},
						arguments = {
							parent and { kindof = "Identifier", value = parent }
						}
					}
				}
			},
			decorations = {
				["global"] = (node.name.kindof == "MemberExpression") and true or nil

			}
		}, level)
	elseif kindof == "IfStatement" then
		local block, latest = "if", node ---@type string, IfStatement?
		while latest do
			repeat
				local head, body = latest.test and generateExpression(latest.test, level), {} ---@type string?, string[]
				for index, statement in ipairs(latest.consequent or latest) do
					body[index] = generateStatement(statement, level + 1, ...)
				end
				block, latest = block .. generate(string.format(head and " %s then" or "else", head or ""), body, "", level) .. ((latest.alternate and latest.alternate.test) and "elseif" or ""), latest.alternate
			until not latest
		end
		return block .. "end"
	elseif kindof == "WhileLoop" then
		local condition, body = generateExpression(node.condition, level), {} ---@type string, string[]
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
			head = string.format("%s, %s%s", generateExpression(node.condition.init --[[@as Expression]]), generateExpression(node.condition.goal, level), node.condition.step and string.format(", %s", generateExpression(node.condition.step, level)) or "")
		else
			local variables = {}
			for index, variable in ipairs(node.condition.variable) do
				variables[index] = generateExpression(variable, level)
			end
			head = string.format("%s in %s", table.concat(variables, ", "), generateExpression(node.condition.iterable, level))
		end
		for index, statement in ipairs(node.body) do
			body[index] = generateStatement(statement, level + 1)
		end
		return generate(string.format("for %s do", head), body, "end", level)
	elseif kindof == "VariableAssignment" then
		local lefts, rights = {}, {} ---@type string[], string[]
		for index, assignment in ipairs(node.assignments) do
			local left = generateExpression(assignment.left, level) --[[@as string]]
			local right ---@string
			if node.decorations and node.decorations["method"] then
				local name = (assignment.left.kindof == "MemberExpression") and assignment.left.property.value or assignment.left.value
				right = generateExpression(assignment.right, level + 1, { name = name --[[@as string]] })
			end
			right = generateExpression(assignment.right, level + 1, ...) --[[@as string]]
			local complexOperator = assignment.operator:sub(1, 1):match("[%-%+%*//%^%%]") or (assignment.operator:sub(1, 2) == ".." and "..")
			if assignment.left.kindof == "RecordLiteralExpression" then
				left, right = left:match("^{%s*(.-)%s*}$"), (right == "..." or assignment.right.kindof == "UnaryExpression" or assignment.right.kindof == "CallExpression") and right or string.format("table.unpack(%s)", right)
			end
			if complexOperator then
				right = left .. string.format(" %s ", complexOperator) .. right
			end
			lefts[index], rights[index] = left, right
		end
		return string.format("%s = %s", table.concat(lefts, ', '), table.concat(rights, ', '))
	elseif kindof == "CallExpression" or kindof == "NewExpression" then
		return generateExpression(node --[[@as Expression]], level, ...)
	end
end

--- Generates valid Lua code from an AST definition.
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

---@alias Generator<T> fun(node: T, level?: integer, ...): string?