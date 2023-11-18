local graphics = { WIDTH = 240, HEIGHT = 136, SOLID = "SOLID", BOX = "BOX", BLACK = 0, BRIGHT_BLACK = 1, RED = 2, BRIGHT_RED = 3, GREEN = 4, BRIGHT_GREEN = 5, BLUE = 6, BRIGHT_BLUE = 7, CYAN = 8, BRIGHT_CYAN = 9, YELLOW = 10, BRIGHT_YELLOW = 11, GRAY = 12, BRIGHT_GRAY = 13, WHITE = 14, BRIGHT_WHITE = 15 }
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
function TIC ()
	graphics.clear(graphics.RED)
	graphics.circle(graphics.BOX, 32, 32, 16, graphics.BRIGHT_RED)
end
-- <PALETTE>
-- 000:000000333333881818e917171e821e3bdd3c1f1f7f3937e51862885db5e3ad9114e3e41c666666999999ccccccffffff
-- </PALETTE>