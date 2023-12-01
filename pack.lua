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
			local __graphics = require("./graphics.tle")
			local __font = require("./font.tle")
			function TIC ()
				__graphics.graphics.clear(__graphics.graphics.WHITE)
				__font.font.print("HELLO WORLD!")
			end
		end,
		{ ["./font.tle"] = 3, ["./graphics.tle"] = 2 }
	},
	{
		-- tests/graphics.tle
		function (require, exports)
			local graphics = { WIDTH = 240, HEIGHT = 136, SOLID = "SOLID", BOX = "BOX", BLACK = 0, BRIGHT_BLACK = 1, RED = 2, BRIGHT_RED = 3, GREEN = 4, BRIGHT_GREEN = 5, BLUE = 6, BRIGHT_BLUE = 7, CYAN = 8, BRIGHT_CYAN = 9, YELLOW = 10, BRIGHT_YELLOW = 11, GRAY = 12, BRIGHT_GRAY = 13, WHITE = 14, BRIGHT_WHITE = 15 }
			exports.graphics = graphics
			function graphics.clear (color)
				color = color or 0
				memset(0, (color * (2 ^ 4)) + color, 16320)
			end
			function graphics.border (color)
				poke(16376, color or 0)
			end
			function graphics.pal (oldcolor, newcolor)
				if oldcolor and newcolor then
					poke4(16368 * 2 + oldcolor, newcolor)
					return true
				end
				for index = 0, 15 do
					poke4(16368 * 2 + index, index)
				end
			end
			function graphics.point (x, y, color)
				if color then
					poke4(0 + (y * 240) + x, color)
				end
				return peek4(0 + (y * 240) + x)
			end
			function graphics.line (x0, y0, x1, y1, color)
				local dx, sx = math.abs(x1 - x0), x0 < x1 and 1 or -1
				local dy, sy = -math.abs(y1 - y0), y0 < y1 and 1 or -1
				local err = dx + dy
				while x0 ~= x1 or y0 ~= y1 do
					graphics.point(x0, y0, color)
					local e = err * 2
					if e >= dy then
						err, x0 = err + dy, x0 + sx
					end
					if e <= dx then
						err, y0 = err + dx, y0 + sy
					end
				end
				graphics.point(x1, y1, color)
			end
			function graphics.rectangle (style, x1, y1, x2, y2, color, border)
				color = color or graphics.WHITE
				if style == graphics.BOX then
					for index = 0, border or 1 do
						rectb(x1 + index, y1 + index, x2 - index * 2, y2 - index * 2, color)
					end
					return true
				elseif style == graphics.SOLID then
					rect(x1, y1, x2, y2, color)
					return true
				end
				error("Wrong drawing style", 2)
			end
			function graphics.circle (style, x, y, radius, color, border, adjust)
				local alter = (radius == 4) and 2 or 0
				if style == graphics.BOX then
					local x1, y1, decision = 0, radius, 3 - 2 * radius
					while x1 <= y1 do
						graphics.point(x + x1, y + y1, color)
						graphics.point(x + x1, y - y1, color)
						graphics.point(x - x1, y + y1, color)
						graphics.point(x - x1, y - y1, color)
						graphics.point(x + y1, y + x1, color)
						graphics.point(x + y1, y - x1, color)
						graphics.point(x - y1, y + x1, color)
						graphics.point(x - y1, y - x1, color)
						if decision < 0 then
							decision = decision + (x1 * 4) + 6 + alter - (adjust or 0)
						else
							decision, y1 = decision + 4 * (x1 - y1) + 10, y1 - 1
						end
						x1 = x1 + 1
					end
					if border and border > 1 then
						for index = 1, border do
							graphics.circle(graphics.BOX, x, y, radius + index, color, 1, -8)
							graphics.circle(graphics.BOX, x, y, radius + index, color, 1, -14)
						end
					end
					return true
				elseif style == graphics.SOLID then
					graphics.point(x, y, color)
					for index = radius, 0, -1 do
						graphics.circle(graphics.BOX, x, y, index, color, 1)
						graphics.circle(graphics.BOX, x, y, index, color, 1, -8)
						if index > 1 then
							graphics.point(x - 1, y - 1, color)
							graphics.point(x - 1, y + 1, color)
							graphics.point(x + 1, y - 1, color)
							graphics.point(x + 1, y + 1, color)
						end
					end
					return true
				end
				error("Wrong drawing style", 2)
			end
		end,
		{}
	},
	{
		-- tests/font.tle
		function (require, exports)
			local __graphics = require("./graphics.tle")
			local font = { SIZE = 8, STYLE_PLAIN = { ADDRESS = 32, WIDTH = 5, ADJUST = { [1] = "#%*%?$&%^mw", [-1] = "\"%%%+/<>\\{}", [-2] = "%(%),;%[%]`1jl", [-3] = "!\'%.:|i" } }, STYLE_BOLD = { ADDRESS = 128, WIDTH = 6, ADJUST = { [3] = "mw", [2] = "#", [1] = "%*%?MW^~", [-1] = "%%%+/<>\\{}", [-2] = "%(%)1,;%[%]`jl", [-3] = "!\'%.:|i" } } }
			exports.font = font
			function font.print (text, x, y, color, style)
				local width = 0
				style = style or (type(x) == "table" and x) or self.STYLE_PLAIN
				__graphics.graphics.pal(__graphics.graphics.BRIGHT_WHITE, color or __graphics.graphics.BLACK)
				for index = 1, string.len(text) do
					local char, charw = string.sub(text, index, index), style.WIDTH
					for adjw, adjp in pairs(style.ADJUST) do
						if string.match(char, "[" .. adjp .. "]") then
							charw = charw + adjw
						end
					end
					if string.match(char, "[%d%u]") then
						charw = charw + 1
					elseif string.match(char, "%s") and index > 1 then
						width = width - 1
					end
					if x and y and string.match(char, "%C") then
						spr(style.ADDRESS + string.byte(char) - 32, x + width, y, 0)
					end
					width = width + charw
				end
				__graphics.graphics.pal()
				return width - 1
			end
		end,
		{ ["./graphics.tle"] = 2 }
	}
})