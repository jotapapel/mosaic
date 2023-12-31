---@meta NodeTypes

--- Terms
---@alias UnaryOperator "not"|"-"|"#"|"..."
---@alias UnaryExpression { kindof: "UnaryExpression", operator: UnaryOperator, argument: Expression }
---@alias Identifier { kindof: "Identifier", value: string }
---@alias StringLiteral { kindof: "LongStringLiteral"|"StringLiteral", value: string }
---@alias NumberLiteral { kindof: "NumberLiteral", value: number }
---@alias BooleanLiteral { kindof: "BooleanLiteral", value: "true"|"false" }
---@alias Undefined { kindof: "Undefined" }
---@alias Term UnaryExpression|Identifier|StringLiteral|NumberLiteral|BooleanLiteral|Undefined

--- Expressions
---@alias MemberExpression { kindof: "MemberExpression", record: MemberExpression|Identifier|ParenthesizedExpression, property: Expression, computed: boolean, instance?: boolean }
---@alias CallExpression { kindof: "CallExpression", caller: MemberExpression|Identifier|ParenthesizedExpression, arguments: Expression[] }
---@alias NewExpression { kindof: "NewExpression", prototype: MemberExpression|Identifier, arguments: Expression[] }
---@alias BinaryOperator "and"|"or"|"is"|"=="|">"|"<"|">="|"<="|"<>"|"+"|"-"|"*"|"/"|"^"|"%"|".."
---@alias BinaryExpression { kindof: "BinaryExpression", left: Expression, operator: BinaryOperator, right: Expression }
---@alias RecordLiteralExpression { kindof: "RecordLiteralExpression", elements: table<string, Expression> }
---@alias AssignmentOperator "="|"+="|"-="|"*="|"/="|"^="|"%="|"..="
---@alias AssignmentExpression { kindof: "AssignmentExpression", left: MemberExpression|RecordLiteralExpression|Identifier, operator: AssignmentOperator, right: Expression }
---@alias FunctionExpression { kindof: "FunctionExpression", parameters: Identifier[], body: BlockStatement[] }
---@alias ParenthesizedExpression { kindof: "ParenthesizedExpression", nodeof: Expression }
---@alias Expression Term|MemberExpression|CallExpression|NewExpression|BinaryExpression|RecordLiteralExpression|FunctionExpression|ParenthesizedExpression

--- Statements
---@alias Comment { kindof: "Comment", content: string[] }
---@alias ImportDeclaration { kindof: "ImportDeclaration", names: Identifier|Identifier[], location: StringLiteral }
---@alias VariableDeclaration { kindof: "VariableDeclaration", declarations: AssignmentExpression[], decorations: table<string, true>? }
---@alias VariableAssignment { kindof: "VariableAssignment", assignments: AssignmentExpression[], decorations: table<string, true>? }
---@alias FunctionDeclaration { kindof: "FunctionDeclaration", name: Expression, super?: Identifier, parameters: Identifier[], body: BlockStatement[], decorations: table<string, true>? }
---@alias ReturnStatement { kindof: "ReturnStatement", arguments: Expression[] }
---@alias PrototypeDeclaration { kindof: "PrototypeDeclaration", name: Expression, parent: Expression, body: BlockStatement[], decorations: table<string, true>? }
---@alias IfStatement { kindof: "IfStatement", test: Expression, consequent: BlockStatement[], alternate?: IfStatement|BlockStatement[] }
---@alias WhileLoop { kindof: "WhileLoop", condition: Expression, body: BlockStatement[] }
---@alias NumericLoopCondition { init: AssignmentExpression, goal: Expression, step?: Expression }
---@alias IterationLoopCondition { variable: Identifier[], iterable: Expression }
---@alias ForLoop { kindof: "ForLoop", condition: NumericLoopCondition|IterationLoopCondition, body: BlockStatement[] }
---@alias BreakStatement { kindof: "BreakStatement" }

---@alias Statement Comment|ImportDeclaration|VariableDeclaration|VariableAssignment|FunctionDeclaration|ReturnStatement|PrototypeDeclaration|IfStatement|WhileLoop|ForLoop|BreakStatement
---@alias BlockStatement Statement|CallExpression|NewExpression

---@alias StatementExpression Statement|Expression