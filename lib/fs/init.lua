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

local function join (...)
	local separator, paths = "/", { ... }
	for index, path in ipairs(paths) do
		paths[index] = path:gsub("/+$", "")
	end
	return table.concat(paths, separator)
end

local function getdir (path)
	path = path:gsub("/+$", "")
	local last = path:find("/[^/]*$")
	if last then
		return path:sub(1, last - 1)
	end
	return path:match("^.*[^/]+") or ""
end

return {
	toabsolute = toabsolute,
	join = join,
	getdir = getdir
}