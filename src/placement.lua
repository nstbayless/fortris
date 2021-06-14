local K_PLACEMENTS = {
  -- T
  {
    color = "purple",
    grid = {
      {0, 1, 0},
      {1, 1, 1},
      {0, 0, 0}
    }
  },

  -- O
  {
    color = "yellow",
    grid = {
      {1, 1},
      {1, 1},
    }
  },

  -- L
  {
    color = "orange",
    grid = {
      {0, 0, 1},
      {1, 1, 1},
      {0, 0, 0}
    }
  },

  -- J
  {
    color = "blue",
    grid = {
      {1, 0, 0},
      {1, 1, 1},
      {0, 0, 0},
    }
  },

  -- S
  {
    color = "green",
    grid = {
      {0, 1, 1},
      {1, 1, 0},
    }
  },

  -- Z
  {
    color = "red",
    grid = {
      {1, 1, 0},
      {0, 1, 1},
    }
  },

  -- I
  {
    color = "lightblue",
    grid = {
      {0, 0, 0, 0},
      {1, 1, 1, 1},
      {0, 0, 0, 0},
    }
  },
}

function init_placement()
  g_state.placement_idx = 6
  g_state.placement_cache = {
    dirty = true,
    placable = false,
    turret_potentials = {}
  }
  next_placement()

  board_observe(
    function() 
      g_state.placement_cache.dirty = true
    end
  )
end

-- returns height, width of placement
function placement_dimensions()
  local placement = g_state.placement
  if placement == nil then
    return 0, 0
  end
  if placement.grid ~= nil then
    return dimensions2d(placement.grid)
  end
  return 0, 0
end

function placement_width()
  local h, w = placement_dimensions()
  return w
end

function placement_height()
  local h, w = placement_dimensions()
  return h
end

-- returns true if current placement could be validly emplaced at its current location.
function placement_placable()
  local placement = g_state.placement

  -- check for direct collision with any other obstruction
  if not board_test_free({
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,
    mask=K_OBSTRUCTION
  }) then
    return false
  end

  -- check that path would not be interrupted by placing this.
  board_push_temporary_change_from_grid(placement.x, placement.y, placement.grid, K_OBSTRUCTION)
  local reachable = svy_goal_reachable()
  board_pop_temporary_change()
  return reachable
end

function next_placement()
  local idx = g_state.placement_idx
  local base = K_PLACEMENTS[(idx % #K_PLACEMENTS) + 1]
  assert(base)
  assert(base.grid ~= nil)
  local default_x, default_y = 14, 8
  g_state.placement_idx = idx + 1
  local x = default_x
  local y = default_y
  if g_state.placement then
    x = g_state.placement.x + placement_width() / 2
    y = g_state.placement.y + placement_height() / 2
  end
  g_state.placement = {
    type = "block",
    x = math.floor(x - width2d(base.grid) / 2),
    y = math.floor(y - height2d(base.grid) / 2),
    color = indexof(k_block_colors, base.color),
    grid = base.grid,

    -- direction turrets will be laid / 'facing'
    dx = 1,
    dy = 1
  }
  g_state.placement_cache.dirty = true
end

-- returns cache; refreshes cache if necessary
function placement_get_cache()
  local cache = g_state.placement_cache
  local placement = g_state.placement
  if cache.dirty then
    cache.dirty = false
    cache.placable = placement_placable()
    if cache.placable then
      board_push_temporary_change_from_grid(placement.x, placement.y, placement.grid, K_OBSTRUCTION)
      cache.turret_potentials = turret_get_potentials_at_grid(
        placement.x, placement.y, placement.grid, placement.dx, placement.dy
      )
      board_pop_temporary_change()
    else
      cache.turret_potentials = {}
    end
  end
  return cache
end

function draw_placement()
  love.graphics.setColor(1, 1, 1, 0.8)
  local cache = placement_get_cache()
  local placement = g_state.placement
  if placement ~= nil and placement.type == "block" then
    local image = g_images.blocks[placement.color]
    if not cache.placable then
      image = g_images.blocks.red2
      love.graphics.setColor(1, 1, 1, 0.5)
    end
    for y, row in ipairs(g_state.placement.grid) do
      for x, e in ipairs(row) do
        if e == 1 then
          local world_pos_x = x + placement.x - 1
          local world_pos_y = y + placement.y - 1
          draw_image_on_grid(image, world_pos_x, world_pos_y)
        end
      end
    end

    -- turrets
    if cache.placable then
      love.graphics.setColor(1, 1, 1, 0.3 + 0.2 * (math.floor(g_state.time * 10) % 2))
      for idx, turret in pairs(cache.turret_potentials) do
        local margin = 8
        love.graphics.rectangle("fill", turret.x * k_dim_x + margin, turret.y * k_dim_y + margin, turret.w * k_dim_x - 2 * margin, turret.h * k_dim_y - 2 * margin)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function placement_emplace()
  local placement = g_state.placement
  local success = board_emplace({
    x = placement.x,
    y = placement.y,
    grid = placement.grid,
    cmask = K_OBSTRUCTION,
    wmask = K_WALL_MASK,
    value = placement.color
  })
  assert(success)

  turret_emplace_potentials_at_grid(placement.x, placement.y, placement.grid, placement.dx, placement.dy)

  next_placement()
end

function update_placement(dx, dy, dr)
  if g_state.placement then
    local proposed_placement = table.clone(g_state.placement)

    -- translate
    proposed_placement.x = proposed_placement.x + dx
    proposed_placement.y = proposed_placement.y + dy

    -- rotate
    if dr == 1 then
      proposed_placement.grid = rotate_2d_array_cw(proposed_placement.grid)
      proposed_placement.dx, proposed_placement.dy = proposed_placement.dy, -proposed_placement.dx
    end
    if dr == -1 then
      proposed_placement.grid = rotate_2d_array_ccw(proposed_placement.grid)
      proposed_placement.dx, proposed_placement.dy = -proposed_placement.dy, proposed_placement.dx
    end

    -- update placement only if any actual change was made.
    if dr ~= 0 or dx ~= 0 or dy ~= 0 then
      g_state.placement = proposed_placement
      g_state.placement_cache.dirty = true
    end

    if key_pressed("space") then
      if placement_placable() then
        placement_emplace()
      end
    end
  end
end