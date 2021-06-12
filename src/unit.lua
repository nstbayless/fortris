K_ANIMATION_STAND = 0
K_ANIMATION_WALK = {}
K_ANIMATION_WALK[0] = 5
K_ANIMATION_WALK[1] = 10
K_ANIMATION_WALK[2] = 15
K_ANIMATION_WALK[3] = 20

local g_unit_id = 0

function unit_init()
  g_state.units = {}
  g_state.remove_units = {}
  board_observe(unit_on_board_update)
end

function unit_path_intersects_grid(path, base_x, base_y, grid)
  for node in entries(path) do
    for yo, xo, v in array_2d_iterate(grid) do
      if v ~= 0 and node.x == base_x + xo - 1 and node.y == base_y + yo - 1 then
        return true
      end
    end
  end
  return false
end

-- repath any units whose current path intersects the update.
function unit_on_board_update(det)
  if false then
    local base_x = det.x
    local base_y = det.y
    local grid = det.grid
    for id, unit in pairs(g_state.units) do
      if unit.path and unit_path_intersects_grid(unit.path, base_x, base_y, grid) then
        unit_repath(id)
      end
    end
  else
    unit_repath_all()
  end
end

function unit_emplace(sprite, x, y)
  local id = g_unit_id
  g_unit_id = g_unit_id + 1
  g_state.units[id] = {
    id = id,

    -- grid x position
    x = x,
    y = y,

    -- movement rate (tiles per second)
    move_speed = 1,

    -- tile distance moved (in dx, dy)
    move_distance = 0,

    -- direction
    dx = 1,
    dy = 0,

    -- animation
    state = "idle",
    animation_speed = 5.5,

    -- sprite
    sprite = sprite
  }

  -- determine first path
  unit_repath(id)
  return id
end

function unit_get(id)
  return g_state.units[id]
end

function unit_repath(id)
  local unit = unit_get(id)
  if not unit then
    return
  end

  local path, _ = svy_pathfind_to_goal(unit.x, unit.y)
  if path then
    unit.path = densify_path(path)
  end
end

function unit_repath_all()
  for id, unit in pairs(g_state.units) do
    unit_repath(id)
  end
end

function unit_process_removals()
  for removal in entries(g_state.remove_units) do
    g_state.units[removal] = nil
  end
  g_state.remove_units = {}
end

function unit_remove(id)
  table.insert(g_state.remove_units, id)
end

function unit_update_all(dt)
  unit_process_removals()
  for id, unit in pairs(g_state.units) do
    unit_update(id, dt)
  end
  unit_process_removals()
end

function unit_draw_all()
  for id, unit in pairs(g_state.units) do
    unit_draw(id)
  end
end

function unit_update(id, dt)
  local unit = g_state.units[id]

  -- remove first path entry if it is equal to the unit's x,y position
  while unit.path ~= nil and #(unit.path) > 0 and unit.path[1].x == unit.x and unit.path[1].y == unit.y do
    table.remove(unit.path, 1)
  end

  -- empty paths are not allowed.
  if unit.path ~= nil and #unit.path == 0 then
    unit.path = nil
  end

  -- walk along path
  -- while loop accounts for possibility of such extreme
    -- lag that multiple tiles are advanced right now.
  local retry = true
  while retry do
    retry = false
    if not unit.path then
      if unit.move_distance ~= 0 then
        unit.move_distance = shrink_toward(unit.move_distance, 0, unit.move_speed * dt)
        unit.state = tern(unit.move_distance < 0, "walk", "walk-reverse")
      else
        unit.state = "idle"
      end
    else
      unit.state = "walk"
      local node = unit.path[1]
      local dx = node.x - unit.x
      local dy = node.y - unit.y
      local goal_move_distance = math.sqrt(dx * dx + dy * dy) / 2
      unit.move_distance = unit.move_distance + unit.move_speed * dt
      dt = 0
      if unit.move_distance >= 0 and (dx ~= 0 or dy ~= 0) then
        unit.dx = dx
        unit.dy = dy
      end
      if unit.move_distance >= goal_move_distance then
        unit.move_distance = unit.move_distance - goal_move_distance * 2
        -- advance to next node
        unit.x = node.x
        unit.y = node.y
        -- TODO: optimize by reversing order of path.
        table.remove(unit.path, 1)
        if #unit.path == 0 then
          unit.path = nil
        end

        -- we need to run this again if we've advanced even further than a whole tile.
        if unit.move_distance >= 0 then
          retry = true
        end
      end
    end
  end

  -- remove unit if reaches destination
  if unit.move_distance == 0 and svy_position_is_at_goal(unit.x, unit.y) then
    unit_remove(unit.id)
  end
end

function unit_draw(id)
  local unit = g_state.units[id]
  if not unit then
    return
  end

  local ux = unit.dx / math.sqrt(unit.dx * unit.dx + unit.dy * unit.dy)
  local uy = unit.dy / math.sqrt(unit.dx * unit.dx + unit.dy * unit.dy)
  --love.graphics.circle("line", (unit.x + 0.5) * k_dim_x, (unit.y + 0.5) * k_dim_y, k_dim_x / 2)
  draw_unit_sprite(unit.sprite, unit.state, ux, uy, g_state.time * unit.animation_speed,
    (unit.x + 0.5 + ux * unit.move_distance) * k_dim_x,
    (unit.y + 0.5 + uy * unit.move_distance) * k_dim_y,
    2, 2
  )
end

-- dx, dy indicate facing.
function draw_unit_sprite(sprite, animation_name, dx, dy, timer, x, y, sx, sy)
  assert(sprite)
  local animation_base = 0
  if animation_name == "idle" then
    animation_base = K_ANIMATION_STAND
  end
  if animation_name == "walk" then
    animation_base = K_ANIMATION_WALK[math.floor(timer) % 4]
  end
  if animation_name == "walk-reverse" then
    animation_base = K_ANIMATION_WALK[math.floor(timer) % 4]
    dx = dx * -1
    dy = dy * -1
  end

  animation_angle_offset = 2
  animation_sx = 1
  if dx ~= 0 or dy ~= 0 then
    local angle = math.atan2(dy, dx) / math.tau
    if angle < 0 then
      angle = angle + 1
    end
    if in_range(angle, 11/16, 13/16) then
      animation_angle_offset = 0
    elseif in_range(angle, 13/16, 15/16) then
      animation_angle_offset = 1
    elseif angle >= 15/16 or angle < 1/16 then
      animation_angle_offset = 2
    elseif in_range(angle, 1/16, 3/16) then
      animation_angle_offset = 3
    elseif in_range(angle, 3/16, 5/16) then
      animation_angle_offset = 4
    elseif in_range(angle, 5/16, 7/16) then
      animation_angle_offset = 3
      animation_sx = -1
    elseif in_range(angle, 7/16, 9/16) then
      animation_angle_offset = 2
      animation_sx = -1
    elseif in_range(angle, 9/16, 11/16) then
      animation_angle_offset = 1
      animation_sx = -1
    end
  end

  draw_sprite(sprite, animation_base + animation_angle_offset, x, y, 0, (sx or 1) * animation_sx, sy or 1)
end