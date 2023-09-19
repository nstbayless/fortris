function camera_init()
  -- camera expressed in grid dimensions
  local w,h = love.graphics.getDimensions()
  g_state.camera = {
    x=g_state.initial_board_width / 2 - w / k_dim_x / 2,
    y=g_state.initial_board_height / 2 - h / k_dim_y / 2,
    w=w / k_dim_x,
    h=h / k_dim_y,
    shake_x = 0,
    shake_y = 0,
    shake_timer = 0,
    -- used for special offscreen-buffer drawing sections of code.
    tmp_canvas = love.graphics.newCanvas(100, 100),
  }
end

function camera_apply_shake(time, amountx, amounty)
  local camera = g_state.camera

  -- TODO: stackable shaking
  camera.shake_timer = time
  camera.shake_x = amountx or 1
  camera.shake_y = amounty or amountx or 1
end

function camera_update(dt)
  local camera = g_state.camera
  local board = g_state.board

  -- update dimensions
  local w, h = love.graphics.getDimensions()
  if w ~= camera.tmp_canvas:getWidth() or h ~= camera.tmp_canvas:getHeight() then
    camera.tmp_canvas = love.graphics.newCanvas(w, h)
  end
  camera.w = w / k_dim_x
  camera.h = h / k_dim_y

  -- clamp
  if (board.right - board.left) <= camera.w then
    camera.x = (board.left + board.right) / 2 - camera.w / 2
  else
    camera.x = math.clamp(camera.x, board.left, board.right - camera.w)
  end
  if (board.bottom - board.top) <= camera.h then
    camera.y = (board.top + board.bottom) / 2 - camera.h / 2
  else
    camera.y = math.clamp(camera.y, board.top, board.bottom - camera.h)
  end

  -- shake
  if camera.shake_timer > 0 then
    camera.shake_timer = camera.shake_timer - dt
  end
end

function camera_get_scroll()
  local offx, offy = 0, 0
  local camera = g_state.camera
  local game_over_shake_multiplier = math.clamp(1 - g_state.game_over_timer / 2, 0, 1)
  if camera.shake_timer > 0 and game_over_shake_multiplier > 0 then
    offx = offx + math.frandom(-camera.shake_x, camera.shake_x) * game_over_shake_multiplier
    offy = offy + math.frandom(-camera.shake_y, camera.shake_y) * game_over_shake_multiplier
  end
  
  return math.round(-camera.x * k_dim_x + offx), math.round(- camera.y * k_dim_y + offy)
end

function camera_apply_transform()
  local x, y = camera_get_scroll()
  love.graphics.translate(x, y)
end

function camera_update_temporary_canvas()
  love.graphics.getDimensions()
end

function camera_begin_temporary_canvas()
  local camera = g_state.camera
  love.graphics.push()
  love.graphics.origin()
  love.graphics.setCanvas(camera.tmp_canvas)
  love.graphics.push()
  camera_apply_transform()
  love.graphics.clear()
end

function camera_commit_temporary_canvas()
  local camera = g_state.camera
  
  love.graphics.pop()
  love.graphics.setCanvas()
  love.graphics.draw(camera.tmp_canvas, 0, 0)
  love.graphics.pop()
end