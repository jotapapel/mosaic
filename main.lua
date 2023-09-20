local parse = require "parser"
local trace = require "tracer"

local file <close> = io.open("index.m")
local source = file:read("*a")

for node in parse(source) do
	trace(node)
end