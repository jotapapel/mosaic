local A = (function ()
	local A = {}
	A.__index = A
	A.__call = function (A)
		return setmetatable({}, A)
	end
	setmetatable({}, A)
	return A
end)()