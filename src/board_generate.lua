local simplex = require("ext.simplex")

function board_generate_init()
  g_state.generate = {}
  g_state.generate.seedx = math.frandom(10000000)
  g_state.generate.seedy = math.frandom(10000000)
  g_state.generate.seedx_tree = math.frandom(10000000)
  g_state.generate.seedy_tree = math.frandom(10000000)
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

-- where enemies must be able to spawn
function board_get_source()
  -- default values
  g_state.sourcex = g_state.sourcex or g_state.spawnx
  g_state.sourcey = g_state.sourcey or g_state.board.top
  return g_state.sourcex, g_state.sourcey
end

-- change where enemies must be able to spawn
function board_set_source(x, y)
  g_state.sourcex, g_state.sourcey = x, y

  -- ensure source location is on border and can reach the goal.
  assert(board_tile_is_border(x, y))
  assert(svy_pathfind_to_goal(x, y))
end

-- what terrain feature does the given coordinate get?
-- value is filtered elsewhere.
local function base_type(x, y)

  -- don't allow within a certain distance of the goal
  if point_distance(x, y, g_state.spawnx, g_state.spawny) < 6 then
    return K_TILE_EMPTY
  end

  -- clear a path north of the goal.
  if math.abs(x - g_state.spawnx) <= 1 then
    return K_TILE_EMPTY
  end

  local scale = 10
  if simplex.Noise2D(x / scale + g_state.generate.seedx, g_state.generate.seedy + y / scale) > 0.6 then
    return K_ROCK
  end
  if simplex.Noise2D(x / scale + g_state.generate.seedx_tree, g_state.generate.seedy_tree + y / scale) > 0.4 then
    return K_TREE
  end
  return K_TILE_EMPTY
end

-- prunes some rocks if they don't have enough neighbours or would end up in a forbidden configuration.
-- grows trees south-easterly
local function type_filtered(x, y, depth)

  -- grow trees to the south-east
  for dx = -1,0 do
    for dy = -1,0 do
      if base_type(x + dx, y + dy) == K_TREE then
        return K_TREE
      end
    end
  end

  -- grow mountains north-west
  for dx = 0,1 do
    for dy = 0,1 do
      if base_type(x + dx, y + dy) == K_ROCK then
        return K_ROCK
      end
    end
  end

  return K_TILE_EMPTY
end


-- grows trees south-rightwardly
local function has_tree_filtered(x, y, depth)
  
end

-- new tile added to board
function board_generate_tile(x, y)
  local v = K_FOG_OF_WAR

  local t = type_filtered(x, y)
  v = bit.bor(v, t)

  -- variants
  if math.random() > 0.4 then
    v = bit.bor(v, K_VARIANT)
  elseif t == K_TREE and math.random() > 0.98 then
    v = bit.bor(v, K_VARIANT2)
  end
  return v
end