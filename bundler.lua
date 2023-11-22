local fs = require "lib.fs"
local parse = require "src.parser"
local generate = require "languages.Lua.generator"
local id = 0

local function createAsset (filename)
	local file <close> = io.open(filename) or error("Source file not found.")
	local source = file:read("*a")
	local ast, dependencies = parse(source), {}
	for _, node in ipairs(ast.body) do
		if node.kindof == "ImportDeclaration" then
			dependencies[#dependencies + 1] = node.filename.value
		end
	end
	id = id + 1
	local code = generate(ast, 3)
	return {
		id = id,
		filename = filename,
		dependencies = dependencies,
		code = code
	}
end

local function createGraph (entry)
	local mainAsset = createAsset(entry)
	local queue = { mainAsset }
	for _, asset in ipairs(queue) do
		asset.mapping = {}
		local dirname = fs.getdir(asset.filename)
		for _, relativePath in ipairs(asset.dependencies) do
			local absolutePath = fs.join(dirname, relativePath)
			local child = createAsset(absolutePath)
			asset.mapping[relativePath] = child.id
			queue[#queue + 1] = child
		end
	end
	return queue
end

local function bundle (graph)
	local modules = {}
	for _, module in ipairs(graph) do
		local mapping = {}
		for relativePath, moduleId in pairs(module.mapping) do
			mapping[#mapping + 1] = string.format("[\"%s\"] = %i", relativePath, moduleId)
		end
		modules[#modules + 1] = string.format([[{
		function (process, module, exports)
%s
		end,
		{%s}
	}]], module.code, #mapping > 0 and string.format(" %s ", table.concat(mapping, ", ")) or "")
	end
	return string.format([[(function (modules)
		local process
		function process (id)
			local fn, mapping = table.unpack(modules[id])
			local module = { exports = {} }
			fn(function (name) return process(mapping[name]) end, module, module.exports)
			return module.exports
		end
		process(1)
end)({
	%s
})]], table.concat(modules, ",\n\t"))
end

local graph = createGraph("./tests/index.tle")
local result = bundle(graph)
print(result)