(function (modules)
	local require
	function require (id)
		local sourceFunc, mapping = table.unpack(modules[id])
		local module = { exports = {} }
		sourceFunc(function (name) return require(mapping[name]) end, module, module.exports)
		return module.exports
	end
	require(1)
end)({
	{
		-- index.lua
		function (require, module, exports)
			local _lib = require("lib.lua")
			local a, b = _lib.a, _lib.b
			print(a, b)
		end,
		{ ["lib.lua"] = 2 }
	},
	{
		-- lib.lua
		function (require, module, exports)
			rawset(exports, "__module", true)
			exports.a, exports.b = 33, false
		end,
		{}
	}
})