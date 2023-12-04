local fs = require "lib.fs"
local parse = require "src.parser"
local generate = require "src.generator.Lua"
local id = 0

--- Create an asset from a Lua file.
---@param location string
---@param kindof "Program"|"Module"
---@return FileBundle
local function createAsset (location, kindof)
	local file <close> = io.open(location) or error("Source file not found.")
	local source = file:read("*a")
	local ast, dependencies = parse(source, kindof), {} ---@type AST, string[]
	for _, node in ipairs(ast.body) do
		if node.kindof == "ImportDeclaration" then
			dependencies[#dependencies + 1] = node.location.value
		end
	end
	id = id + 1
	return {
		id = id,
		location = location,
		dependencies = dependencies,
		code = generate(ast, 3)
	}
end

--- Process a Lua file to bundle it's dependencies.
---@param entry string
---@return FileBundle[]
local function createGraph (entry)
	local mainAsset, mainDependencies = createAsset(entry, "Program"), {}
	local queue = { mainAsset } ---@type FileBundle[]
	for _, asset in ipairs(queue) do
		asset.mapping = {}
		local dirname = fs.getdir(asset.location)
		for _, relativePath in ipairs(asset.dependencies) do
			local absolutePath = fs.join(dirname, relativePath)
			local child = createAsset(absolutePath, "Module")
			asset.mapping[relativePath] = mainDependencies[relativePath] or child.id
			if not mainDependencies[relativePath] then
				queue[#queue + 1], mainDependencies[relativePath] = child, child.id
			end
		end
	end
	return queue
end

--- Bundle all files and dependencies.
---@param graph FileBundle[]
---@return string
local function bundle (graph)
	local modules = {} ---@type string[]
	for _, module in ipairs(graph) do
		local mapping = {} ---@type string[]
		for relativePath, moduleId in pairs(module.mapping) do
			mapping[#mapping + 1] = string.format("[\"%s\"] = %i", relativePath, moduleId)
		end
		modules[#modules + 1] = string.format([[{
		-- %s
		function (require, exports)
%s
		end,
		{%s}
	}]], fs.toabsolute(module.location), module.code, #mapping > 0 and string.format(" %s ", table.concat(mapping, ", ")) or "")
	end
	return string.format([[(function (modules)
		local require
		function require (id)
			local fn, mapping = table.unpack(modules[id])
			local module = { exports = {} }
			fn(function (name) return require(mapping[name]) end, module.exports)
			return module.exports
		end
		require(1)
end)({
	%s
})]], table.concat(modules, ",\n\t"))
end

local mainFilepath, targetFilepath = ...
local graph = createGraph(mainFilepath)
local result = bundle(graph)

local outfile <const>, err = io.open(targetFilepath, "w+") --[[@as file*]]
outfile:write(result)

---@alias FileBundle { id: integer, location: string, dependencies: string[], code: string, mapping?: table<string, integer> }