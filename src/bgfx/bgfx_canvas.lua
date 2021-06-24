function bgfx_add(id, opts)
  opts.canvas = nil
  opts.layer = opts.layer or BGFX_LAYER.base
  opts.w, opts.h = nil, nil
  g_bgfx[id] = opts
  bgfx_refresh(g_bgfx[id])
end

function bgfx_refresh_tile(bgfx, x, y)

  -- draw to tile layer canvas
  local already_in_canvas = love.graphics.getCanvas() == bgfx.canvas
  if not already_in_canvas then
    love.graphics.setCanvas(bgfx.canvas)
  end
  
  -- restrict to drawing only in this tile
  love.graphics.setScissor(
    k_dim_x * (x - g_state.board.left),
    k_dim_y * (y - g_state.board.top),
    k_dim_x, k_dim_y
  )

  -- clear this tile
  love.graphics.setBackgroundColor(0, 0, 0, 0)
  love.graphics.clear()

  -- render tile
  local bg_tile_fn = tern(bgfx.subdivided, bgfx_draw_subdivided_at, bgfx_draw_at)
  bg_tile_fn(x, y, bgfx.canvas, bgfx.subtile_fn or wall_get_subtile,
    function(canvas, subimage, px, py)
      -- convert to canvas coordinates
      px = px - k_dim_x * g_state.board.left
      py = py - k_dim_y * g_state.board.top

      draw_sprite(bgfx.sprite, subimage, px, py)
    end
  )

  love.graphics.setScissor()
  if not already_in_canvas then
    love.graphics.setCanvas()
  end
end

function bgfx_draw_feature(layer)
  if layer then
    love.graphics.draw(layer.canvas, g_state.board.left * k_dim_x, g_state.board.top * k_dim_y)
  end
end

function bgfx_refresh(bgfx)
  -- resize (optional)
  if bgfx.w ~= board_width() or bgfx.h ~= board_height() then
    bgfx.w = board_width()
    bgfx.h = board_height()
    bgfx.canvas = love.graphics.newCanvas(k_dim_x * bgfx.w, k_dim_y * bgfx.h)
  end

  -- lutro cannot update all the tiles in one frame; it's too slow.
  --if g_is_lutro and g_state.time < 0.2 then return end

  love.graphics.setCanvas(bgfx.canvas)

  for y, x in board_iterate() do
    bgfx_refresh_tile(bgfx, x, y)
  end
  love.graphics.setCanvas()
end