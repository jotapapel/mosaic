local json = require "json"
local parse = require "frontend.parser"

local file <close> = io.open("index.m") or error("Source file not found.")
local source = file:read("*a")

local program = parse(source, {})
print(json.encode({ kindof = "Program", body = program }, true))