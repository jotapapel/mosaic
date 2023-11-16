--[[
"use strict";
var myClass = (function () {
	function myClass(x, y) {
		this.x = 0;
		this.y = 0;
		this.x = x, this.y = y;
	}
	myClass.prototype.locate = function () {
		console.log(this.x, this.y);
	};
	return myClass;
}());
--]]
local myClass = (function ()
	local myClass = setmetatable({}, {
		__call = function (myClass, x, y)
			local self = setmetatable({}, { __index = myClass })
			self.x, self.y = x, y
			return self
		end
	})
	myClass.locate = function (self)
		print(self.x, self.y)
	end
	return myClass
end)()
local mySecondClass = (function (myClass)
	local mySecondClass = setmetatable({}, {
		__index = myClass,
		__call = function (mySecondClass, x, z)
			local self = setmetatable(myClass(x, 0), { __index = mySecondClass })
			self.z = z
			return self
		end
	})
	mySecondClass.locate = function (self)
		myClass.locate(self)
		print("(location)")
	end
	return mySecondClass
end)(myClass)
local s = mySecondClass(32, "X")
s:locate()
