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
    for yo, xo, v in array_2d_iterate(grid, 0) do
      if v ~= 0 and node.x == base_x + xo and node.y == base_y + yo then
        return true
      end
    end
  end
  return false
end

-- repath any units whose current path intersects the update.
function unit_on_board_update(det)
  if det.etype == K_BOARD_EVENT_SET then
    if false then -- TODO -- enable this.
      local base_x = det.x
      local base_y = det.y
      local grid = det.grid
      for id, unit in pairs(g_state.units) do
        if unit.path and unit_path_intersects_grid(unit.path, base_x, base_y, grid) then
          unit.path = nil
          unit_repath(id)
        end
      end
    else
      unit_repath_all()
    end
  end
end

function unit_emplace(sprite, x, y, opts)
  local id = g_unit_id
  g_unit_id = g_unit_id + 1
  g_state.units[id] = {
    id = id,

    -- grid x position
    x = x,
    y = y,

    -- stats
    health = opts.hp or opts.health or opts.hpmax or opts.healthmax or 4,
    healthmax = opts.hpmax or opts.healthmax or opts.hp or opts.health or 4,
    bounty = opts.bounty or 2,

    -- movement rate (tiles per second)
    move_speed = 1,
    move_speed_concealed = 10, -- speed when in fog of war
    concealed = nil,

    -- tile distance moved (in dx, dy)
    move_distance = 0,

    -- direction
    dx = 1,
    dy = 0,

    -- animation
    state = "idle",
    animation_speed = 5.5, -- temp/arbitrary
    healthbar_offy = -25, -- temp/arbitrary
    healthbar_height = 9,
    healthbar_width = 30, -- temp/arbitrary

    -- sprite
    sprite = sprite
  }

  -- determine first path
  unit_repath(id)
  return id
end

-- iterates: id, unit
function unit_iterate()
  return pairs(g_state.units)
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
    unit.path = nil
    unit_repath(id)
  end
end

function unit_process_removals()
  for removal in entries(g_state.remove_units) do
    g_state.units[removal] = nil
  end
  g_state.remove_units = {}
end

-- kills unit with blood splatter
function unit_splatter(id)
  local unit = unit_get(id)
  if unit then
    local gx, gy = unit_get_precise_grid_position(id)
    for i = 1,7 + math.random(5) do
      local effect = {
        sprite = g_images.blood,
        duration = 0.3 + math.frandom(0.3)
      }
      local dx, dy = math.frandom(-0.7, 0.7), math.frandom(-0.7, 0.7)
      effects_create({
        x = k_dim_x * (dy + gx),
        y = k_dim_y * (dy + gy),
        duration = 0.2 + math.frandom(0.6),
        sprite = g_images.blood,
        scale = 1 + math.frandom(1),
        xspeed = dx * k_dim_x * 2 + math.frandom(-1, 1) * k_dim_x,
        yspeed = dy * k_dim_y * 2 + math.frandom(-1, 1) * k_dim_y,
      })
    end

    local squash_bounty = math.ceil(unit.bounty * 1.5)
    effects_create_text(gx * k_dim_x, gy * k_dim_y, "$" .. tostring(squash_bounty))
    svy_gain_bounty(squash_bounty)
    unit_remove(id)
  end
end

function unit_splatter_at_grid(x, y, grid)
  local splatter_count = 0
  for yo, xo, v in array_2d_iterate(grid, 0) do
    if v then
      for id, unit in unit_iterate() do
        if unit.x == x + xo and unit.y == y + yo then
          unit_splatter(id)
          splatter_count = splatter_count + 1
        end
      end
    end
  end

  return splatter_count
end

