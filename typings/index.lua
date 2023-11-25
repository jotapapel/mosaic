---@meta

---@class Lexeme
---@field typeof? string Lexeme type.
---@field value string Lexeme value.
---@field line integer Lexeme line number.
---@field startIndex? integer

---@alias NextLexeme fun(): string?, string, integer, integer
---@alias CurrentLexeme fun(): string, string, integer

---@alias UnaryExpression { kindof: "UnaryExpression", operator: "-"|"$"|"#"|"!", argument: Expression }
---@alias Identifier { kindof: "Identifier", value: string }
---@alias StringLiteral { kindof: "StringLiteral", value: string, key?: boolean }
---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true"|"false" }
---@alias Ellipsis { kindof: "Ellipsis", value: string }
---@alias Undefined { kindof: "Undefined" }
---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined|Ellipsis

---@alias MemberExpression { kindof: "MemberExpression", record: Expression, property: Expression, computed: boolean, instance?: boolean }
---@alias CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
---@alias NewExpression { kindof: "NewExpression", caller: Expression, arguments: Expression[] }
---@alias BinaryOperator "and"|"or"|"is"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: BinaryOperator, right: Expression }
---@alias RecordElement { kindof: "RecordElement", key?: (StringLiteral|Identifier|NumberLiteral)?, value: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteralExpression", elements: RecordElement[] }
---@alias AssignmentOperator "="|"+="|"-="|"*="|"/="|"^="|"%="
---@alias AssignmentExpression { kindof: "AssignmentExpression", left?: MemberExpression|Identifier, operator?: AssignmentOperator, right: Expression }
---@alias ParenthesizedExpression { kindof: "ParenthesizedExpression", node: Expression }
---@alias Expression Term|MemberExpression|CallExpression|NewExpression|BinaryExpression|RecordLiteralExpression|ParenthesizedExpression

---@alias Comment { kindof: "Comment", content: string[] }
---@alias ImportDeclaration { kindof: "ImportDeclaration", names: Expression, filename: StringLiteral }
---@alias VariableDeclaration { kindof: "VariableDeclaration", declarations: AssignmentExpression[], decorations?: string[] }
---@alias VariableAssignment { kindof: "VariableAssignment", assignments: AssignmentExpression[] }
---@alias FunctionDeclaration { kindof: "FunctionDeclaration", name: Expression, parameters: Identifier[], body: BlockStatement[], decorations?: string[] }
---@alias ReturnStatement { kindof: "ReturnStatement", arguments: Expression[] }
---@alias PrototypeDeclaration { kindof: "PrototypeDeclaration", name: Expression, parent: Expression, body: (Comment|VariableDeclaration|FunctionDeclaration)[], decorations?: string[] }
---@alias IfStatement { kindof: "IfStatement", test: Expression, consequent: BlockStatement[], alternate?: IfStatement|BlockStatement[] }
---@alias WhileLoop { kindof: "WhileLoop", condition: Expression, body: BlockStatement[] }
---@alias NumericLoopCondition { init: AssignmentExpression, goal: Expression, step?: Expression }
---@alias IterationLoopCondition { variable: Identifier[], iterable: Expression }
---@alias ForLoop { kindof: "ForLoop", condition: NumericLoopCondition|IterationLoopCondition, body: BlockStatement[] }
---@alias BreakStatement { kindof: "BreakStatement" }
---@alias Statement Comment|ImportDeclaration|VariableDeclaration|FunctionDeclaration|ReturnStatement|PrototypeDeclaration|IfStatement|WhileLoop|ForLoop|BreakStatement|VariableAssignment
---@alias StatementExpression Statement|Expression
---@alias BlockStatement Statement|CallExpression|NewExpression

---@alias AST { kindof: "Program"|"Module", body: StatementExpression[] }
---@alias Parser<T> fun(): T?
---@alias Generator<T> fun(node: T, level?: integer): string?

---@alias JSONValue { [string]: JSONValue }|JSONValue[]|boolean|number|string