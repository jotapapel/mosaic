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

---@alias UnaryExpression { kindof: "UnaryExpression", operator: "-"|"$"|"#"|"!", argument: Expression }
---@alias Identifier { kindof: "Identifier", value: string }
---@alias StringLiteral { kindof: "StringLiteral", value: string, iskey?: boolean }
---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true" | "false" }
---@alias Undefined { kindof: "Undefined" }
---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined

---@alias MemberExpression { kindof: "MemberExpression", record: Expression, property: Expression, computed: boolean, instance?: boolean }
---@alias CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
---@alias NewExpression { kindof: "NewExpression", caller: Expression, arguments: Expression[] }
---@alias BinaryOperator "and"|"or"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: BinaryOperator, right: Expression }
---@alias RecordElement { kindof: "RecordElement", key?: (UnaryExpression|Identifier|NumberLiteral)?, value: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteralExpression", elements: RecordElement[] }
---@alias AssignmentExpression { kindof: "AssignmentExpression", left: Term, operator: "=", right: Expression }
---@alias VariableAssignment { kindof: "VariableAssignment", assignments: AssignmentExpression[] }
---@alias ParenthesizedExpression { kindof: "ParenthesizedExpression", node: Expression }
---@alias Expression Term|MemberExpression|CallExpression|BinaryExpression|RecordLiteralExpression|AssignmentExpression|ParenthesizedExpression

---@alias Comment { kindof: "Comment", content: string }
---@alias VariableDeclarator { kindof: "VariableDeclarator", identifier: Identifier, init?: Expression }
---@alias VariableDeclaration { kindof: "VariableDeclaration", declarations: VariableDeclarator[], decorations?: string[] }
---@alias FunctionDeclaration { kindof: "FunctionDeclaration", name: Identifier|MemberExpression, parameters: Identifier[], body: BlockStatement[], decorations?: string[] }
---@alias ReturnStatement { kindof: "ReturnStatement", arguments: Expression[] }
---@alias PrototypeDeclaration { kindof: "PrototypeDeclaration", name: Identifier|MemberExpression, parent: Expression, body: BlockStatement[], decorations?: string[] }
---@alias IfStatement { kindof: "IfStatement", test: Expression, consequent: BlockStatement[], alternate?: IfStatement|BlockStatement[] }
---@alias WhileLoop { kindof: "WhileLoop", condition: Expression, body: BlockStatement[] }
---@alias BreakStatement { kindof: "BreakStatement" }
---@alias NumericLoopCondition { init: AssignmentExpression, goal: Expression, step?: Expression }
---@alias IterationLoopCondition { variable: Identifier[], iterable: Expression }
---@alias ForLoop { kindof: "ForLoop", condition: NumericLoopCondition|IterationLoopCondition, body: BlockStatement[] }
---@alias Statement Comment|VariableDeclaration|FunctionDeclaration|ReturnStatement|PrototypeDeclaration|IfStatement|WhileLoop|BreakStatement|ForLoop
---@alias BlockStatement Statement|AssignmentExpression|CallExpression
---@alias StatementExpression Statement|Expression

---@alias JSONValue { [string]: JSONValue }|JSONValue[]|boolean|number|string

---@alias ExpressionGenerator fun(node: Expression): string
---@alias StatementGenerator fun(node: StatementExpression, level?: integer): string?