---@meta

---@class Lexeme
---@field typeof? string Lexeme type.
---@field value string Lexeme value.
---@field line integer Lexeme line number.
---@field startIndex? integer

---@alias NextLexeme fun(): string?, string, integer, integer
---@alias CurrentLexeme fun(): string, string, integer

---@alias ExpressionParser fun(): Expression?
---@alias StatementParser fun(): StatementExpression?

---@alias UnaryOperator "-"|"$"|"#"|"!"
---@alias UnaryExpression { kindof: "UnaryExpression", operator: UnaryOperator, argument: Expression }
---@alias Identifier { kindof: "Identifier", value: string }
---@alias StringLiteral { kindof: "StringLiteral", value: string }
---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true" | "false" }
---@alias Undefined { kindof: "Undefined" }
---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined

---@alias MemberExpression { kindof: "MemberExpression", record: Term, property: Expression, computed: boolean }
---@alias CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
---@alias BinaryOperator "and"|"or"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: BinaryOperator, right: Expression }
---@alias RecordElement { kindof: "RecordElement", key?: Term, value: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteralExpression", elements: RecordElement[] }
---@alias AssignmentExpression { kindof: "AssignmentExpression", left: Term, operator: "=", right: Expression }
---@alias ParenthesizedExpression { kindof: "ParenthesizedExpression", node: Expression }
---@alias Expression Term|MemberExpression|CallExpression|BinaryOperator|RecordLiteralExpression|AssignmentExpression|ParenthesizedExpression

---@alias Comment { kindof: "Comment", content: string }
---@alias VariableDeclarator { kindof: "VariableDeclarator", identifier: Identifier, init?: Expression }
---@alias VariableDeclaration { kindof: "VariableDeclaration", declarations: VariableDeclarator[], decorations?: string[] }
---@alias FunctionDeclaration { kindof: "FunctionDeclaration", name: Identifier|MemberExpression, parameters: Identifier[], body: BlockStatement[], decorations?: string[] }
---@alias ReturnStatement { kindof: "ReturnStatement", argument: Expression }
---@alias PrototypeDeclaration { kindof: "PrototypeDeclaration", name: Identifier|MemberExpression, parent: Expression, body: BlockStatement[], decorations?: string[] }
---@alias IfStatement { kindof: "IfStatement", test: Expression, consequent: BlockStatement[], alternate?: IfStatement|BlockStatement[] }
---@alias WhileLoop { kindof: "WhileLoop", condition: Expression, body: Statement[] }
---@alias BreakStatement { kindof: "BreakStatement" }
---@alias NumericLoopCondition { init: AssignmentExpression, goal: Expression, step?: Expression }
---@alias IterationLoopCondition { variable: Term[], iterable: Expression }
---@alias ForLoop { kindof: "ForLoop", condition: NumericLoopCondition|IterationLoopCondition, body: BlockStatement[] }
---@alias Statement Comment|VariableDeclaration|FunctionDeclaration|ReturnStatement|PrototypeDeclaration|IfStatement|WhileLoop|BreakStatement|ForLoop
---@alias BlockStatement Statement|AssignmentExpression|CallExpression
---@alias StatementExpression Statement|Expression

---@alias JSONValue { [string]: JSONValue }|JSONValue[]|string|number|boolean

---@alias ExpressionGenerator fun(node: Expression): string?
---@alias StatementGenerator fun(node: StatementExpression): string?