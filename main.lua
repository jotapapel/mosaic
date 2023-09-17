--local scan = require "scanner"
local parse = require "parser"
local trace = require "tracer"

local source = [[
	function myFunction ()
		var a = 32
	end
]]

for node in parse(source) do
	trace(node)
end