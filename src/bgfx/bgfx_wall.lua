-- wall image indices
local K_WALL_INNER_CORNER = {
  {17, 16}, {13, 12}
}

local K_WALL_OUTER_CORNER = {
  {0, 2}, {8, 10}
}

local K_WALL_HORIZONTAL = {
  1, 9
}

local K_WALL_VERTICAL = {
  4, 6
}

local K_SHADOW = {
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
