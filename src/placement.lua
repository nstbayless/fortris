K_PLACEMENT_COST = 10

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
    color = "pink",
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
  g_state.placement_idx = nil
  g_state.placement_permutation = {}
  g_state.placement_count = -1
  g_state.placement_rotation_count = 0
  g_state.placement_cache = {
    dirty = true,
    show_message_timer = 0,
    placable = false,
    implacable_reason = 1,
    turret_potentials = {},
    confirm = false
  }
  next_placement(true)

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

K_MINIMUM_TURRETS_FOR_DESTROY = 4

K_PLACEMENT_REASON_INSUFFICIENT_FUNDS = 1
K_PLACEMENT_REASON_OBSTRUCTION = 2
K_PLACEMENT_REASON_BLOCKING = 3
K_PLACEMENT_REASON_SHROUD = 4
K_PLACEMENT_REASON_BORDER = 5
K_PLACEMENT_REASON_DESTROY = 6
K_PLACEMENT_REASON_DESTROY_TURRETS_COUNT = 7

K_PLACEMENT_REASON_TEXT = {
  "$" .. tostring(K_PLACEMENT_COST) .. " Required",
  "Obstructed",
  "Blocking!",
  "Shroud",
  "Edge",
  "Destroy",
  "Need " .. tostring(K_MINIMUM_TURRETS_FOR_DESTROY) .. " Turrets First"
}

-- returns 1 if current placement could be validly emplaced at its current location,
-- and 2 if the piece should remove underlying wall instead.
-- also returns a 'reason'
function placement_placable()
  local placement = g_state.placement

  -- check for being completely in fog of war (unless debugging)
  if not g_debug_mode then
    if board_test_collides({
      x=g_state.placement.x,
      y=g_state.placement.y,
      grid=g_state.placement.grid,
      mask=K_FOG_OF_WAR,
      all=true
    }) then
      return false, K_PLACEMENT_REASON_SHROUD
    end
  end

  -- check for touching the border
  for y, x, v in array_2d_iterate(g_state.placement.grid, 0) do
    if v ~= 0 and board_tile_is_border(x + g_state.placement.x, y + g_state.placement.y) then
      return false, K_PLACEMENT_REASON_BORDER
    end
  end

  -- check for fully overlapping a structure
  if board_test_free({
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,
    mask=K_WALL,
    cvalue = K_WALL
  }) then
    -- check that we have sufficient money
    if not g_debug_mode and g_state.statics_count["turret"] < K_MINIMUM_TURRETS_FOR_DESTROY then
      return false, K_PLACEMENT_REASON_DESTROY_TURRETS_COUNT
    end
    if g_state.svy.money < K_PLACEMENT_COST then
      return false, K_PLACEMENT_REASON_INSUFFICIENT_FUNDS
    end
    return 2, K_PLACEMENT_REASON_DESTROY
  end

  -- check for direct collision with any other obstruction
  if not board_test_free({
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,
    mask=K_OBSTRUCTION
  }) then
    return false, K_PLACEMENT_REASON_OBSTRUCTION
  end

  -- check that path would not be interrupted by placing this.
  board_push_temporary_change_from_grid(placement.x, placement.y, placement.grid, K_IMPATHABLE)
  local reachable = svy_goal_reachable()
  board_pop_temporary_change()

  if not reachable then
    return false, K_PLACEMENT_REASON_BLOCKING
  end

  -- check that we have sufficient money
  if g_state.svy.money < K_PLACEMENT_COST then
    return false, K_PLACEMENT_REASON_INSUFFICIENT_FUNDS
  end

  -- can be placed.
  return 1, 0
end

