local k_controls = {
  up = {
    keyboard = {"up"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_UP
    }
  },
  down = {
    keyboard = {"down"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_DOWN
    }
  },
  left = {
    keyboard = {"left"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_LEFT
    }
  },
  right = {
    keyboard = {"right"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_RIGHT
    }
  },
  rotccw = {
    keyboard = {"a"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_B,
      RETRO_DEVICE_ID_JOYPAD_R,
      RETRO_DEVICE_ID_JOYPAD_R2,
    }
  },
  rotcw = {
    keyboard = {"s"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_A,
      RETRO_DEVICE_ID_JOYPAD_L,
      RETRO_DEVICE_ID_JOYPAD_L2,
    }
  },
  place = {
    keyboard = {"space", "return"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_Y
    }
  },
  pause = {
    keyboard = {"p", "escape"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_START
    }
  },
  swap = {
    keyboard = {"t", "tab"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_SELECT
    }
  },
  save_demo = {
    keyboard = {"i"},
    lutro_joypad = {
      RETRO_DEVICE_ID_JOYPAD_R3
    }
  }
}
local K_IDX_PRESSED = 1
local K_IDX_HELD = 2
local K_IDX_RELEASED = 3
local K_IDX_PRESSED_REPEAT = 4

local g_input = {}
-- allows slightly snappier key detection when lagging
local g_pre_input = {}

function input_init()
  g_input = {}
  g_pre_input = {}
  g_input_state = {
    dx = 0,
    dy = 0,
    dr = 0
  }
end

if g_is_lutro then

  -- lutro controls
  function input_poll_key(keydata)
    for _, jp_button in ipairs(keydata.lutro_joypad) do
      if love.joystick.isDown(1, jp_button) then
        return true
      end
    end
    return false
  end

else

  -- love2d controls
  function input_poll_key(keydata)
    for _, key in ipairs(keydata.keyboard) do
      if g_pre_input[key] and g_pre_input[key].pressed then
        g_pre_input[key] = {}
        return true
      elseif g_pre_input[key] and g_pre_input[key].released then
        g_pre_input[key] = {}
        return false
      else
        if love.keyboard.isDown(key) then
          return true
        end
      end
    end
    return false
  end

  function love.keypressed( key, scancode, isrepeat )
    if not isrepeat then
      g_pre_input[key] = g_pre_input[key] or {}
      g_pre_input[key].pressed = true
    end
  end

  function love.keyreleased( key, scancode )
    g_pre_input[key] = g_pre_input[key] or {}
    g_pre_input[key].released = true
  end
end

function update_input(dt)
  -- update each key.
  for key, keydata in pairs(k_controls) do
    g_input[key] = g_input[key] or {false, false, false, false, false}
    local prev_down = g_input[key][K_IDX_HELD]

    -- is key currently considered to be held?
    -- ('release' and 'pressed' are calculated from this.
    local down = demo_is_playback() and
      demo_getv("keydown_" .. key) or
      (g_test_mode and test_get_key_down(key) or input_poll_key(keydata))
    if demo_is_recording() then
      demo_setv("keydown_" .. key, down)
    end

    -- update pressed, held, released etc. based on this.
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
  g_input_state.dr = ibool(key_pressed("rotcw")) - ibool(key_pressed("rotccw"))
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