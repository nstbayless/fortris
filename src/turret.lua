-- checks for turret placability
K_TURRET_GRID = {}
K_TURRET_GRID[2] = make_2d_array(2, 2, 1)
K_TURRET_GRID[3] = make_2d_array(3, 3, 1)
K_TURRET_GRID[4] = make_2d_array(4, 4, 1)

-- see what turrets can fit anywhere including the given grid coordinates.
function turret_get_potentials_at_grid(x, y, grid, dx, dy)
  local a = {}
  dx = dx or 1
  dy = dy or 1
  local used = {}
  for size = 4,2,-1 do -- try largest sizes first
    for yo, xo, v in array_2d_iterate(grid, 0) do
      local p = turret_get_potential_at(x + xo, y + yo, size, dx, dy, used)
      if p then
        table.insert(a, p)
        -- mark as used temporarily
        for yu = p.y,p.y + p.size-1 do
          if not used[yu] then
            used[yu] = {}
          end
          for xu = p.x,p.x + p.size-1 do
            used[yu][xu] = true
          end
        end
      end
    end
  end
  return a
end

function turret_location_in_use(x, y, w, h, used)
  assert(used)
  for yu = y,y+h-1 do
    for xu = x,x+w-1 do
      if used[yu] and used[yu][xu] then
        return true
      end
    end
  end
  return false
end

function turret_get_potential_at(x, y, size, dx, dy, used)
  -- optimization / early out
  if turret_location_in_use(x, y, 1, 1, used) then
    return nil
  end

  -- check each possible offset
  for offx in ordered_range(0, -size + 1, dx) do
    for offy in ordered_range(0, -size + 1, dy) do
      -- check that the space is completely covered in wall,
      -- and yet there are no statics there.
      if not turret_location_in_use(x + offx, y + offy, size, size, used) then
        if board_test_collides({
          x = x + offx,
          y = y + offy,
          grid = K_TURRET_GRID[size],
          all = true,
          mask = K_WALL_MASK
        }) and static_test_emplace({
          x = x + offx,
          y = y + offy,
          w = size,
          h = size,
          --grid = K_TURRET_GRID[size]
        }) then
          return {
            x = x + offx,
            y = y + offy,
            size = size
          }
        end
      end
    end
  end

  return nil
end

function turret_emplace_potentials_at_grid(x, y, grid, dx, dy)
  local potentials = turret_get_potentials_at_grid(x, y, grid, dx, dy)
  for potential in entries(potentials) do
    assert(potential.x and potential.y and potential.size)
    local sprite = g_images.turret_base
    if potential.size == 3 then
      sprite = g_images.artillery
    end
    static_emplace({
      x = potential.x,
      y = potential.y,
      w = potential.size,
      h = potential.size,
      collision_flags = K_STATIC,
      sprites = {{
        sprite = sprite,
        sprite_offx = k_dim_x * potential.size / 2,
        sprite_offy = k_dim_y * potential.size / 2,
      }}
    })
  end
end