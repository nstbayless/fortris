local simplex = require("ext.simplex")

function board_generate_init()
  g_state.generate = {}
  g_state.generate.seedx = math.frandom(1000000)
  g_state.generate.seedy = math.frandom(1000000)
end

-- unused, but could be used to replace board_generate_tile.
function board_generate_tile_basic(x, y)
  local v = K_FOG_OF_WAR

  -- variants
  if math.random() > 0.5 then
    v = bit.bor(v, K_VARIANT)
  end
  return v
end

-- where enemies spawn
function board_get_source()
  return g_state.spawnx, g_state.board.top
end

-- should the given coordinate have rock at it?
-- value is filtered elsewhere.
local function has_rock_base(x, y)

  -- don't allow within a certain distance of the goal
  if point_distance(x, y, g_state.spawnx, g_state.spawny) < 6 then
    return false
  end

  -- clear a path north of the goal.
  if math.abs(x - g_state.spawnx) <= 1 then
    return false
  end

  local scale = 10
  local margin = 0.5
  return simplex.Noise2D(x / scale + g_state.generate.seedx, g_state.generate.seedy + y / scale) > margin
end

-- prunes some rocks if they don't have enough neighbours or would end up in a forbidden configuration.
local function has_rock_base_filtered(x, y, depth)
  if not has_rock_base(x, y) then
    return false
  end
  local has_x_neighbour = has_rock_base(x + 1, y) or has_rock_base(x - 1, y)
  local has_y_neighbour = has_rock_base(x, y + 1) or has_rock_base(x, y - 1)

  if not has_x_neighbour and not has_y_neighbour then
    return false
  end

  return true
end

-- new tile added to board
function board_generate_tile(x, y)
  local v = K_FOG_OF_WAR

  if has_rock_base_filtered(x, y) then
    v = bit.bor(v, K_ROCK)
  end

  -- variants
  if math.random() > 0.6 then
    v = bit.bor(v, K_VARIANT)
  end
  return v
end