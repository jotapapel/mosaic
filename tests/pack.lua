(function (modules)
		local require
		function require (id)
			local fn, mapping = table.unpack(modules[id])
			local module = { exports = {} }
			fn(function (name) return require(mapping[name]) end, module.exports)
			return module.exports
		end
		require(1)
end)({
	{
		-- index.tle
		function (require, exports)
			local __lib_a = require("./lib/a.tle")
			local __lib_b = require("./lib/b.tle")
			print(__lib_a.default)
		end,
		{ ["./tests/lib/b.tle"] = 3, ["./tests/lib/a.tle"] = 2 }
	},
	{
		-- a.tle
		function (require, exports)
			local A = "HELLO WORLD"
			exports.default = A
		end,
		{}
	},
	{
		-- b.tle
		function (require, exports)
			local __a = require("./a.tle")
			local b = __a.default .. "!"
		end,
		{ ["./tests/lib/a.tle"] = 2 }
	}
})