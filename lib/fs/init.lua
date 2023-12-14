--- Takes a relative path as input and returns the corresponding absolute path.
---@param relativePath string The relative path.
---@param basePath? string Base path to generate the absolute path.
---@return string #The absolute path.
local function toabsolute (relativePath, basePath)
    local scriptDirectory = basePath or debug.getinfo(0, "S").source:sub(2):gsub("^[^/]", "/%1")
    local absolutePath = scriptDirectory:match("(.*[/\\])") .. relativePath
	absolutePath = absolutePath:gsub("\\", "/")
	local parts = {}
    for part in absolutePath:gmatch("[^/]+") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
    return "./" .. table.concat(parts, "/")
end

--- Takes multiple path components as arguments and concatenates them into a single path.
---@param ... string The path components.
---@return string #The resulting path.
local function join (...)
	local separator, paths = "/", { ... }
	for index, path in ipairs(paths) do
		paths[index] = path:gsub("/+$", "")
	end
	return table.concat(paths, separator)
end

--- Extracts the directory part of a path.
---@param path string The path.
---@return string #The directory.
local function getdir (path)
	path = path:gsub("/+$", "")
	local last = path:find("/[^/]*$")
	if last then
		return path:sub(1, last - 1)
	end
	return path:match("^.*[^/]+") or ""
end

--- Returns the filename of a path.
---@param path string The path to use.
---@param name? boolean Return the name only, without the extension.
---@return string #The filename.
local function filename (path, name)
    return path:match("/?([^/]+)" .. (name and "%." or "$"))
end

--- Simple filesystem library.
---@class fslib
return {
	toabsolute = toabsolute,
	join = join,
	getdir = getdir,
	filename = filename
}