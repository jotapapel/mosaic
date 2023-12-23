local fs = require "lib.fs"
local json = require "lib.json"
local parse = require "src.parser"
local generate = require "src.generator.Lua"

local path, option, display = ...
local ast = parse(path, "Module")
local output = (option == "--ast") and json.encode(ast, true) or generate(ast)

if option == "--display" or display == "--display" then
	io.write(output, "\n")
	os.exit()
else
	local outpath = fs.toabsolute(path):match("^(.-)%.tle$") .. ((option == "--ast") and ".json" or ".lua")
	local outfile <const>, err = io.open(outpath, "w+") --[[@as file*]]
	outfile:write(output)
end