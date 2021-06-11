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
  next_placement()
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
  if not board_test({
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,
    mask=K_OBSTRUCTION
  }) then
    return false
  end

  -- check that path would not be interrupted by placing this.
  board_push_temporary_pathable_from_grid(placement.x, placement.y, placement.grid, 1)
  local reachable = svy_goal_reachable()
  board_pop_temporary_pathable()
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
    grid = base.grid
  }
end

function draw_placement()
  love.graphics.setColor(1, 1, 1, 0.8)
  local placement = g_state.placement
  if placement ~= nil and placement.type == "block" then
    local image = g_images.blocks[placement.color]
    if not placement_placable() then
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
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function update_placement(dx, dy, dr)
  if g_state.placement then
    local proposed_placement = table.clone(g_state.placement)
    proposed_placement.x = proposed_placement.x + dx
    proposed_placement.y = proposed_placement.y + dy
    if dr == 1 then
      proposed_placement.grid = rotate_2d_array_cw(proposed_placement.grid)
    end
    if dr == -1 then
      proposed_placement.grid = rotate_2d_array_ccw(proposed_placement.grid)
    end

    g_state.placement = proposed_placement

    if key_pressed("space") then
      if placement_placable() then
        if board_emplace({
            x = g_state.placement.x,
            y = g_state.placement.y,
            grid = g_state.placement.grid,
            cmask = K_OBSTRUCTION,
            wmask = K_WALL_MASK,
            value = g_state.placement.color
          }) then
          next_placement()
        end
      end
    end
  end
end