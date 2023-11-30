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
	-- tests/index.tle
	function (require, exports)
			local __lib = require("./lib.tle")
			local __another = require("./another.tle")
			print(__lib.a, __another.b)
	end,
	{ ["./another.tle"] = 3, ["./lib.tle"] = 2 }
},
{
	-- tests/lib.tle
	function (require, exports)
			local a = false
			exports.a = a
			local b = 32
			exports.b = b
	end,
	{}
},
{
	-- tests/another.tle
	function (require, exports)
			-- this is another module
			local __lib = require("./lib.tle")
			local b = __lib.c
			exports.b = b
	end,
	{ ["./lib.tle"] = 4 }
},
{
	-- tests/lib.tle
	function (require, exports)
			local a = false
			exports.a = a
			local b = 32
			exports.b = b
	end,
	{}
}
})