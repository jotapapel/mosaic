local json = require "lib.json"
local parse = require "src.parser"
local generate = require "languages.Lua.generator"

local file <close> = io.open("tests/Lua_tests/index.tile") or error("Source file not found.")
local source = file:read("*a")

local output = generate(source)
print(output)