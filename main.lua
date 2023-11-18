local json = require "lib.json"
local parse = require "src.parser"
local generate = require "languages.Lua.generator"

local name, target = ...
local file <close> = io.open(name) or error("Source file not found.")
local source = file:read("*a")

local output = generate(source)
local outfile <const>, err = io.open(target, "w+")
outfile:write(output)
