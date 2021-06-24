K_PLACEMENT_COST = 10
K_REMOVAL_COST = 20

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
  g_state.placement_queue = {}
  g_state.placement_count = 0
  g_state.placement_swap = nil
  g_state.placement_rotation_count = 0
  g_state.placement_cache = {
    dirty = true,
    show_message_timer = 0,
    placable = false,
    implacable_reason = 1,
    turret_potentials = {},
    confirm = false
  }
  next_placement()

  board_observe(
    function() 
      g_state.placement_cache.dirty = true
    end
  )
end

function peek_placement(idx)
  idx = idx or 0
  while #g_state.placement_queue <= idx do
    local add = shuffle(iota(#K_PLACEMENTS))

    -- ensure square appears at start of the game
    if g_state.placement_count == 0 and #g_state.placement_queue == 0 then
      table.swap(add, math.random(2, 3), indexof(add, 2))
    end

    -- add
    for _, v in ipairs(add) do
      g_state.placement_queue[#g_state.placement_queue + 1] = v
    end
  end

  return g_state.placement_queue[idx + 1]
end

function pop_placement()
  local i = peek_placement(0)
  table.remove(g_state.placement_queue, 1)
  return i
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
  local w, h = placement_dimensions()
  return w
end

function placement_height()
  local w, h = placement_dimensions()
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
  "Insufficient Funds",
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
      return false, K_PLACEMENT_REASON_DESTROY_TURRETS_COUNT, K_MINIMUM_TURRETS_FOR_DESTROY
    end
    if g_state.svy.money < K_PLACEMENT_COST then
      return false, K_PLACEMENT_REASON_INSUFFICIENT_FUNDS, K_REMOVAL_COST
    end
    return 2, K_PLACEMENT_REASON_DESTROY, K_REMOVAL_COST
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

  local _, tree_count = board_test_collides({
    all = true, -- need this to get accurate count
    x=g_state.placement.x,
    y=g_state.placement.y,
    grid=g_state.placement.grid,
    mask=K_TREE
  })
  local cost = K_PLACEMENT_COST + 2 * tree_count

   -- check that we have sufficient money
   if g_state.svy.money < cost then
     return false, K_PLACEMENT_REASON_INSUFFICIENT_FUNDS, cost
  end

  -- can be placed.
  return 1, 0, cost
end

-- TODO: cleanup. this is messy.
function next_placement()
  local base = K_PLACEMENTS[pop_placement()]
  g_state.placement_count = g_state.placement_count + 1
  assert(base)
  assert(base.grid ~= nil)
  
  set_placement({
    type = "block",
    color = indexof(k_block_colors, base.color),
    grid = base.grid,

    -- direction turrets will be laid / 'facing'
    dx = 1,
    dy = 1
  })

  -- rotate randomly
  rotate_placement(math.random(4))
  placement_set_dirty()
end

function set_placement(placement)

  local x, y = 0, 0
  -- select good default location
  -- TODO: make this better. Select randomly from all non-shrouded non-colliding locations.
  if not g_state.placement then
    local default_r = 3

    local spawn_offset_x, spawn_offset_y = tern(math.random() > 0.5, -1, 1) * default_r, tern(math.random() > 0.5, -1, 1) * default_r

    local default_x, default_y = g_state.spawnx + spawn_offset_y, g_state.spawny + spawn_offset_x
    x = default_x
    y = default_y
  else
    x = g_state.placement.x + math.floor(placement_width() / 2)
    y = g_state.placement.y + math.floor(placement_height() / 2)
  end

  placement.x = x - math.floor(width2d(placement.grid) / 2)
  placement.y = y - math.floor(height2d(placement.grid) / 2)
  g_state.placement = placement

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
      cache.show_message_timer = 0
      cache.placable = placable
      cache.reason = reason
      cache.payload = payload
      cache.confirm = false
      cache.requires_confirm = (reason == K_PLACEMENT_REASON_DESTROY)
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

function draw_placement_preview_centred(placement, x, y, s)
  s = s or 16
  local w = width2d(placement.grid)
  local h = height2d(placement.grid)
  local img = g_images.blocks[placement.color]
  local imgw, imgh = img:getDimensions()
  for yo, xo, v in array_2d_iterate(placement.grid, 0) do
    if v ~= 0 then
      local vx = x + (xo - w/2) * s - s/2
      local vy = y + (yo - h/2) * s - s/2
      love.graphics.draw(img, vx, vy, 0, s / imgw, s / imgh)
    end
  end
end

function draw_placement_queue(x, y, n, s)
  local p = math.clamp(g_state.full_feature_timer, 0, 1)
  love.graphics.push_opts()
  local a = 0.9
  s = s or 16
  n = n or 4
  for i = 0,n-1 do
    love.graphics.setColor(1, 1, 1, math.clamp(a - 1 + p, 0, 1))
    local placement = K_PLACEMENTS[peek_placement(i)]
    draw_placement_preview_centred(placement, x, y, s)
    y = y + s * 4
    s = s * 0.9
    a = a * 0.8
  end
  love.graphics.pop_opts()
end

function draw_placement_swap(x, y, s)
  love.graphics.push_opts()

  local p = math.clamp(g_state.full_feature_timer, 0, 1)
  local boxsize = s * 4 + 9
  for i = 0,1 do
    if i == 1 then
      love.graphics.setColor(1, 1, 1, p)
    else
      love.graphics.setColor(0, 0, 0, 0.6 * p)
    end

    love.graphics.rectangle(tern(i == 0, "fill", "line"), x - boxsize/2, y - boxsize/2, boxsize, boxsize)
  end

  love.graphics.setColor(1, 1, 1, 0.8 * p)
  if g_state.placement_swap then
    draw_placement_preview_centred(g_state.placement_swap, x + s / 2, y + s / 2, s or 16)
  else
    local text = get_cached_text(g_font_msg, "[Swap]")
    love.graphics.draw(text, x + s / 2 - text:getWidth() / 2 - 6, y - s/3 - text:getHeight() / 2)
  end

  local text = get_cached_text(g_font_msg, "Press T")
  love.graphics.draw(text, x + s / 2 - text:getWidth() / 2 - 6, y + s + 8 - text:getHeight() / 2)

  love.graphics.pop_opts()
end

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
        local ripple = nil
        if g_is_lutro then
          interval = 20
          ripple = 4
          offset = offset / 1.5
        end
        draw_concentric_circles((turret.x + turret.w / 2) * k_dim_x, (turret.y + turret.h / 2) * k_dim_y, (props.min_range) * k_dim_x, props.max_range * k_dim_x, interval, offset, true, ripple)
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

  -- centre of placement (in grid coordinates)
  local centre_x = (placement.x + width2d(placement.grid) / 2)
  local centre_y = (placement.y + height2d(placement.grid) / 2)

  -- show pathable boundaries
  local pathable_boundary_margin = 3
  local K_DISPLAY_EDGES = bit.bor(K_TREE, K_ROCK) -- only display for rock and tree right now
  for x = placement.x - pathable_boundary_margin,placement.x + width2d(placement.grid) + pathable_boundary_margin -1 do
    for y = placement.y - pathable_boundary_margin,placement.y + height2d(placement.grid) + pathable_boundary_margin -1 do
      -- only draw boundaries on tiles matching K_DISPLAY_EDGES which are impathable and not concealed
      if bit.band(board_get_value(x, y, 0), bit.band(K_DISPLAY_EDGES, K_IMPATHABLE)) ~= 0
        and bit.band(board_get_value(x, y, K_FOG_OF_WAR), K_FOG_OF_WAR) == 0 then
        for xc = x - 1,x+1 do
          for yc = y-1,y+1 do
            if (xc == x and yc ~= y) or (xc ~= x and yc == y) then
              if bit.band(board_get_value(xc, yc, K_DISPLAY_EDGES), K_DISPLAY_EDGES) == 0 then
                -- this is a border, so we draw it.
                local dx, dy = xc - x, yc - y
                local line_interval = 4
                for j = 0,tern(g_is_lutro, 0, 2) do
                  local p = math.max(0.1, 1 - point_distance( centre_x, centre_y, xc + 0.5, yc + 0.5) / 8) * (1 - j / 3)
                  love.graphics.setColor(0.9, 0.8, 1, (0.7 + math.sin(g_state.time * 3) * 0.1) * p)
                  if yc == y then
                    love.graphics.line(k_dim_x * (x + xc + 1) / 2 - dx * j * line_interval, k_dim_y * y + 1, k_dim_x * (x + xc + 1) / 2 - dx * j * line_interval, k_dim_y * (y + 1) - 1)
                  elseif xc == x then
                    love.graphics.line(k_dim_x * x, k_dim_y * (y + yc + 1) / 2 - dy * j * line_interval, k_dim_x * (x + 1) - 1, k_dim_y * (y + yc + 1) / 2 - dy * j * line_interval)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- implacable reason
  if cache.placable ~= 1 or cache.confirm or (cache.placable == 1 and cache.payload > K_PLACEMENT_COST) then
    local text = K_PLACEMENT_REASON_TEXT[cache.reason]
    local glow = true
    if cache.reason == K_PLACEMENT_REASON_INSUFFICIENT_FUNDS then
      text = "$" .. tostring(cache.payload) .. " Required"
    end
    if (cache.placable == 1) and cache.payload > K_PLACEMENT_COST then
      text = "$" .. tostring(cache.payload)
      glow = false
    end
    if cache.confirm then
      text = "Confirm: $" .. tostring(cache.payload)
    end
    local show_message = cache.show_message_timer > 0 or cache.reason == K_PLACEMENT_REASON_BLOCKING or cache.reason == K_PLACEMENT_REASON_BORDER or cache.confirm or cache.placable == 2 or (cache.placable == 1 and cache.payload > K_PLACEMENT_COST)

    -- placement failure reason
    if text and show_message then
      local text_width = 12 * #text
      local text_height = 30
      local coordx = k_dim_x * centre_x - text_width / 2
      local coordy = k_dim_x * centre_y - text_height / 2
      
      love.graphics.setColor(0, 0, 0, 0.6 + math.sin(g_state.time * 6) * tern(glow, 0.2, 0.02))
      love.graphics.rectangle("fill", coordx, coordy, text_width, text_height)

      love.graphics.setColor(1, 0.8, 0.6, 0.9)
      if not g_is_lutro then
        love.graphics.printf(text, g_font_msg, coordx, coordy + 4, text_width, "center")
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function placement_clear()
  local placement = g_state.placement
  local cache = g_state.placement_cache

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
    "-$" .. tostring(cache.payload)
  )

  g_state.svy.money = g_state.svy.money - cache.payload

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
    "-$" .. tostring(g_state.placement_cache.payload)
  )

  g_state.svy.money = g_state.svy.money - g_state.placement_cache.payload

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

function placement_swap()
  local placement = g_state.placement
  if g_state.placement_swap then
    set_placement(g_state.placement_swap)
  else
    next_placement()
  end
  g_state.placement_swap = placement
end

function update_placement(dt)
  if g_state.placement_cache.show_message_timer > 0 then
    g_state.placement_cache.show_message_timer = g_state.placement_cache.show_message_timer - dt
  end

  local dx, dy, dr = g_input_state.dx, g_input_state.dy, g_input_state.dr

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
    
    if key_pressed("swap") then
      if g_state.full_feature then
        placement_swap()
      end
    end

    if key_pressed("place") then
      local cache = placement_get_cache()
      if not cache.confirm and cache.requires_confirm then
        cache.confirm = true
      else
        cache.confirm = false
        if cache.placable == 1 then
          placement_emplace()
        elseif cache.placable == 2 then
          placement_clear()
        else
          -- show reason why it can't be placed.
          cache.show_message_timer = 2.7
        end
      end
    end
  end
end