---@meta NodeTypes

--- Terms
---@alias UnaryExpression { kindof: "UnaryExpression", operator: "-"|"$"|"#"|"!", argument: Expression }
---@alias Identifier { kindof: "Identifier", value: string }
---@alias StringLiteral { kindof: "StringLiteral", value: string, key?: boolean }
---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true"|"false" }
---@alias Ellipsis { kindof: "Ellipsis", value: string }
---@alias Undefined { kindof: "Undefined" }
---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined|Ellipsis

--- Expressions
---@alias MemberExpression { kindof: "MemberExpression", record: Expression, property: Expression, computed: boolean, instance?: boolean }
---@alias CallExpression { kindof: "CallExpression", caller: Expression, arguments: Expression[] }
---@alias NewExpression { kindof: "NewExpression", prototype: Expression, arguments: Expression[] }
---@alias BinaryOperator "and"|"or"|"is"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: BinaryOperator, right: Expression }
---@alias RecordElement { kindof: "RecordElement", key?: StringLiteral|Identifier|NumberLiteral, value: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteralExpression", elements: RecordElement[] }
---@alias AssignmentOperator "="|"+="|"-="|"*="|"/="|"^="|"%="
---@alias AssignmentExpression { kindof: "AssignmentExpression", left?: MemberExpression|Identifier, operator?: AssignmentOperator, right: Expression }
---@alias FunctionExpression { kindof: "FunctionExpression", parameters: Identifier[], body: BlockStatement[] }
---@alias ParenthesizedExpression { kindof: "ParenthesizedExpression", node: Expression }
---@alias Expression Term|ParenthesizedExpression|MemberExpression|CallExpression|NewExpression|RecordLiteralExpression|FunctionExpression|BinaryExpression

--- Statements
---@alias Comment { kindof: "Comment", content: string[] }
---@alias ImportDeclaration { kindof: "ImportDeclaration", names: Identifier|Identifier[], location: StringLiteral }
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
---@alias BlockStatement Statement|CallExpression|NewExpression
---@alias StatementExpression Statement|Expression