-- TODO: cleanup. this is messy.
function next_placement(is_first_placement)
  if g_state.placement_idx == nil or g_state.placement_idx >= #K_PLACEMENTS then
    g_state.placement_idx = 0
    g_state.placement_permutation = shuffle(iota(#K_PLACEMENTS))

    -- first placement: guarantee that a square block is in either second or third spot.
    -- (this ensures a turret will be placed)
    if is_first_placement then
      table.swap(g_state.placement_permutation, math.random(2, 3), indexof(g_state.placement_permutation, 2))
    end
  end
  g_state.placement_count = g_state.placement_count + 1
  local idx = g_state.placement_idx
  g_state.placement_idx = idx + 1
  local base = K_PLACEMENTS[g_state.placement_permutation[idx + 1]]
  assert(base)
  assert(base.grid ~= nil)

  local x, y = 0, 0
  -- select good default location
  -- TODO: make this better. Select randomly from all non-shrouded non-colliding locations.
  if not g_state.placement then
    local default_r = 3

    local spawn_offset_x, spawn_offset_y = tern(math.random() > 0.5, -1, 1) * default_r, tern(math.random() > 0.5, -1, 1) * default_r

    local default_x, default_y = g_state.spawnx + spawn_offset_y, g_state.spawny + spawn_offset_x
    x = default_x
    y = default_y
  end
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
  -- rotate randomly
  rotate_placement(math.random(4))
  placement_set_dirty()
end

-- returns cache; refreshes cache if necessary
function placement_get_cache()
  local cache = g_state.placement_cache
  local placement = g_state.placement
  if cache.dirty then
    cache.dirty = false
    local placable, reason, payload = placement_placable()
    if placable ~= cache.placable or reason ~= cache.reason or payload ~= cache.payload then
      cache.confirm = false
      cache.show_message_timer = 0
      cache.placable = placable
      cache.reason = reason
      cache.payload = payload
    end
    if cache.placable == 1 or cache.reason == K_PLACEMENT_REASON_INSUFFICIENT_FUNDS then
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

local K_TURRET_VIEW_OBSTRUCTION_RADIUS = 3.5

function draw_placement()
  love.graphics.setColor(1, 1, 1, 0.8)
  local cache = placement_get_cache()
  local placement = g_state.placement
  if placement ~= nil and placement.type == "block" then
    local image = g_images.blocks[placement.color]
    if not cache.placable then
      -- change block color
      image = ({g_images.blocks.gray, g_images.blocks.red2, g_images.blocks.darkgray, g_images.blocks.red, g_images.blocks.red, g_images.blocks.red, g_images.blocks.red})[cache.reason]

      -- render blocks semitransparent
      love.graphics.setColor(1, 1, 1, 0.5)
    end
    if cache.placable == 2 then
      -- 'removal' mode
      image = g_images.blocks.white

      love.graphics.setColor(0.91, 1, 0.9, 0.85)
    end
    for y, x, v in array_2d_iterate(placement.grid, 0) do
      if v ~= 0 then
        local world_pos_x = x + placement.x
        local world_pos_y = y + placement.y
        draw_image_on_grid(image, world_pos_x, world_pos_y)
      end
    end

    -- turret previews
    if cache.placable or cache.reason == K_PLACEMENT_REASON_INSUFFICIENT_FUNDS then
      -- show new turrets
      love.graphics.setColor(1, 1, 1, tern(cache.placable, 0.3 + 0.2 * (math.floor(g_state.time * 10) % 2), 0.28))
      for idx, turret in pairs(cache.turret_potentials) do
        local margin = 8

        -- fill rect
        love.graphics.rectangle("fill", turret.x * k_dim_x + margin, turret.y * k_dim_y + margin, turret.w * k_dim_x - 2 * margin, turret.h * k_dim_y - 2 * margin)
      end

      love.graphics.setColor(1, 1, tern(cache.placable, 0.5, 1), tern(cache.placable, 0.8 + 0.03 * (math.sin(g_state.time * math.tau / 2)), 0.4))
      for idx, turret in pairs(cache.turret_potentials) do
        local props = turret_get_props_by_size(turret.size)

        -- range circle
        local interval = 3
        local offset = tern(cache.placable, g_state.time * 3, g_state.time)
        draw_concentric_circles((turret.x + turret.w / 2) * k_dim_x, (turret.y + turret.h / 2) * k_dim_y, (props.min_range) * k_dim_x, props.max_range * k_dim_x, interval, offset, true)
      end
    end

    -- show existing turrets
    -- disabled because it looks bad
    if g_show_existing_turrets_when_placing then
      for idx, static in static_iterate() do
        if static.wall_obstacle then
          local cx, cy = static.x + static.w / 2, static.y + static.h / 2
          local p = 2 - (point_distance(placement.x + width2d(placement.grid) / 2, placement.y + height2d(placement.grid) / 2, cx, cy) / K_TURRET_VIEW_OBSTRUCTION_RADIUS * 2)
          if p > 0 then
            for margin = 2,20,3 do
              love.graphics.setColor(1, 0.9, 0.9, math.min(p, 1)/(margin / 8 + 1))
              love.graphics.rectangle("line", k_dim_x * static.x + margin, k_dim_y * static.y + margin, k_dim_x * static.w - margin * 2, k_dim_y * static.h - margin * 2)
            end
          end
        end
      end
    end
  end

  -- implacable reason
  if cache.placable ~= 1 then
    local text = K_PLACEMENT_REASON_TEXT[cache.reason]
    if cache.confirm then
      text = "Confirm?"
    end
    local show_message = cache.show_message_timer > 0 or cache.reason == K_PLACEMENT_REASON_BLOCKING or cache.reason == K_PLACEMENT_REASON_BORDER or cache.confirm or cache.placable == 2

    -- placement failure reason
    if text and show_message then
      local text_width = 12 * #text
      local text_height = 30
      local coordx = k_dim_x * (placement.x + width2d(placement.grid) / 2) - text_width / 2
      local coordy = k_dim_x * (placement.y + height2d(placement.grid) / 2) - text_height / 2

      love.graphics.setColor(0, 0, 0, 0.6 + math.sin(g_state.time * 6) * 0.2)
      love.graphics.rectangle("fill", coordx, coordy, text_width, text_height)

      love.graphics.setColor(1, 0.8, 0.6, 0.9)
      love.graphics.printf(text, g_font_msg, coordx, coordy + 4, text_width, "center")
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function placement_clear()
  local placement = g_state.placement

  -- remove wall
  local success = board_emplace({
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,

    -- all board values must be wall
    all = true,
    cmask=K_WALL,
    cvalue = K_WALL,

    -- write zero to those spaces
    wmask = K_WALL,
    value = 0
  })
  assert(success)

  -- remove turrets
  for yo, xo, v in array_2d_iterate(g_state.placement.grid, 0) do
    if v ~= 0 then
      local removed = static_destroy_at(xo + g_state.placement.x, yo + g_state.placement.y)
      print("remove:", xo, yo, removed)
    end
  end

  -- money cost effect
  effects_create_text(
    (placement.x + width2d(placement.grid) / 2) * k_dim_x,
    (placement.y + height2d(placement.grid) / 2) * k_dim_y,
    "-$" .. tostring(K_PLACEMENT_COST)
  )

  g_state.svy.money = g_state.svy.money - K_PLACEMENT_COST

  -- slight effect
  camera_apply_shake(0.3, 1)

  next_placement()
end

function placement_emplace()
  local placement = g_state.placement

  -- place wall
  local success = board_emplace({
    x = placement.x,
    y = placement.y,
    grid = placement.grid,
    cmask = K_OBSTRUCTION,
    wmask = K_FEATURE_MASK,
    value = K_WALL
  })
  assert(success)

  -- remove shroud
  success = board_emplace({
    x = placement.x - 3,
    y = placement.y - 3,
    grid = array_2d_grow(array_2d_grow(array_2d_grow(placement.grid, true), false), false),
    force = true,
    mask = K_FOG_OF_WAR,
    value = 0
  })
  assert(success)

  -- money cost effect
  effects_create_text(
    (placement.x + width2d(placement.grid) / 2) * k_dim_x,
    (placement.y + height2d(placement.grid) / 2) * k_dim_y,
    "-$" .. tostring(K_PLACEMENT_COST)
  )

  g_state.svy.money = g_state.svy.money - K_PLACEMENT_COST

  turret_emplace_potentials_at_grid(placement.x, placement.y, placement.grid, placement.dx, placement.dy)

  local splatter_count = unit_splatter_at_grid(placement.x, placement.y, placement.grid)
  local splatter_shake = 1 + math.sqrt(splatter_count)

  -- shake effect
  camera_apply_shake(0.15 * splatter_shake, 1.6 * splatter_shake)

  next_placement()
end

function placement_set_dirty(reset_placement_ui)
  g_state.placement_cache.dirty = true
  if reset_placement_ui then
    g_state.placement_cache.confirm = false
    g_state.placement_cache.show_message_timer = 0
  end
end

function rotate_placement(dr, placement)
  local placement = placement or g_state.placement
  for iter = 1,(math.abs(dr) % 4) do
    if dr >= 1 then
      placement.grid = rotate_2d_array_cw(placement.grid)
      placement.dx, placement.dy = placement.dy, -placement.dx
    end
    if dr <= -1 then
      placement.grid = rotate_2d_array_ccw(placement.grid)
      placement.dx, placement.dy = -placement.dy, placement.dx
    end
  end
end

function update_placement(dx, dy, dr, dt)
  if g_state.placement_cache.show_message_timer > 0 then
    g_state.placement_cache.show_message_timer = g_state.placement_cache.show_message_timer - dt
  end

  if g_state.placement then
    local proposed_placement = table.clone(g_state.placement)

    -- translate
    proposed_placement.x = proposed_placement.x + dx
    proposed_placement.y = proposed_placement.y + dy

    -- clamp
    proposed_placement.x = math.clamp(proposed_placement.x, g_state.board.left, g_state.board.right - 1)
    proposed_placement.y = math.clamp(proposed_placement.y, g_state.board.top, g_state.board.bottom - 1)

    -- rotate
    rotate_placement(dr, proposed_placement)
    if dr ~= 0 then
      g_state.placement_rotation_count = g_state.placement_rotation_count + 1
    end

    -- update placement only if any actual change was made.
    if dr ~= 0 or dx ~= 0 or dy ~= 0 then
      g_state.placement = proposed_placement
      placement_set_dirty(true)
      g_state.placement.show_message_timer = 0
    end

    if key_pressed("space") or key_pressed("return") then
      local cache = placement_get_cache()
      if cache.placable == 1 then
        placement_emplace()
      elseif cache.placable == 2 then
        if cache.confirm then
          cache.confirm = false
          placement_clear()
        else
          cache.confirm = true
        end
      else
        -- show reason why it can't be placed.
        cache.show_message_timer = 2.7
      end
    end
  end
end