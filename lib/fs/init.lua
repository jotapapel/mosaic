--- Takes a relative path as input and returns the corresponding absolute path.
---@param relative string The relative path.
---@return string #The absolute path.
local function toabsolute (relative)
	local current <close> = io.popen("cd"):read("*n")
	local absolute, parts = string.gsub(current .. "/" .. relative, "\\", "/"), {}
	for part in absolute:gmatch("[^/]+") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, "/")
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

---@class fslib
return {
	toabsolute = toabsolute,
	join = join,
	getdir = getdir
}