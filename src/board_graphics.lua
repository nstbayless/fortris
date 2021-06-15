-- manages drawing board tiles which are dependent on their surroundings (like walls or fog of war)

local g_bgfx = {}

function bgfx_init()
  -- list of cfg graphics
  g_bgfx = {}
  board_observe(bgfx_on_board_update)

  bgfx_add("wall", {
    sprite = g_images.wall,
    cmask = bit.bor(K_WALL_MASK, K_NO_SHADOWS),
    mask = K_WALL_MASK,
    edges_are_walls = false,
    shadows = true
  })
  bgfx_add("fog", {
    sprite = g_images.fog_of_war,
    mask = K_FOG_OF_WAR,
    edges_are_walls = true,
  })
end

function bgfx_add(id, opts)
  opts.sprite_batch = love.graphics.newSpriteBatch(opts.sprite.spriteSheet, bgfx_get_sprite_batch_sprite_count())
  opts.cmask = opts.cmask or opts.mask
  opts.indices = {}
  g_bgfx[id] = opts
  bgfx_refesh(g_bgfx[id])
end

function bgfx_get_sprite_batch_idx(x, y)
  local board = g_state.board
  -- max is for paranoia.
  -- unsure why adding 1 is necessary but it seems to be extremely important.
  return math.max(0, 4 * (x - board.left + (y - board.top) * board_width())) + 1
end

function bgfx_get_sprite_batch_sprite_count()
  return 4 * board_width() * board_height() + 1
end

function bgfx_refresh_tile(bgfx, x, y)
  -- (pass-by-reference idx into function to allow updating it.)
  local idx = {bgfx_get_sprite_batch_idx(x, y)}
  for i = idx[1],idx[1]+3 do
    sprite_batch_remove(bgfx.sprite_batch, i)
  end
  wall_draw_at(x, y, bgfx.sprite_batch, bgfx.mask, bgfx.edges_are_walls, bgfx.shadows,
    function(sb, ...)
      local t = {...}
      if bgfx.indices[idx[1]] == nil then
        local i = sprite_batch_add_sprite(sb, bgfx.sprite, unpack(t))
        if i then
          bgfx.indices[idx[1]] = i
        end
      else
        -- sprite_batch_set_sprite(sb, bgfx.indices[idx[1]], bgfx.sprite, unpack(t))
        sprite_batch_remove(sb, bgfx.indices[idx[1]])
      end
      idx[1] = idx[1] + 1
    end
  )
end

function bgfx_refesh(bgfx)
  bgfx.sprite_batch:clear()
  bgfx.indices = {}
  for y, x in board_iterate() do
    bgfx_refresh_tile(bgfx, x, y)
  end
end

function bgfx_on_board_update(event)
  for key, bgfx in pairs(g_bgfx) do
    -- refresh the given tile.
    if event.etype == K_BOARD_EVENT_SET and not event.during_board_resize then
      if bit.band(event.mask, bgfx.cmask) ~= 0 then
        for yo, xo, v in array_2d_iterate(event.grid, 0) do
          if v ~= 0 then
            local x = xo + event.x
            local y = yo + event.y
            bgfx_refresh_tile(bgfx, x, y)
          end
        end
      end

      bgfx_refesh(bgfx)
    end

    -- full refresh
    if event.etype == K_BOARD_EVENT_RESIZE_END then
      bgfx_refesh(bgfx)
    end
  end
end


-- wall image indices
K_WALL_INNER_CORNER = {
  {17, 16}, {13, 12}
}

K_WALL_OUTER_CORNER = {
  {0, 2}, {8, 10}
}

K_WALL_HORIZONTAL = {
  1, 9
}

K_WALL_VERTICAL = {
  4, 6
}

K_SHADOW = {
  nil, 20, 21, 26,
  23, 24, 22, 25,
}

-- returns one of four corner tiles for the wall at the given idx
function wall_get_subtile(base_x, base_y, dx, dy, mask, edges_are_walls, shadows)
  assert(dx and dy and dx ~= 0 and dy ~= 0)
  local wall_at = {}
  
  -- check 2x2 square to see what walls are there.
  for y in ordered_range(base_y, base_y + dy) do
    wall_at[y] = {}
    for x in ordered_range(base_x, base_x + dx) do
      wall_at[y][x] = bit.band(d(board_get_value(x, y, edges_are_walls and mask or 0), 0), mask) ~= 0
    end
  end

  -- indices for selecting subimages from lists
  local imgx = tern(dx > 0, 2, 1)
  local imgy = tern(dy > 0, 2, 1)

  -- if base position has no wall, then there is no wall.
  if not wall_at[base_y][base_x] then
    -- check for shadows
    if not shadows then
      return nil
    end

    if dx == 1 and dy == 1 then
      -- bottom-right corner never has shadows.
      return nil
    end
    -- no wall, but possibly shadows
    local left = dx == -1 and wall_at[base_y][base_x + dx]
    local top = dy == -1 and wall_at[base_y + dy][base_x]
    local diagonal = (dx == -1 and dy == -1 and wall_at[base_y + dy][base_x + dx]) or (dx == 1 and dy == -1 and top) or (dy == 1 and dx == -1 and left)

    return K_SHADOW[tern(left, 1, 0) + tern(top, 2, 0) + tern(diagonal, 4, 0) + 1]
  else
    -- full region or inner corner
    if wall_at[base_y + dy][base_x] and wall_at[base_y][base_x + dx] then
      if wall_at[base_y + dy][base_x + dx] then
        -- full
        return 5
      else
        return K_WALL_INNER_CORNER[imgy][imgx]
      end
    end

    -- horizontal wall
    if wall_at[base_y][base_x + dx] and not wall_at[base_y + dy][base_x] then
      return K_WALL_HORIZONTAL[imgy]
    end

    -- vertical  wall
    if wall_at[base_y + dy][base_x] and not wall_at[base_y][base_x + dx] then
      return K_WALL_VERTICAL[imgx]
    end

    -- outer corner
    if not wall_at[base_y + dy][base_x] and not wall_at[base_y][base_x + dx] then
      return K_WALL_OUTER_CORNER[imgy][imgx]
    end
  end
end

function wall_draw_at(x, y, sprite, mask, edges_are_walls, shadows, fn)
  fn = fn or draw_sprite
  for dy = -1,1 do
    for dx = -1,1 do
      if dx ~= 0 and dy ~= 0 then
        local wall_subtile = wall_get_subtile(x, y, dx, dy, mask or K_WALL_MASK, edges_are_walls or false, shadows or false)
        if wall_subtile then
          fn(sprite or g_images.wall, wall_subtile,
            (x + 0.25 + 0.25 * dx) * k_dim_x,
            (y + 0.25 + 0.25 * dy) * k_dim_y
          )
        end
      end
    end
  end
end

-- draws terrain features / walls
function board_draw()
  -- bgfx_refesh(g_bgfx["wall"])
  love.graphics.draw(g_bgfx["wall"].sprite_batch)
  --[[ for y, x, v in board_iterate(g_state.board) do
    if bit.band(v, K_WALL_MASK) ~= 0 or bit.band(v, K_NO_SHADOWS) == 0 then
      wall_draw_at(x, y, g_images.wall)
    end
  end --]]
end

function board_draw_fog()
  -- bgfx_refesh(g_bgfx["fog"])
  love.graphics.draw(g_bgfx["fog"].sprite_batch)
  --[[
  for y, x, v in board_iterate(g_state.board) do
    if bit.band(v, K_FOG_OF_WAR) ~= 0 then
      wall_draw_at(x, y, g_images.fog_of_war, K_FOG_OF_WAR, true)
    end
  end --]]
end