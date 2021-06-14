K_WALL_MASK = 0xff
K_WALL_MASK_OBSTRUCTION = 0x7f
K_STATIC = 0x100
K_STATIC_OBSTRUCTION = 0x200
K_FOG_OF_WAR = 0x400
K_STATIC_ALL = bit.bor(K_STATIC, K_STATIC_OBSTRUCTION)
K_OBSTRUCTION = bit.bor(K_WALL_MASK_OBSTRUCTION, K_STATIC_OBSTRUCTION)
K_NO_SHADOWS = 0

g_board_observers = {}

function board_init()
  g_state.board = {
    left = 0;
    right = 0;
    top = 0;
    bottom = 0;
    grid = {},
    temporary_edits = {}, -- list of {{x, y, mask, value}, ...} sets; temporarily modify these values of the board. (sparse.)
    path_dirty = true
  }

  g_board_observers = {}

  board_update_bounds(0, 40, 0, 24)
end

-- new tile added to board
function board_generate_tile(x, y)
  return K_FOG_OF_WAR
end

-- sets new bounds for the board, adding or removing tiles as needed.
-- refreshes pathing as well.
function board_update_bounds(left, right, top, bottom)
  local board = g_state.board

  -- previous values
  local pleft = board.left
  local pright = board.right
  local ptop = board.top
  local pbottom = board.bottom

  -- adjust grid

  for y = math.min(ptop,top),math.max(pbottom, bottom) - 1 do
    if not in_range(y, top, bottom) and in_range(y, ptop, pbottom) then
      -- remove row
      board:remove(y)
    elseif in_range(y, top, bottom) then
      if not in_range(y, ptop, pbottom) then
        -- add row
        board.grid[y] = {}
        for x = left,right - 1 do
          board.grid[y][x] = board_generate_tile(x, y)
        end
      else
        for x = math.min(left,pleft),math.max(right, pright) - 1 do
          if in_range(x, left, right) and not in_range(x, pleft, pright) then
            -- new tile
            board.grid[y][x] = 0
          elseif not in_range(x, left, right) and in_range(x, pleft, pright) then
            board.grid[y]:remove(x)
          end
        end
      end
    end
  end

   -- update bounds
   board.left = left
   board.right = right
   board.top = top
   board.bottom = bottom

   pf_reset(right - left, bottom - top)
   board_refresh_pathing()
end

function board_iterate(board)
  return function(state)
    local board = state.board
    if state.y >= board.bottom then
      return nil, nil, nil
    end
    local y = state.y
    local x = state.x
    local v = board_get_value(state.x, state.y)
    state.x = state.x + 1
    if state.x >= board.right then
      state.x = board.left
      state.y = state.y + 1
    end
    return y, x, v
  end, {board=board, x=board.left, y=board.top}, 0
end

function board_width()
  return g_state.board.right - g_state.board.left
end

function board_height()
  return g_state.board.bottom - g_state.board.top
end

function board_perimeter()
  return 2 * board_width() + 2 * board_height() - 4
end

-- returns x, y location of perimeter location
function board_perimeter_location(i)
  i = i % board_perimeter()
  if i < board_width() then
    return i, 0
  end
  i = i - board_width()
  if i < board_height() - 2  then
    return board_width() - 1, i + 1
  end
  i = i - board_height() + 2
  if i < board_width()  then
    return board_width() - i - 1, board_height() - 1
  end
  i = i - board_width()
  if i < board_height() - 2 then
    return 0, board_height() - 1 - i
  end
  -- paranoia
  return 0, 0
end

-- wall image indices
K_WALL_INNER_CORNER = {
  {17, 16}, {13, 12}
}

K_WALL_OUTER_CORNER = {
  {0, 2}, {8, 10}
}

K_WALL_HORIZONTAL = {
  1, 9
}

K_WALL_VERTICAL = {
  4, 6
}

K_SHADOW = {
  nil, 20, 21, 26,
  23, 24, 22, 25,
}

