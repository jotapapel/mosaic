local json = require "lib.json"
local parse = require "src.parser"
local generate = require "languages.Lua.generator"

local name, target, option = ...
local file <close> = io.open(name) or error("Source file not found.")
local source = file:read("*a")

local ast = parse(source)
--print(json.encode(ast, true))

local output = generate(ast)
print(output)
--local outfile <const>, err = io.open(target, "w+")
--outfile:write(output)