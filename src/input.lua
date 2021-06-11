local k_controls = {
  "up", "down", "left", "right", "a", "s", "space"
}
local K_IDX_PRESSED = 1
local K_IDX_HELD = 2
local K_IDX_RELEASED = 3

local g_input = {}

function update_input()
  for idx, key in ipairs(k_controls) do
    g_input[key] = g_input[key] or {false, false, false}
    local prev_down = g_input[key][K_IDX_HELD]
    local down = love.keyboard.isDown(key)
    g_input[key][K_IDX_PRESSED] = down and not prev_down
    g_input[key][K_IDX_HELD] = down
    g_input[key][K_IDX_RELEASED] = prev_down and not down
  end
end

function key_held(name)
  return d(g_input[name], {false, false, false})[K_IDX_HELD]
end

function key_pressed(name)
  return d(g_input[name], {false, false, false})[K_IDX_PRESSED]
end

function key_released(name)
  return d(g_input[name], {false, false, false})[K_IDX_RELEASED]
end