-- returns one of four corner tiles for the wall at the given idx
function wall_get_subtile(base_x, base_y, dx, dy, mask, edges_are_walls)
  assert(dx and dy and dx ~= 0 and dy ~= 0)
  local wall_at = {}
  
  -- check 2x2 square to see what walls are there.
  for y in ordered_range(base_y, base_y + dy) do
    wall_at[y] = {}
    for x in ordered_range(base_x, base_x + dx) do
      wall_at[y][x] = bit.band(d(board_get_value(x, y, edges_are_walls and mask or 0), 0), mask) ~= 0
    end
  end

  -- indices for selecting subimages from lists
  local imgx = tern(dx > 0, 2, 1)
  local imgy = tern(dy > 0, 2, 1)

  -- if base position has no wall, then there is no wall.
  if not wall_at[base_y][base_x] then
    if dx == 1 and dy == 1 then
      -- bottom-right corner never has shadows.
      return nil
    end
    -- no wall, but possibly shadows
    local left = dx == -1 and wall_at[base_y][base_x + dx]
    local top = dy == -1 and wall_at[base_y + dy][base_x]
    local diagonal = (dx == -1 and dy == -1 and wall_at[base_y + dy][base_x + dx]) or (dx == 1 and dy == -1 and top) or (dy == 1 and dx == -1 and left)

    return K_SHADOW[tern(left, 1, 0) + tern(top, 2, 0) + tern(diagonal, 4, 0) + 1]
  else
    -- full region or inner corner
    if wall_at[base_y + dy][base_x] and wall_at[base_y][base_x + dx] then
      if wall_at[base_y + dy][base_x + dx] then
        -- full
        return 5
      else
        return K_WALL_INNER_CORNER[imgy][imgx]
      end
    end

    -- horizontal wall
    if wall_at[base_y][base_x + dx] and not wall_at[base_y + dy][base_x] then
      return K_WALL_HORIZONTAL[imgy]
    end

    -- vertical  wall
    if wall_at[base_y + dy][base_x] and not wall_at[base_y][base_x + dx] then
      return K_WALL_VERTICAL[imgx]
    end

    -- outer corner
    if not wall_at[base_y + dy][base_x] and not wall_at[base_y][base_x + dx] then
      return K_WALL_OUTER_CORNER[imgy][imgx]
    end
  end
end

function wall_draw_at(x, y, sprite, mask, edges_are_walls)
  for dy = -1,1,2 do
    for dx = -1,1,2 do
      local wall_subtile = wall_get_subtile(x, y, dx, dy, mask or K_WALL_MASK, edges_are_walls or false)
      if wall_subtile then
        draw_sprite(sprite or g_images.wall, wall_subtile,
          (x + 0.25 + 0.25 * dx) * k_dim_x,
          (y + 0.25 + 0.25 * dy) * k_dim_y
        )
      end
    end
  end
end

-- draws terrain features / walls
function board_draw()
  for y, x, v in board_iterate(g_state.board) do
    if bit.band(v, K_WALL_MASK) ~= 0 or bit.band(v, K_NO_SHADOWS) == 0 then
      wall_draw_at(x, y, g_images.wall)
    end
  end
end

function board_draw_fog()
  for y, x, v in board_iterate(g_state.board) do
    if bit.band(v, K_FOG_OF_WAR) ~= 0 then
      wall_draw_at(x, y, g_images.fog_of_war, K_FOG_OF_WAR, true)
    end
  end

  -- draw borders
  local m = 1000
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", -m, -m, m * 2 + board_width() * k_dim_x, m)
  love.graphics.rectangle("fill", -m, 0, m, board_height() * k_dim_y)
  love.graphics.rectangle("fill", board_width() * k_dim_x, 0, m, board_height() * k_dim_y)
  love.graphics.rectangle("fill", -m, board_height() * k_dim_y, m * 2 + board_width() * k_dim_x, m)
  love.graphics.setColor(1, 1, 1)
end

function board_get_value(x, y, default)
  local board = g_state.board
  if not board.grid[y] then
    return default
  end
  local v = board.grid[y][x]
  if v == nil then
    return default
  end

  -- check temporary edits
  for idx, edits in ipairs(board.temporary_edits) do
    for _, e in ipairs(edits) do
      local ex, ey, mask, value = unpack(e)
      if ex == x and ey == y then
        return bit.bor(bit.band(v, bit.bnot(mask)), bit.band(mask, value))
      end
    end
  end

  return v
end

