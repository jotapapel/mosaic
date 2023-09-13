local scanner = require "scanner"

local source = [[
	a & b
]]

for typeof, value in scanner(source) do
	print(typeof, value)
end