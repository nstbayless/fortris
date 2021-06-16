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
    for yo, xo, v in array_2d_iterate(grid, 0, dx, dy) do
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

function turret_get_props_by_size(size)
  local sprites = {{sprite = g_images.turret_base}, {sprite = g_images.turret}}

  local props = {
    target = nil,
    min_range = 1,
    max_range = 5,
    damage = 0.25,
    firing_interval = 0.5,
    firing_timer = 0.12,
  }

  if size == 3 then
    sprites = {{sprite = nil}, {sprite = g_images.artillery}}
    props = {
      target = nil,
      min_range = 5,
      max_range = 12,
      damage = 2.25,
      firing_interval = 10 / 3,
      firing_timer = 2.1,
    }
  end

  if size == 4 then
    -- TODO: a bigger sprite.
    sprites = {{sprite = nil}, {sprite = g_images.artillery}}
    props = {
      target = nil,
      min_range = 5,
      max_range = 12,
      damage = 10,
      firing_interval = 4.5,
      firing_timer = -2,
    }
  end

  -- apply sprite offset
  for sprite in entries(sprites) do
    sprite.sprite_offx = k_dim_x * size / 2
    sprite.sprite_offy = k_dim_y * size / 2
  end

  return props, sprites
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
          mask = K_WALL
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
            size = size,
            w = size,
            h = size
          }
        end
      end
    end
  end

  return nil
end

-- updates a turret static.
function turret_update(dt, id, turret)
  -- centre of turret
  local cx = turret.x + turret.w / 2
  local cy = turret.y + turret.h / 2
  local props = turret.props

  if props.target == nil or not in_range(d(unit_distance_to(cx, cy, props.target), 0), props.min_range, props.max_range) then
    -- select new target
    props.target = unit_closest(cx, cy, props.min_range, props.max_range)
    if not in_range(d(unit_distance_to(cx, cy, props.target), 0), props.min_range, props.max_range) then
      props.target = nil
    end
  end

  -- shoot, if there is a target.
  local do_shoot = false
  props.firing_timer = props.firing_timer + dt
  if props.firing_timer >= props.firing_interval then
    if props.target then
      props.firing_timer = props.firing_timer - props.firing_interval
      do_shoot = true
      -- damage target
      unit_apply_damage(props.target, props.damage)
    else
      props.firing_timer = props.firing_interval
    end
  end

  local target = unit_get(props.target)

  -- animation: face target
  local angle_offset = 0
  if target then
    angle_offset = get_rotation_offset_for_animation(8, target.x + 0.5 - cx, target.y + 0.5 - cy)
    if angle_offset then
      turret.sprites[2].sprite_subimage = angle_offset
    else
      angle_offset = 0
    end
  end

  -- animation: shooting
  if props.firing_timer < props.firing_interval / 4.5  then
    turret.sprites[2].sprite_subimage = (turret.sprites[2].sprite_subimage % 8) + 8
  else
    turret.sprites[2].sprite_subimage = turret.sprites[2].sprite_subimage % 8
  end

  -- muzzle flash
  if do_shoot then
    muzzle_centre_x = cx * k_dim_x + 18 * math.sin(angle_offset * math.tau / 8)
    muzzle_centre_y = cy * k_dim_y - 18 * math.cos(angle_offset * math.tau / 8) - 2

    effects_create({
      x = muzzle_centre_x,
      y = muzzle_centre_y,
      sprite = g_images.muzzle,
      duration = 0.5,
      subimage_range = {angle_offset * 8, angle_offset * 8 + 8},
      scale = 2
    })
  end
end

function turret_emplace_potentials_at_grid(x, y, grid, dx, dy)
  local potentials = turret_get_potentials_at_grid(x, y, grid, dx, dy)
  for potential in entries(potentials) do
    assert(potential.x and potential.y and potential.size)
    local props, sprites = turret_get_props_by_size(potential.size)

    static_emplace({
      x = potential.x,
      y = potential.y,
      w = potential.size,
      h = potential.size,
      collision_flags = K_STATIC,
      sprites = sprites,
      fn_update = turret_update,
      props = props
    })
  end
end