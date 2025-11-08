-- gui.lua - lightweight UI hook to toggle NoAnimations mod.
-- This assumes a main menu draw/update hook where we can inject a button.
-- Because Balatro/SMODS internal GUI APIs may vary, we implement a generic Love2D-like overlay.
-- If the game provides a formal UI injection system, adapt this to those callbacks.

local NA = _G.NoAnimations or { enabled = true }

-- Styling constants
local BTN_W, BTN_H = 140, 28
local MARGIN = 12
local font = nil
local hover = false

-- Safe Love2D references (Balatro is LÖVE-based)
local lg = love and love.graphics
local lm = love and love.mouse

local function ensure_font()
	if not lg then return end
	if not font then
		local ok
		ok, font = pcall(function() return lg.newFont(12) end)
		if not ok then font = nil end
	end
end

-- Determine button rectangle in top-right corner
local function button_rect()
	if not lg then return 0,0,0,0 end
	local sw, sh = lg.getWidth(), lg.getHeight()
	local x = sw - BTN_W - MARGIN
	local y = MARGIN
	return x, y, BTN_W, BTN_H
end

local function point_in_rect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Toggle function exposed globally for other potential UI parts
function NA.toggle()
	if NA.set_enabled then
		NA.set_enabled(not NA.enabled)
	else
		NA.enabled = not NA.enabled
	end
end

-- Draw the button; to be called from a menu draw hook (e.g., love.draw or a mod GUI pass)
function NA.draw_toggle_button()
	if not lg then return end
	ensure_font()
	local x, y, w, h = button_rect()
	local label = NA.enabled and 'Animations: ON' or 'Animations: OFF'
	lg.setColor(0,0,0,0.35)
	lg.rectangle('fill', x, y, w, h)
	if hover then
		lg.setColor(0.2,0.85,0.2,0.9)
	else
		lg.setColor(0.8,0.2,0.2,0.9)
	end
	lg.rectangle('line', x, y, w, h)
	if font then lg.setFont(font) end
	lg.setColor(1,1,1,1)
	local text_w = font and font:getWidth(label) or #label * 6
	local text_h = font and font:getHeight() or 12
	lg.print(label, x + (w - text_w)/2, y + (h - text_h)/2)
end

-- Update hover state; call from love.update or menu update hook
function NA.update_toggle_button(dt)
	if not lm then return end
	local mx, my = lm.getPosition()
	local x, y, w, h = button_rect()
	hover = point_in_rect(mx, my, x, y, w, h)
end

-- Mouse pressed handler; integrate with existing love.mousepressed or equivalent
function NA.mousepressed_toggle_button(x, y, button)
	if button ~= 1 then return end
	local bx, by, bw, bh = button_rect()
	if point_in_rect(x, y, bx, by, bw, bh) then
		NA.toggle()
		return true -- consumed
	end
end

-- For environments where we can directly patch love callbacks, do guarded hookup.
if love then
	-- Wrap existing love.draw
	local original_draw = love.draw
	love.draw = function(...)
		if original_draw then original_draw(...) end
		-- Only show on main menu if we can detect it; otherwise always show for now.
		NA.draw_toggle_button()
	end

	local original_update = love.update
	love.update = function(dt, ...)
		if original_update then original_update(dt, ...) end
		NA.update_toggle_button(dt)
	end

	local original_mousepressed = love.mousepressed
	love.mousepressed = function(x, y, button, ...)
		local consumed = NA.mousepressed_toggle_button(x, y, button)
		if (not consumed) and original_mousepressed then original_mousepressed(x, y, button, ...) end
	end
end

return NA
