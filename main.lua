local parse = require "parser"
---@overload fun(value: Expression|Statement, inline?: boolean)
local trace = require "tracer"

local file <close> = io.open("index.m") or error("File not found.")
local source = file:read("*a")

for node in parse(source) do
	trace(node)
end