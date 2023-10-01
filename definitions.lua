---@meta

---@class Lexeme
---@field typeof? string Lexeme type.
---@field value string Lexeme value.
---@field line number Lexeme line number.
---@field startIndex? number

---@alias NextLexeme fun(): string?, string, number, number
---@alias CurrentLexeme fun(): string?, string, number

---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined
---@alias MemberExpression { kindof: "MemberExpression", identifier: Identifier, property: Expression }
---@alias CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
---@alias Operator "and"|"or"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: Operator, right: Expression }
---@alias RecordElement { kindof: "RecordElement", key?: Identifier, value: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteral", properties: RecordElement[] }
---@alias AssignmentExpression { kindof: "AssignmentExpression", left: Identifier, operator: "=", right: Expression }
---@alias Expression AssignmentExpression|RecordLiteralExpression|BinaryExpression|MemberExpression|CallExpression|Term

---@alias Statement Comment|VariableDeclaration|FunctionDeclaration|ReturnStatement|PrototypeDeclaration|IfStatement|WhileLoop|BreakStatement|ForLoop
---@alias BlockStatement Statement|AssignmentExpression|CallExpression

---@alias Comment { kindof: "Comment", content: string }
---@alias VariableDeclarator { kindof: "VariableDeclarator", identifier: Identifier, init?: Expression }
---@alias VariableDeclaration { kindof: "VariableDeclaration", declarations: VariableDeclarator[] }
---@alias FunctionDeclaration { kindof: "FunctionDeclaration", name: Identifier|MemberExpression, parameters: Identifier[], body: BlockStatement[] }
---@alias ReturnStatement { kindof: "ReturnStatement", argument: Expression }
---@alias PrototypeDeclaration { kindof: "PrototypeDeclaration", name: Expression, parent: Expression, body: BlockStatement[] }
---@alias IfStatement { kindof: "IfStatement", test: Expression, consequent: BlockStatement[], alternate?: IfStatement|BlockStatement[] }
---@alias WhileLoop { kindof: "WhileLoop", condition: Expression, body: Statement[] }
---@alias BreakStatement { kindof: "BreakStatement" }
---@alias ForLoop { kindof: "ForLoop", init: AssignmentExpression, goal: Expression, step?: Expression, body: BlockStatement[] }

---@alias StatementExpression Statement|Expression