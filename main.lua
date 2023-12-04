local json = require "lib.json"
local parse = require "src.parser"
local generate = require "src.generator.Lua"

local name, target, option = ...
local file <close> = io.open(name) or error("Source file not found.")
local source = file:read("*a")

local ast = parse(source, "Program")
local output = (option == "--ast") and json.encode(ast, true) or generate(ast)

local outfile <const>, err = io.open(target, "w+") --[[@as file*]]
outfile:write(output)