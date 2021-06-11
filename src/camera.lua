function camera_init()
  -- camera expressed in grid dimensions
  local w,h = love.graphics.getDimensions()
  g_state.camera = {
    x=0,
    y=0,
    w=w / k_dim_x,
    h=h / k_dim_y
  }
end

function camera_update()
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
end

function camera_apply_transform()
  love.graphics.translate(-g_state.camera.x * k_dim_x, -g_state.camera.y * k_dim_y)
end