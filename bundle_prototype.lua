(function (modules)
	local process
	function process (id)
		local fn, mapping = table.unpack(modules[id])
		local module = { exports = {} }
		fn(function (name) return process(mapping[name]) end, module, module.exports)
		return module.exports
	end
	process(1)
end)({
	{
		-- index.lua
		function (process, module, exports)
			local _lib = process("lib.lua")
			local _lib2 = (_lib and _lib.__module) and _lib or { default = _lib }
			local testElement = _lib2.default("Joe")
			testElement:greet()
		end,
		{ ["lib.lua"] = 2 }
	},
	{
		-- lib.lua
		function (process, module, exports)
			rawset(exports, "__module", true)
			local prototype = (function ()
				local prototype = setmetatable({}, {
					__call = function(prototype, name)
						local self = setmetatable({}, { __index = prototype })
						self.name = "Hello, " .. name .. "."
						return self
					end
				})
				function prototype.greet(self)
					print(self.name)
				end
				return prototype
			end)()
			exports.default = prototype
		end,
		{}
	}
})