-- writes values to the board, if they don't collide with another value.
-- returns true if successful, false if fails (a collision)
-- x, y: the top-left coordinate to write to the board at.
-- grid={{1}}: a 2d array of values. Every non-zero value will be written.
-- mask: required if both cmask and wmask are not provided. cmask and wmask are set to this.
-- cmask: if not nil, then only check and overwrite the masked bits of the board.
-- wmask: if not nil, then overwrite only these bits (rather than mask).
-- value: if not nil, then write this value instead of whatever is in the grid. Must be a subset of wmask. (Allows grid to be simple 0/1)
-- bounds: if set, then treat regions outside of the board as though they have this value. (default: cannot place outside board)
-- all: if set, only fail if all possible locations collide.
-- force: apply without checking
-- test: (private use) only compare, do not write.
function board_emplace(opts, test)
  local base_x = opts.x
  local base_y = opts.y
  local grid = opts.grid or make_2d_array(opts.w, opts.h, 1)
  local all = not not opts.all
  local any_free = false
  local cmask = d(opts.cmask, opts.mask, 0xffffffff) -- "compare mask"
  local wmask = tern(test, 0, d(opts.wmask, opts.mask)) -- "write mask"
  assert(wmask ~= nil, "wmask not set.")
  local value = opts.value or opts.wmask
  assert(test or value ~= nil, "value must be supplied")
  local bounds = opts.bounds
  if value ~= nil and not test then
    assert(bit.band(value, bit.bnot(wmask)) == 0, "wmask (" .. HEX(wmask) .. ") must be a superset of value (" .. HEX(value) .. ")")
  end
  local change_occurred = false
  grid = grid or {{1}}
  bounds = d(bounds, cmask)
  local board = g_state.board

  if not test and #board.temporary_edits > 0 then
    assert(false, "cannot place value on board if temporary board edits are in effect.")
  end

  -- do two passes:
  -- first pass is the "test" run. Check for collisions. (skip if opts.force)
  -- second pass is the "emplace" run. Write values. (skip if test)
  for pass = tern(opts.force ~= nil, 1, 0),tern(test == true, 0, 1) do
    for yo, xo, grid_value in array_2d_iterate(grid, 0) do
      local x = xo + base_x
      local y = yo + base_y
      local board_value = bounds
      on_board = false
      if x >= board.left and x < board.right and y >= board.top and y < board.bottom then
        on_board = true
        board_value = board_get_value(x, y)
      end

      local obstruction = bit.band(board_value, cmask) ~= 0 and grid_value ~= 0

      if pass == 0 then
        -- first pass: check for collisions
        if obstruction then
          if not all then
            return false
          end
        elseif grid_value ~= 0 then
          any_free = true
        end
      elseif grid_value ~= 0 and on_board then
        -- second pass: write values
        if bit.band(value, K_OBSTRUCTION) then
          -- have to update pathfinder.
          board.path_dirty = true
        end
        local prev = board.grid[y][x]
        board.grid[y][x] = bit.bor(bit.band(board.grid[y][x], bit.bnot(wmask)), value)
        if prev ~= board.grid[y][x] then
          change_occurred = true
        end
      end
    end -- iterate board
    if all and pass == 0 and not any_free then
      -- fail.
      return false
    end
  end -- iterate pass

  -- notify board observers of update
  if change_occurred then
    for observer in entries(g_board_observers) do
      observer({
        x= base_x, y = base_y, grid = grid, mask = wmask, value = value
      })
    end
  end

  -- success.
  return true
end

-- checks if region would be free
function board_test_free(opts)
  return board_emplace(opts, true)
end

-- checks if region would be obstructed
function board_test_collides(opts)
  return not board_test_free(opts)
end

function board_push_temporary_change_from_grid(x, y, grid, mask, value)
  assert(x and y and grid and mask)
  local a = {}
  for yo, xo, v in array_2d_iterate(grid) do
    if v ~= 0 then
      table.insert(a, {x + xo - 1, y + yo - 1, mask, value or mask})
    end
  end
  board_push_temporary_change(a)
end

-- push array of {x, y, mask, value}
function board_push_temporary_change(tiles)
  -- edge case / early out
  if #tiles == 0 then
    return
  end

  g_state.board.path_dirty = true

  -- validate input
  for idx, change in ipairs(tiles) do
    local x, y, mask, value = unpack(change)
    assert(x and y and mask and value)
    assert(bit.band(bit.bnot(mask), value) == 0, "value must be subset of mask")
  end

  if type(tiles[1]) == "number" then
    tiles = {tiles}
  end

  table.insert(g_state.board.temporary_edits, tiles)
end

function board_pop_temporary_change()
  table.remove(g_state.board.temporary_edits, #g_state.board.temporary_edits)
end

function board_refresh_pathing()
  local board = g_state.board
  local grid = pf_get_grid_reference()
  assert(grid ~= nil)
  for y, x, v in board_iterate(board) do
    if bit.band(v, K_OBSTRUCTION) ~= 0 then
      grid[y - board.top + 1][x - board.left + 1] = 1
    else
      grid[y - board.top + 1][x - board.left + 1] = 0
    end
  end

  board.path_dirty = false

  pf_update_from_grid()
end

function board_observe(fn)
  table.insert(g_board_observers, fn)
end

function board_pathfind(x, y, px, py)
  local board = g_state.board
  if board.path_dirty then
    board_refresh_pathing()
  end

  local path, length = pf_pathfind(x - board.left + 1, y - board.top + 1, px - board.left + 1, py - board.top + 1)
  -- convert path coordinates
  if path ~= nil then
    for idx, node in ipairs(path) do
      node.x = node.x + board.left - 1
      node.y = node.y + board.top - 1
    end
  end
  return path, length
end