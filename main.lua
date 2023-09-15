--local scanner = require "scanner"
local parse = require "parser"
local trace = require "tracer"

local source = [[
	a + 2 * 32
]]

for node in parse(source) do
	trace(node)
end