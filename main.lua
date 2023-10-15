local json = require "json"
local parse = require "frontend.parser"

local file <close> = io.open("index.tile") or error("Source file not found.")
local source = file:read("*a")

local ast = parse(source)
print(json.encode(ast, true))