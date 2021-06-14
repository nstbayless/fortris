function camera_init()
  -- camera expressed in grid dimensions
  local w,h = love.graphics.getDimensions()
  g_state.camera = {
    x=0,
    y=0,
    w=w / k_dim_x,
    h=h / k_dim_y,
    shake_x = 0,
    shake_y = 0,
    shake_timer = 0
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

function camera_apply_transform()
  local offx, offy = 0, 0
  local camera = g_state.camera
  if camera.shake_timer > 0 then
    offx = offx + math.frandom(-camera.shake_x, camera.shake_x)
    offy = offy + math.frandom(-camera.shake_y, camera.shake_y)
  end
  love.graphics.translate(math.round(-camera.x * k_dim_x + offx), math.round(-camera.y * k_dim_y + offy))
end