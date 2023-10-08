local file <close> = io.open("index.m") or error("File not found.")
local source = file:read("*a")


local parse = require "frontend.parser"
local trace = require "tracer"
for node in parse(source) do
	trace(node)
end
--]]

--[[
local generate = require "generator"
generate(source, "target/lua.json")
--]]