-- damages unit by the given amount
-- set effect to false to suppress any blood splatter effect
function unit_apply_damage(id, amount, effect)
  if effect == nil then
    effect = {
      sprite = g_images.blood,
      duration = 0.3 + math.frandom(0.3)
    }
  end
  local unit = unit_get(id)
  if unit then
    local px, py = unit_get_precise_position(id)
    unit.health = unit.health - amount
    if amount > 0 and effect and effect ~= 0 then
      effects_create({
        x = k_dim_x * math.frandom(-0.4, 0.4) + px,
        y = k_dim_y * math.frandom(-0.4, 0.4) + py,
        duration = effect.duration,
        sprite = effect.sprite,
        scale = 1 + math.frandom(0.6)
      })
    end
    if unit.health <= 0 then
      -- death
      unit.health = 0
      svy_gain_bounty(unit.bounty)
      effects_create_text(px, py, "$" .. tostring(unit.bounty))
      unit_remove(id)
    end
  end
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

  -- wander if no path found and not at goal.
  if unit.path == nil and unit.move_distance >= 0 and not svy_position_is_at_goal(unit.x, unit.y) then
    local blocking_grid = make_2d_array(3, 3, 0)
    for y, x in array_2d_iterate(blocking_grid, 1) do
      if bit.band(board_get_value(x + unit.x - 2, y + unit.y - 2, K_IMPATHABLE), K_IMPATHABLE) ~= 0 then
        blocking_grid[y][x] = 1
      end
    end

    for _, i in ipairs(shuffle(iota(0, 8))) do
      local x = (i % 3) + 1
      local y = math.floor(i / 3) + 1
      if x ~= 2 or y ~= 2 then
        print(i, x, y, blocking_grid[y][x])
        if blocking_grid[y][x] == 0 then
          unit.path = {{x = x + unit.x - 2, y = y + unit.y - 2}}
          print("set path")
          break
        end
      end
    end
  end

  -- walk along path
  -- while loop accounts for possibility of such extreme
    -- lag that multiple tiles are advanced right now.
  local retry = true
  if unit.concealed == nil then
    unit.concealed = true
    for x = -1,1 do
      for y = -1,1 do
        if not board_test_collides({x = unit.x + x, y = unit.y + y, grid = {{1}}, mask = K_FOG_OF_WAR}) then
          unit.concealed = false
          break
        end
      end
    end
  end
  local speed = tern(unit.concealed, unit.move_speed_concealed, unit.move_speed)
  while retry do
    retry = false
    if not unit.path then
      if unit.move_distance ~= 0 then
        unit.move_distance = shrink_toward(unit.move_distance, 0, speed * dt)
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
      unit.move_distance = unit.move_distance + speed * dt
      dt = 0
      if unit.move_distance >= 0 and (dx ~= 0 or dy ~= 0) then
        unit.dx = dx
        unit.dy = dy
      end
      if unit.move_distance >= goal_move_distance then
        unit.concealed = nil
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

    -- damage sovereignty
    svy_lose_hp()
  end
end

-- returns precise distance from (grid) x, y location to unit in grid distance
function unit_distance_to(x, y, id)
  local gx, gy = unit_get_precise_grid_position(id)
  if gx and gy then
    -- TODO: factor in unit's offset.
    return point_distance(x, y, gx, gy)
  end
end

-- returns closest unit (and its distance) to given location
function unit_closest(x, y, min, max)
  min = min or 0
  local best = nil
  local best_id = nil
  for id, unit in unit_iterate() do
    local dist = unit_distance_to(x, y, id)
    if ((not best) or dist < best) and dist >= min and ((not max) or dist <= max) then
      best = dist
      best_id = id
    end
  end

  return best_id, best
end

function unit_draw_all()
  for id, unit in pairs(g_state.units) do
    unit_draw(id)
  end
end

-- retrieves pixel x,y location of unit
-- (also returns normalized dx, dy values.)
function unit_get_precise_position(id)
  local unit = unit_get(id)
  if not unit then
    return nil, nil
  end
  local ux = unit.dx / math.sqrt(unit.dx * unit.dx + unit.dy * unit.dy)
  local uy = unit.dy / math.sqrt(unit.dx * unit.dx + unit.dy * unit.dy)
  --love.graphics.circle("line", (unit.x + 0.5) * k_dim_x, (unit.y + 0.5) * k_dim_y, k_dim_x / 2)
  local px = (unit.x + 0.5 + ux * unit.move_distance) * k_dim_x
  local py = (unit.y + 0.5 + uy * unit.move_distance) * k_dim_y
  return px, py, ux, uy
end

-- as above, but in grid coordinates
function unit_get_precise_grid_position(id)
  local px, py, ux, uy = unit_get_precise_position(id)
  if not px then
    return nil, nil
  end
  return px / k_dim_x, py / k_dim_y, ux, uy
end

function unit_draw(id)
  local unit = g_state.units[id]
  if not unit then
    return
  end

  local px, py, ux, uy = unit_get_precise_position(id)
  draw_unit_sprite(unit.sprite, unit.state, ux, uy, g_state.time * unit.animation_speed,
    px,
    py,
    1.5, 1.5
  )

  -- health bar
  -- (checking health > 0 is paranoia)
  if unit.health < unit.healthmax and unit.health > 0 then
    draw_healthbar(px, py + unit.healthbar_offy, unit.healthbar_width, unit.healthbar_height, unit.health, unit.healthmax)
  end
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

  animation_angle_offset = d(get_rotation_offset_for_animation(8, dx, dy), 2)
  animation_sx = 1
  if animation_angle_offset >= 5 then
    animation_angle_offset = 8 - animation_angle_offset
    animation_sx = -1
  end
  
  draw_sprite(sprite, animation_base + animation_angle_offset, x, y, 0, (sx or 1) * animation_sx, sy or 1)
end