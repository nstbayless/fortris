-- allows lutro compatability
function love.graphics.getDPIScale() end

function love.graphics.getDimensions()
  return love.graphics.getWidth(), love.graphics.getHeight()
end

RETRO_DEVICE_ID_JOYPAD_B        = 1
RETRO_DEVICE_ID_JOYPAD_Y        = 2
RETRO_DEVICE_ID_JOYPAD_SELECT   = 3
RETRO_DEVICE_ID_JOYPAD_START    = 4
RETRO_DEVICE_ID_JOYPAD_UP       = 5
RETRO_DEVICE_ID_JOYPAD_DOWN     = 6
RETRO_DEVICE_ID_JOYPAD_LEFT     = 7
RETRO_DEVICE_ID_JOYPAD_RIGHT    = 8
RETRO_DEVICE_ID_JOYPAD_A        = 9
RETRO_DEVICE_ID_JOYPAD_X        = 10
RETRO_DEVICE_ID_JOYPAD_L        = 11
RETRO_DEVICE_ID_JOYPAD_R        = 12
RETRO_DEVICE_ID_JOYPAD_L2       = 13
RETRO_DEVICE_ID_JOYPAD_R2       = 14
RETRO_DEVICE_ID_JOYPAD_L3       = 15
RETRO_DEVICE_ID_JOYPAD_R3       = 16

-- converts floats in the range 0-1 to unsigned bytes in the range 0-255
local function xff(...)
  local t = {...}
  for i, v in ipairs(t) do
    t[i] = v * 255
  end
  return unpack(t)
end

local setColor = love.graphics.setColor
local setBackgroundColor = love.graphics.setBackgroundColor

love.graphics.setColor = function(...) return setColor(xff(...)) end
love.graphics.setBackgroundColor = function(...) return setBackgroundColor(xff(...)) end