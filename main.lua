local json = require "json"
local parse = require "frontend.parser"
local generate = require "backend.generator"

local file <close> = io.open("index.m") or error("Source file not found.")
local source = file:read("*a")

local ast = parse(source)
--[[local output = generate(ast)
print(output)--]]
print(json.encode(ast, true))