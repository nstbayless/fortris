local k_controls = {
  "up", "down", "left", "right", "a", "s", "space", "return", "p", "escape", "t", "tab"
}
local K_IDX_PRESSED = 1
local K_IDX_HELD = 2
local K_IDX_RELEASED = 3
K_IDX_PRESSED_REPEAT = 4

local g_input = {}

function input_init()
  g_input = {}
  g_input_state = {
    dx = 0,
    dy = 0,
    dr = 0
  }
end

function update_input(dt)
  -- update each key.
  for idx, key in ipairs(k_controls) do
    g_input[key] = g_input[key] or {false, false, false}
    local prev_down = g_input[key][K_IDX_HELD]
    local down = love.keyboard.isDown(key)
    if g_test_mode then
      down = test_get_key_down(key)
    end
    g_input[key][K_IDX_PRESSED] = down and not prev_down
    g_input[key][K_IDX_HELD] = down
    g_input[key][K_IDX_RELEASED] = prev_down and not down
    g_input[key].hold_time = (not down or not g_input[key].hold_time) and 0 or (g_input[key].hold_time + dt)
    if g_input[key].hold_time > k_hold_repeat_input_initial then
      g_input[key].hold_time = g_input[key].hold_time - k_hold_repeat_input_repeat
      g_input[key][K_IDX_PRESSED_REPEAT] = true
    else
      g_input[key][K_IDX_PRESSED_REPEAT] = g_input[key][K_IDX_PRESSED]
    end

    -- prevent undesirable behaviour where game starts with a key pressed.
    -- note that this allows for a key to be held at the start but never 'pressed'
    -- (watch for rolling rocks......)
    if g_state.time - dt < 0.1 then
      g_input[key][K_IDX_PRESSED] = false
      g_input[key][K_IDX_PRESSED_REPEAT] = false
    end
  end

  g_input_state.dx = ibool(key_pressed("right", true)) - ibool(key_pressed("left", true))
  g_input_state.dy = ibool(key_pressed("down", true)) - ibool(key_pressed("up", true))
  g_input_state.dr = ibool(key_pressed("s")) - ibool(key_pressed("a"))
end

function key_held(name)
  return d(g_input[name], {false, false, false})[K_IDX_HELD]
end

function key_pressed(name, rept)
  if rept and g_hold_repeat_input then
    return d(g_input[name], {false, false, false})[K_IDX_PRESSED_REPEAT]
  else
    return d(g_input[name], {false, false, false})[K_IDX_PRESSED]
  end
end

function key_released(name)
  return d(g_input[name], {false, false, false})[K_IDX_RELEASED]
end